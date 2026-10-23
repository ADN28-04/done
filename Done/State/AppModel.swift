import Foundation
import Observation
import SwiftData

/// État partagé : tâches Todoist, projets et plan du jour.
@Observable
@MainActor
final class AppModel {
    private(set) var index = TaskIndex()
    private(set) var projects: [TodoistProject] = []
    private(set) var completed: [TodoistTask] = []
    private(set) var isLoading = false
    private(set) var lastRefresh: Date?
    private(set) var hasToken: Bool
    /// Clé API Claude présente dans le trousseau.
    private(set) var hasClaudeKey = Keychain.read(Keychain.anthropicAccount) != nil
    private(set) var plan: DayPlan?
    /// Jour du dernier bilan du soir (`Format.dayKey`).
    private(set) var lastReviewDay: String?
    /// Tâches reportées par le dernier bilan, pour le prochain plan du matin.
    private(set) var carryOver: CarryOver?
    /// Notes « où j'en suis » des tâches quittées en cours de route.
    private(set) var resumeNotes = ResumeNotes()
    /// Fichiers joints aux tâches pour le découpage avec Claude.
    private(set) var taskAttachments = TaskAttachments()
    var errorMessage: String?

    private static let lastReviewKey = "review.lastDay"
    private static let carryOverKey = "review.carryOver"
    private static let resumeNotesKey = "resume.notes"
    private static let attachmentsKey = "attachments.byTask"

    let context: ModelContext
    @ObservationIgnored private var token: String?

    init(context: ModelContext) {
        self.context = context
        let token = Keychain.readToken()
        self.token = token
        self.hasToken = token != nil
        self.plan = nil
        let defaults = UserDefaults.standard
        self.lastReviewDay = defaults.string(forKey: Self.lastReviewKey)
        self.carryOver = defaults.data(forKey: Self.carryOverKey).flatMap { try? JSONDecoder().decode(CarryOver.self, from: $0) }
        self.resumeNotes = defaults.data(forKey: Self.resumeNotesKey).flatMap { try? JSONDecoder().decode(ResumeNotes.self, from: $0) } ?? ResumeNotes()
        self.taskAttachments = defaults.data(forKey: Self.attachmentsKey).flatMap { try? JSONDecoder().decode(TaskAttachments.self, from: $0) } ?? TaskAttachments()
        loadPlan()
    }

    var rules: Rules { Rules.current }

    // MARK: Lecture

    var todayPlan: DayPlan? {
        guard let plan, Calendar.current.isDateInToday(plan.day) else { return nil }
        return plan
    }

    var planIDs: [String] { todayPlan?.taskIDs ?? [] }

    var meetingsToday: [Meeting] {
        Planner.meetings(in: index.all, on: .now, rules: rules)
    }

    var candidates: [TodoistTask] {
        Planner.candidates(in: index, rules: rules)
    }

    func projectName(_ id: String) -> String {
        projects.first { $0.id == id }?.name ?? ""
    }

    func projectName(for task: TodoistTask) -> String {
        projectName(task.projectId)
    }

    /// Toutes les tâches ouvertes hors réunions, filtrées par texte.
    func pickableTasks(matching query: String) -> [TodoistTask] {
        let currentRules = rules
        let text = query.trimmingCharacters(in: .whitespaces)
        let matches = index.all.filter { task in
            guard !Planner.isMeeting(task, rules: currentRules) else { return false }
            guard !text.isEmpty else { return true }
            return task.content.localizedCaseInsensitiveContains(text)
                || projectName(for: task).localizedCaseInsensitiveContains(text)
        }
        // Les tâches datées plus tard restent trouvables, mais en fin de liste.
        let now = Date.now
        let sorted = matches.sorted { a, b in
            let laterA = Planner.isScheduledLater(a, rules: currentRules, now: now)
            let laterB = Planner.isScheduledLater(b, rules: currentRules, now: now)
            if laterA != laterB { return laterB }
            return Planner.priorityOrder(a, b)
        }
        return Array(sorted.prefix(200))
    }

    // MARK: Connexion

    func connect(token rawToken: String) async -> Bool {
        let candidate = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty else { return false }
        do {
            _ = try await TodoistClient(token: candidate).projects()
            Keychain.saveToken(candidate)
            token = candidate
            hasToken = true
            errorMessage = nil
            await refresh()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func disconnect() {
        Keychain.deleteToken()
        token = nil
        hasToken = false
        index = TaskIndex()
        projects = []
        completed = []
    }

    // MARK: Synchro Todoist

    func refresh() async {
        guard let token, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let client = TodoistClient(token: token)
        do {
            async let fetchedTasks = client.tasks()
            async let fetchedProjects = client.projects()
            let (tasks, projectList) = try await (fetchedTasks, fetchedProjects)
            index = TaskIndex(tasks)
            projects = projectList
                .filter { !$0.isArchived }
                .sorted { ($0.isInbox ? -1 : $0.childOrder) < ($1.isInbox ? -1 : $1.childOrder) }
            lastRefresh = .now
            errorMessage = nil
            loadPlan()
            recordSnapshot()
            updateResumeNotes { $0.keepOnly(Set(tasks.map(\.id))) }
            updateAttachments { $0.keepOnly(Set(tasks.map(\.id))) }
            updateMeetingReminders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshIfStale(after seconds: TimeInterval = 60) async {
        if let lastRefresh, Date.now.timeIntervalSince(lastRefresh) < seconds { return }
        await refresh()
    }

    func loadCompleted(weeks: Int = 8) async {
        guard let token else { return }
        let until = Date.now
        let since = Calendar.current.date(byAdding: .day, value: -7 * weeks, to: until) ?? until
        do {
            completed = try await TodoistClient(token: token).completedTasks(since: since, until: until)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Coche la tâche dans Todoist et la retire tout de suite de l'index local.
    func close(_ task: TodoistTask) async throws {
        guard let token else { throw TodoistError.unauthorized }
        try await TodoistClient(token: token).closeTask(id: task.id)
        index = index.removing(task.id)
        updateResumeNotes { $0.remove(task.id) }
        updateAttachments { $0.removeAll(for: task.id) }
        if let plan = todayPlan, plan.taskIDs.contains(task.id) {
            plan.taskIDs.removeAll { $0 == task.id }
            plan.doneIDs.append(task.id)
            save()
        }
    }

    // MARK: Découpage et chantiers actifs

    var activeChantiers: [TodoistTask] {
        Planner.activeChantiers(in: index, rules: rules)
    }

    /// Crée la prochaine action concrète comme sous-tâche dans Todoist.
    @discardableResult
    func addSubtask(_ content: String, to parent: TodoistTask) async throws -> TodoistTask {
        guard let token else { throw TodoistError.unauthorized }
        let created = try await TodoistClient(token: token).createSubtask(content: content, parentID: parent.id)
        index = TaskIndex(index.all + [created])
        return created
    }

    /// Met des chantiers en file d'attente : retire @Chantier-actif dans Todoist, puis recharge.
    func park(_ tasks: [TodoistTask]) async throws {
        guard let token else { throw TodoistError.unauthorized }
        let client = TodoistClient(token: token)
        for task in tasks {
            for update in Planner.parkingUpdates(for: task, in: index) {
                _ = try await client.updateLabels(taskID: update.taskID, labels: update.labels)
            }
        }
        await refresh()
    }

    // MARK: Bilan du soir

    var isReviewDue: Bool {
        Review.isDue(now: .now, rules: rules, hasPlan: todayPlan != nil, lastReviewDay: lastReviewDay)
    }

    var reviewDoneToday: Bool { lastReviewDay == Format.dayKey(.now) }

    /// Tâches reportées par le dernier bilan, à proposer dans le plan d'aujourd'hui.
    var carriedOverIDs: [String] {
        carryOver?.taskIDs(availableOn: Format.dayKey(.now)) ?? []
    }

    func completeReview(_ carry: CarryOver) {
        carryOver = carry
        lastReviewDay = carry.fromDay
        let defaults = UserDefaults.standard
        defaults.set(try? JSONEncoder().encode(carry), forKey: Self.carryOverKey)
        defaults.set(carry.fromDay, forKey: Self.lastReviewKey)
    }

    // MARK: Claude

    /// Vérifie la clé auprès de l'API, puis la range dans le trousseau.
    func saveClaudeKey(_ rawKey: String) async throws {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw ClaudeError.missingKey }
        try await ClaudeClient(apiKey: key).checkKey()
        Keychain.save(key, account: Keychain.anthropicAccount)
        hasClaudeKey = true
    }

    func deleteClaudeKey() {
        Keychain.delete(Keychain.anthropicAccount)
        hasClaudeKey = false
    }

    /// Trois premières actions proposées par Claude, avec le contexte de Todoist et du dossier choisi.
    func suggestBreakdown(for task: TodoistTask) async throws -> [Breakdown.Suggestion] {
        guard let key = Keychain.read(Keychain.anthropicAccount) else { throw ClaudeError.missingKey }
        let rules = rules
        let folder = rules.claudeContextFolder.isEmpty ? nil : ContextFolder(root: URL(fileURLWithPath: rules.claudeContextFolder))
        // Parcourir le dossier peut prendre un moment : hors du fil principal.
        let (files, entries) = await Task.detached { () -> ([ContextFolder.File], [Breakdown.ContextEntry]) in
            guard let folder else { return ([], []) }
            let files = folder.files()
            return (files, folder.entries(of: files))
        }.value

        let parent = task.parentId.flatMap { index[$0] }
        let siblings = task.parentId.map { index.children(of: $0).filter { $0.id != task.id } } ?? []
        let system = Breakdown.systemPrompt(
            method: rules.claudeMethod,
            examples: Breakdown.examples(in: index, preferring: task.projectId, excluding: task.id, rules: rules),
            files: entries
        )
        let prompt = Breakdown.taskPrompt(
            task: task,
            projectName: projectName(for: task),
            parent: parent,
            siblings: siblings,
            resumeNote: resumeNote(for: task.id)?.text
        )
        var attachments: [Breakdown.Attachment] = []
        for path in taskAttachments[task.id] {
            attachments.append(try await AttachmentLoader.load(URL(fileURLWithPath: path)))
        }
        return try await ClaudeClient(apiKey: key, model: rules.claudeModel).suggestActions(
            system: system,
            userContent: Breakdown.userContent(prompt: prompt, attachments: attachments),
            offersFiles: !files.isEmpty
        ) { paths in
            guard let folder else { return "" }
            return await folder.read(paths, in: files)
        }
    }

    // MARK: Pièces jointes

    func attachments(for taskID: String) -> [String] {
        taskAttachments[taskID]
    }

    /// Joint des fichiers à une tâche. Renvoie ceux refusés faute de place.
    @discardableResult
    func attach(_ paths: [String], to taskID: String) -> [String] {
        var refused: [String] = []
        updateAttachments { refused = $0.add(paths, to: taskID) }
        return refused
    }

    func detach(_ path: String, from taskID: String) {
        updateAttachments { $0.remove(path, from: taskID) }
    }

    private func updateAttachments(_ change: (inout TaskAttachments) -> Void) {
        var attachments = taskAttachments
        change(&attachments)
        guard attachments != taskAttachments else { return }
        taskAttachments = attachments
        UserDefaults.standard.set(try? JSONEncoder().encode(attachments), forKey: Self.attachmentsKey)
    }

    // MARK: Note de reprise

    func resumeNote(for taskID: String) -> ResumeNote? {
        resumeNotes[taskID]
    }

    func setResumeNote(_ text: String, for taskID: String) {
        updateResumeNotes { $0.set(text, for: taskID) }
    }

    private func updateResumeNotes(_ change: (inout ResumeNotes) -> Void) {
        var notes = resumeNotes
        change(&notes)
        guard notes != resumeNotes else { return }
        resumeNotes = notes
        UserDefaults.standard.set(try? JSONEncoder().encode(notes), forKey: Self.resumeNotesKey)
    }

    // MARK: Réunion proche

    /// Reprogramme les rappels des réunions d'aujourd'hui et de demain, après chaque synchro
    /// ou changement de réglage.
    func updateMeetingReminders() {
        let rules = rules
        guard rules.meetingReminder else {
            Notifier.shared.updateMeetingReminders([])
            return
        }
        let now = Date.now
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
        let meetings = Planner.meetings(in: index.all, on: now, rules: rules)
            + Planner.meetings(in: index.all, on: tomorrow, rules: rules)
        Notifier.shared.updateMeetingReminders(MeetingReminder.plan(meetings, now: now, minutes: rules.meetingReminderMinutes))
    }

    // MARK: Plan du jour

    func savePlan(_ ids: [String]) {
        if let plan = todayPlan {
            plan.taskIDs = ids
            plan.validatedAt = .now
        } else {
            let plan = DayPlan(day: Calendar.current.startOfDay(for: .now), taskIDs: ids)
            context.insert(plan)
            self.plan = plan
        }
        // Le report de la veille a servi : il ne doit pas revenir demain.
        if !carriedOverIDs.isEmpty {
            carryOver = nil
            UserDefaults.standard.removeObject(forKey: Self.carryOverKey)
        }
        save()
    }

    /// « Passer » : la tâche part en fin de plan.
    func skip(_ id: String) {
        guard let plan = todayPlan, plan.taskIDs.contains(id) else { return }
        var ids = plan.taskIDs.filter { $0 != id }
        ids.append(id)
        plan.taskIDs = ids
        save()
    }

    /// Met une tâche (urgente ou choisie à la main) en tête du plan.
    func putFirst(_ id: String) {
        guard let plan = todayPlan else {
            savePlan([id])
            return
        }
        plan.taskIDs = [id] + plan.taskIDs.filter { $0 != id }
        save()
    }

    private func loadPlan() {
        let start = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<DayPlan>(predicate: #Predicate { $0.day == start })
        plan = (try? context.fetch(descriptor))?.first
    }

    private func recordSnapshot() {
        let numbers = Stats.backlog(index, rules: rules)
        let day = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<BacklogSnapshot>(predicate: #Predicate { $0.day == day })
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.update(numbers)
        } else {
            let snapshot = BacklogSnapshot(day: day)
            snapshot.update(numbers)
            context.insert(snapshot)
        }
        save()
    }

    private func save() {
        do {
            try context.save()
        } catch {
            errorMessage = "Enregistrement local impossible : \(error.localizedDescription)"
        }
    }
}
