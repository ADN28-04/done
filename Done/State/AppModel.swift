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
    private(set) var plan: DayPlan?
    /// Jour du dernier bilan du soir (`Format.dayKey`).
    private(set) var lastReviewDay: String?
    /// Tâches reportées par le dernier bilan, pour le prochain plan du matin.
    private(set) var carryOver: CarryOver?
    var errorMessage: String?

    private static let lastReviewKey = "review.lastDay"
    private static let carryOverKey = "review.carryOver"

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
