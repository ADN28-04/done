import Foundation
import Observation
import SwiftData

/// État partagé : tâches, projets, réunions, plan du jour et bilan du soir.
/// Les tâches vivent dans un fichier local (`TaskStorage`), réécrit à chaque changement.
@Observable
@MainActor
final class AppModel {
    private(set) var store = TaskStore()
    /// Tâches ouvertes, avec l'arborescence des sous-tâches.
    private(set) var index = TaskIndex()
    private(set) var plan: DayPlan?
    /// Jour du dernier bilan du soir (`Format.dayKey`).
    private(set) var lastReviewDay: String?
    /// Tâches reportées par le dernier bilan, pour le prochain plan du matin.
    private(set) var carryOver: CarryOver?
    /// Notes « où j'en suis » des tâches quittées en cours de route.
    private(set) var resumeNotes = ResumeNotes()
    var errorMessage: String?
    /// Tâches cochées dans une liste, pas encore enregistrées : leur ligne garde une seconde pour
    /// montrer la case, l'éclat et le trait, puis la tâche est cochée et part vers « Fait aujourd'hui ».
    private(set) var finishing: Set<String> = []

    private static let lastReviewKey = "review.lastDay"
    private static let carryOverKey = "review.carryOver"
    private static let resumeNotesKey = ResumeNotes.defaultsKey

    let context: ModelContext
    let storage: TaskStorage
    /// Plan du jour échangé avec le connecteur Claude.
    let planFiles: PlanFiles
    /// Faux si le fichier illisible n'a pas pu être mis de côté : on ne l'écrase jamais.
    @ObservationIgnored private var canSave = true
    /// Version du fichier des tâches à la dernière lecture ou écriture par Done. Si elle change, le
    /// connecteur Claude l'a réécrit : Done le relit avant d'y toucher.
    @ObservationIgnored private var fileStamp: TaskStorage.Stamp?
    @ObservationIgnored private var watcher: FolderWatcher?
    @ObservationIgnored private var finishingTimers: [String: Task<Void, Never>] = [:]

    init(context: ModelContext, storage: TaskStorage = .standard, planFiles: PlanFiles? = nil) {
        self.context = context
        self.storage = storage
        self.planFiles = planFiles ?? PlanFiles(folder: storage.folder)
        let defaults = UserDefaults.standard
        lastReviewDay = defaults.string(forKey: Self.lastReviewKey)
        carryOver = defaults.data(forKey: Self.carryOverKey).flatMap { try? JSONDecoder().decode(CarryOver.self, from: $0) }
        resumeNotes = defaults.data(forKey: Self.resumeNotesKey).flatMap { try? JSONDecoder().decode(ResumeNotes.self, from: $0) } ?? ResumeNotes()
        do {
            store = try storage.load() ?? TaskStore()
            fileStamp = storage.stamp()
        } catch {
            if let moved = storage.setAsideUnreadable() {
                errorMessage = "Le fichier des tâches était illisible. Il a été mis de côté ici : \(moved.path)"
            } else {
                canSave = false
                errorMessage = "Le fichier des tâches est illisible (\(error.localizedDescription)). Done n'y écrira rien tant qu'il n'est pas réparé ou déplacé : \(storage.fileURL.path)"
            }
        }
        index = TaskIndex(store.openTasks)
        // Les réunions de la veille et d'avant ne servent plus.
        // Gardées jusqu'à la fin de la semaine, pour le calendrier.
        commit { $0.pruneMeetings(endedBefore: Stats.week(containing: .now).start) }
        updateResumeNotes { $0.keepOnly(Set(store.openTasks.map(\.id))) }
        loadPlan()
        applyPlanRequest()
        publishPlan()
    }

    var rules: Rules { Rules.current }

    // MARK: Lecture

    var todayPlan: DayPlan? {
        guard let plan, Calendar.current.isDateInToday(plan.day) else { return nil }
        return plan
    }

    var planIDs: [String] { todayPlan?.taskIDs ?? [] }

    /// Plan du jour bouclé : tout ce qui y était prévu est coché.
    var isPlanFinished: Bool {
        guard let plan = todayPlan else { return false }
        return DayAgenda.isPlanFinished(plan: plan.taskIDs, done: plan.doneIDs) { index[$0] != nil }
    }

    var projects: [Project] { store.sortedProjects }

    /// Étiquettes des tâches ouvertes, par ordre alphabétique.
    var tags: [String] { store.tags }

    var meetingsToday: [Meeting] { store.meetings(on: .now) }

    /// Réunions pas encore finies, à partir d'aujourd'hui.
    var upcomingMeetings: [Meeting] { store.upcomingMeetings(after: .now) }

    var candidates: [TodoTask] {
        Planner.candidates(in: index, rules: rules)
    }

    func project(_ id: String?) -> Project? {
        guard let id else { return nil }
        return store.projects.first { $0.id == id }
    }

    /// Nom du projet (« Projet › Sous-projet » pour un sous-projet), ou « Inbox » sans projet.
    func projectName(_ id: String?) -> String {
        store.projectPath(id) ?? "Inbox"
    }

    func subprojects(of id: String) -> [Project] { store.subprojects(of: id) }

    var topLevelProjects: [Project] { store.topLevelProjects }

    func listName(_ list: TaskList) -> String {
        switch list {
        case .inbox: "Inbox"
        case .project(let id): projectName(id)
        case .tag(let name): name
        }
    }

    /// Où la tâche est rangée : son projet, sinon sa première étiquette, sinon l'Inbox.
    func listName(for task: TodoTask) -> String {
        if project(task.projectID) != nil { return projectName(task.projectID) }
        return task.tags.first ?? "Inbox"
    }

    /// Tâches ouvertes de premier niveau d'une liste, dans l'ordre de la liste.
    func topLevelTasks(in list: TaskList) -> [TodoTask] {
        index.all
            .filter { $0.parentID == nil && store.contains($0, in: list) }
            .sorted { $0.position < $1.position }
    }

    func openCount(in list: TaskList) -> Int {
        index.all.filter { $0.parentID == nil && store.contains($0, in: list) }.count
    }

    /// Tâches cochées d'une liste, les plus récentes d'abord.
    func completedTasks(in list: TaskList, limit: Int = 50) -> [TodoTask] {
        let done = store.tasks
            .filter { !$0.isOpen && store.contains($0, in: list) }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        return Array(done.prefix(limit))
    }

    /// Toutes les tâches ouvertes, filtrées par texte.
    func pickableTasks(matching query: String) -> [TodoTask] {
        let currentRules = rules
        let text = query.trimmingCharacters(in: .whitespaces)
        let matches = index.all.filter { task in
            guard !text.isEmpty else { return true }
            return task.title.localizedCaseInsensitiveContains(text)
                || listName(for: task).localizedCaseInsensitiveContains(text)
                || task.tags.contains { $0.localizedCaseInsensitiveContains(text) }
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

    // MARK: Absences

    func absence(on day: Date) -> Absence? {
        store.absence(on: day)
    }

    func setAbsence(on day: Date, title: String) {
        commit { $0.setAbsence(on: day, title: title) }
    }

    func removeAbsence(on day: Date) {
        commit { $0.removeAbsence(on: day) }
    }

    // MARK: Tâches

    @discardableResult
    func addTask(_ title: String, projectID: String?, parentID: String? = nil) -> TodoTask? {
        var created: TodoTask?
        commit { created = $0.addTask(title: title, projectID: projectID, parentID: parentID) }
        return created
    }

    /// Crée une tâche avec tous ses détails et ses étapes, en une seule écriture du fichier.
    @discardableResult
    func addTask(_ draft: TaskDraft) -> TodoTask? {
        var created: TodoTask?
        commit { created = $0.addTask(draft) }
        return created
    }

    /// Ajoute les étapes d'un découpage, dans l'ordre.
    @discardableResult
    func addSubtasks(_ titles: [String], to parent: TodoTask) -> [TodoTask] {
        var created: [TodoTask] = []
        commit { store in
            for title in titles {
                if let task = store.addTask(title: title, projectID: parent.projectID, parentID: parent.id) {
                    created.append(task)
                }
            }
        }
        return created
    }

    func update(_ task: TodoTask) {
        commit { $0.update(task) }
    }

    /// Range une tâche par glisser-déposer sur une liste de la barre latérale.
    func file(_ id: String, into list: TaskList) {
        commit { $0.file(id, into: list) }
    }

    func renameTag(_ old: String, to new: String) {
        commit { $0.renameTag(old, to: new) }
    }

    func removeTag(_ name: String) {
        commit { $0.removeTag(name) }
    }

    /// Coche la tâche et ses sous-tâches, et la sort du plan du jour.
    func complete(_ task: TodoTask) {
        let ids = [task.id] + store.descendants(of: task.id)
        commit { $0.complete(task.id) }
        updateResumeNotes { notes in ids.forEach { notes.remove($0) } }
        if let plan = todayPlan, plan.taskIDs.contains(where: { ids.contains($0) }) {
            plan.taskIDs.removeAll { ids.contains($0) }
            if !plan.doneIDs.contains(task.id) { plan.doneIDs.append(task.id) }
            save()
        }
    }

    // MARK: Coche différée

    /// Coche la tâche après `delay`, le temps que sa ligne le montre. Recliquer pendant ce temps
    /// l'annule (`cancelFinishing`) ; quitter Done l'enregistre aussitôt (`flushFinishing`).
    /// Les autres façons de cocher (minuteur, Rappels, Claude) restent immédiates.
    func completeSoon(_ task: TodoTask, delay: Duration = .seconds(1)) {
        guard task.isOpen, !finishing.contains(task.id) else { return }
        finishing.insert(task.id)
        finishingTimers[task.id] = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.finishNow(task.id)
        }
    }

    func cancelFinishing(_ id: String) {
        finishingTimers.removeValue(forKey: id)?.cancel()
        finishing.remove(id)
    }

    /// Enregistre tout de suite les coches en attente : à la fermeture de Done.
    func flushFinishing() {
        for id in finishing {
            finishNow(id)
        }
    }

    private func finishNow(_ id: String) {
        finishingTimers.removeValue(forKey: id)?.cancel()
        guard finishing.remove(id) != nil, let task = store[id], task.isOpen else { return }
        complete(task)
    }

    /// Rouvre une tâche cochée par erreur.
    func reopen(_ task: TodoTask) {
        commit { $0.reopen(task.id) }
    }

    /// Supprime la tâche et ses sous-tâches.
    func delete(_ task: TodoTask) {
        let ids = [task.id] + store.descendants(of: task.id)
        commit { $0.delete(task.id) }
        updateResumeNotes { notes in ids.forEach { notes.remove($0) } }
        if let plan = todayPlan, plan.taskIDs.contains(where: { ids.contains($0) }) {
            plan.taskIDs.removeAll { ids.contains($0) }
            save()
        }
    }

    /// Monte ou descend une tâche d'un cran parmi ses sœurs ouvertes (⌘↑, ⌘↓).
    func shift(_ id: String, by offset: Int) {
        commit { $0.shift(id, by: offset) }
    }

    /// Place `id` juste avant `target` parmi les tâches de même niveau, ou en fin de liste.
    func move(_ id: String, before target: String?) {
        commit { $0.move(id, before: target) }
    }

    /// Étape bloquée : laissée ouverte mais plus proposée, la raison gardée en note de reprise.
    func markBlocked(_ task: TodoTask, reason: String) {
        commit { $0.setBlocked(task.id, true) }
        setResumeNote(Planner.blockedNote(reason), for: task.id)
    }

    func unblock(_ task: TodoTask) {
        commit { $0.setBlocked(task.id, false) }
    }

    // MARK: Projets

    @discardableResult
    func addProject(named name: String, parentID: String? = nil) -> Project? {
        var created: Project?
        commit { created = $0.addProject(named: name, parentID: parentID) }
        return created
    }

    /// Range un projet sous un autre, ou le remonte au premier niveau (`nil`).
    func moveProject(_ id: String, under parentID: String?) {
        commit { $0.moveProject(id, under: parentID) }
    }

    func renameProject(_ id: String, to name: String) {
        commit { $0.renameProject(id, to: name) }
    }

    func shiftProject(_ id: String, by offset: Int) {
        commit { $0.shiftProject(id, by: offset) }
    }

    /// Supprime le projet ; ses tâches passent dans l'Inbox.
    func deleteProject(_ id: String) {
        commit { $0.deleteProject(id) }
    }

    // MARK: Réunions

    @discardableResult
    func addMeeting(title: String, start: Date, end: Date) -> Meeting? {
        var created: Meeting?
        commit { created = $0.addMeeting(title: title, start: start, end: end) }
        return created
    }

    func deleteMeeting(_ id: String) {
        commit { $0.deleteMeeting(id) }
    }

    func updateMeeting(_ meeting: Meeting) {
        commit { $0.updateMeeting(meeting) }
    }

    /// Reprogramme les rappels des réunions des sept prochains jours, après chaque changement
    /// de réunion ou de réglage.
    func updateMeetingReminders() {
        let rules = rules
        guard rules.meetingReminder else {
            Notifier.shared.updateMeetingReminders([])
            return
        }
        let now = Date.now
        let limit = now.addingTimeInterval(7 * 86_400)
        let meetings = store.upcomingMeetings(after: now).filter { $0.start < limit }
        // macOS garde 64 notifications en attente par app : on reste loin de la limite.
        let reminders = MeetingReminder.plan(meetings, now: now, minutes: rules.meetingReminderMinutes)
        Notifier.shared.updateMeetingReminders(Array(reminders.prefix(40)))
    }

    // MARK: Bilan du soir

    var isReviewDue: Bool {
        Review.isDue(now: .now, rules: rules, hasPlan: todayPlan != nil, lastReviewDay: lastReviewDay)
    }

    var reviewDoneToday: Bool { lastReviewDay == Format.dayKey(.now) }

    /// Tâches reportées par le dernier bilan, encore ouvertes, à proposer dans le plan d'aujourd'hui.
    var carriedOverIDs: [String] {
        (carryOver?.taskIDs(availableOn: Format.dayKey(.now)) ?? []).filter { index[$0] != nil }
    }

    func completeReview(_ carry: CarryOver) {
        carryOver = carry
        lastReviewDay = carry.fromDay
        let defaults = UserDefaults.standard
        defaults.set(try? JSONEncoder().encode(carry), forKey: Self.carryOverKey)
        defaults.set(carry.fromDay, forKey: Self.lastReviewKey)
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
        if carryOver?.taskIDs(availableOn: Format.dayKey(.now)).isEmpty == false {
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

    /// Ajoute une tâche en fin de plan du jour.
    func addToPlan(_ id: String) {
        guard let plan = todayPlan else {
            savePlan([id])
            return
        }
        guard !plan.taskIDs.contains(id), plan.taskIDs.count < Rules.maxPlanSize else { return }
        plan.taskIDs.append(id)
        save()
    }

    private func loadPlan() {
        let start = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<DayPlan>(predicate: #Predicate { $0.day == start })
        plan = (try? context.fetch(descriptor))?.first
        // Une tâche supprimée ou d'une ancienne version de Done ne reste pas dans le plan.
        if let plan, plan.taskIDs.contains(where: { index[$0] == nil }) {
            plan.taskIDs.removeAll { index[$0] == nil }
            save()
        }
    }

    // MARK: Connecteur Claude

    /// Au lancement : reprend ce que le connecteur Claude écrit dans le dossier de Done pendant que
    /// l'app est ouverte.
    func startWatching() {
        guard watcher == nil else { return }
        watcher = FolderWatcher(folder: storage.folder) { [weak self] in self?.syncFromDisk() }
        watcher?.start()
    }

    /// Relit les tâches si le connecteur les a changées, et applique le plan du jour qu'il demande.
    func syncFromDisk() {
        reloadIfChanged()
        applyPlanRequest()
    }

    /// Le plan du jour demandé par le connecteur, appliqué puis effacé. Seules les tâches encore
    /// ouvertes sont retenues.
    func applyPlanRequest() {
        guard let request = planFiles.takeRequest() else { return }
        let open = Set(index.all.map(\.id))
        guard let ids = SharedPlan.accepted(request, openIDs: open, today: Format.dayKey(.now)) else { return }
        guard ids != planIDs else { return }
        savePlan(ids)
    }

    /// Relit tasks.json s'il a changé hors de Done, pour partir de la version du connecteur.
    private func reloadIfChanged() {
        guard canSave, let stamp = storage.stamp(), stamp != fileStamp else { return }
        guard let loaded = try? storage.load() else { return }
        fileStamp = stamp
        guard loaded != store else { return }
        adopt(loaded)
    }

    /// Prend les tâches relues sur le disque, comme si les changements avaient été faits dans Done :
    /// rappels de réunion, notes de reprise et plan du jour suivent.
    private func adopt(_ loaded: TaskStore) {
        let meetingsChanged = loaded.meetings != store.meetings
        store = loaded
        index = TaskIndex(store.openTasks)
        if meetingsChanged { updateMeetingReminders() }
        let open = Set(store.openTasks.map(\.id))
        updateResumeNotes { $0.keepOnly(open) }
        // Une tâche du plan cochée par Claude en sort, et compte parmi les tâches faites du jour.
        if let plan = todayPlan, plan.taskIDs.contains(where: { !open.contains($0) }) {
            let closed = plan.taskIDs.filter { !open.contains($0) }
            plan.taskIDs.removeAll { !open.contains($0) }
            for id in closed where store[id] != nil && !plan.doneIDs.contains(id) {
                plan.doneIDs.append(id)
            }
            save()
        }
    }

    /// Publie le plan du jour (plan.json) pour le connecteur, qui n'ouvre pas la base locale.
    private func publishPlan() {
        guard let plan = todayPlan else { return }
        // En cas d'échec, Claude voit seulement un plan moins à jour : rien à signaler.
        try? planFiles.publish(PlanSnapshot(day: Format.dayKey(plan.day), taskIDs: plan.taskIDs, doneIDs: plan.doneIDs))
    }

    // MARK: Enregistrement

    /// Applique un changement aux tâches, met l'index à jour et réécrit le fichier.
    private func commit(_ change: (inout TaskStore) -> Void) {
        // Sous verrou : le connecteur Claude n'écrit pas entre la relecture et l'écriture.
        storage.withLock {
            reloadIfChanged()
            var next = store
            change(&next)
            guard next != store else { return }
            let meetingsChanged = next.meetings != store.meetings
            store = next
            index = TaskIndex(store.openTasks)
            persist()
            if meetingsChanged { updateMeetingReminders() }
        }
    }

    private func persist() {
        guard canSave else { return }
        do {
            try storage.save(store)
            fileStamp = storage.stamp()
        } catch {
            errorMessage = "Les tâches n'ont pas pu être enregistrées : \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            errorMessage = "Enregistrement local impossible : \(error.localizedDescription)"
        }
        publishPlan()
    }
}
