import Foundation

/// Type de travail : il fixe la durée proposée pour une session.
enum TaskKind: String, Codable, CaseIterable, Identifiable {
    case normal
    case quick
    case deepwork

    var id: String { rawValue }

    var label: String {
        switch self {
        case .normal: "Normale"
        case .quick: "Rapide"
        case .deepwork: "Deepwork"
        }
    }
}

/// Une tâche de Done. Une sous-tâche pointe vers sa parente ; sans projet, la tâche est dans l'Inbox.
struct TodoTask: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var notes: String
    var projectID: String?
    var parentID: String?
    /// Ordre parmi les tâches de même niveau.
    var position: Int
    /// 1 = P1 (urgent) … 4 = P4 (normal).
    var priority: Int
    var kind: TaskKind
    /// Jour d'échéance, au début du jour. Enregistré sous forme de clé de jour (« 2026-10-31 »).
    var due: Date?
    /// Bloquée : Done ne la propose plus tant qu'elle n'est pas débloquée.
    var isBlocked: Bool
    let createdAt: Date
    var completedAt: Date?

    init(
        id: String = UUID().uuidString,
        title: String,
        notes: String = "",
        projectID: String? = nil,
        parentID: String? = nil,
        position: Int = 0,
        priority: Int = 4,
        kind: TaskKind = .normal,
        due: Date? = nil,
        isBlocked: Bool = false,
        createdAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.projectID = projectID
        self.parentID = parentID
        self.position = position
        self.priority = priority
        self.kind = kind
        self.due = due
        self.isBlocked = isBlocked
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    var isOpen: Bool { completedAt == nil }

    enum CodingKeys: String, CodingKey {
        case id, title, notes, projectID, parentID, position, priority, kind, due, isBlocked, createdAt, completedAt
    }

    // Lecture tolérante : un champ ajouté plus tard prend sa valeur par défaut dans un ancien fichier.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        projectID = try c.decodeIfPresent(String.self, forKey: .projectID)
        parentID = try c.decodeIfPresent(String.self, forKey: .parentID)
        position = try c.decodeIfPresent(Int.self, forKey: .position) ?? 0
        priority = min(max(try c.decodeIfPresent(Int.self, forKey: .priority) ?? 4, 1), 4)
        kind = try c.decodeIfPresent(String.self, forKey: .kind).flatMap(TaskKind.init(rawValue:)) ?? .normal
        due = try c.decodeIfPresent(String.self, forKey: .due).flatMap(Format.date(fromDayKey:))
        isBlocked = try c.decodeIfPresent(Bool.self, forKey: .isBlocked) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(notes, forKey: .notes)
        try c.encodeIfPresent(projectID, forKey: .projectID)
        try c.encodeIfPresent(parentID, forKey: .parentID)
        try c.encode(position, forKey: .position)
        try c.encode(priority, forKey: .priority)
        try c.encode(kind.rawValue, forKey: .kind)
        try c.encodeIfPresent(due.map(Format.dayKey), forKey: .due)
        try c.encode(isBlocked, forKey: .isBlocked)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
    }
}

struct Project: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    var position: Int
}

/// Réunion saisie à la main : Done en tient compte pour proposer une session qui tient avant.
struct Meeting: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var start: Date
    var end: Date

    func contains(_ date: Date) -> Bool { start <= date && date < end }
}

/// Projets, tâches (ouvertes et terminées) et réunions, enregistrés en JSON par `TaskStorage`.
/// Les opérations sont pures, pour être testées hors de l'app.
struct TaskStore: Codable, Equatable {
    static let currentVersion = 1

    var version = TaskStore.currentVersion
    var projects: [Project] = []
    var tasks: [TodoTask] = []
    var meetings: [Meeting] = []

    init() {}

    enum CodingKeys: String, CodingKey {
        case version, projects, tasks, meetings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? TaskStore.currentVersion
        projects = try c.decodeIfPresent([Project].self, forKey: .projects) ?? []
        tasks = try c.decodeIfPresent([TodoTask].self, forKey: .tasks) ?? []
        meetings = try c.decodeIfPresent([Meeting].self, forKey: .meetings) ?? []
    }

    subscript(id: String) -> TodoTask? {
        tasks.first { $0.id == id }
    }

    var openTasks: [TodoTask] { tasks.filter(\.isOpen) }

    var sortedProjects: [Project] { projects.sorted { $0.position < $1.position } }

    // MARK: Projets

    @discardableResult
    mutating func addProject(named name: String, id: String = UUID().uuidString) -> Project? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let project = Project(id: id, name: trimmed, position: (projects.map(\.position).max() ?? -1) + 1)
        projects.append(project)
        return project
    }

    mutating func renameProject(_ id: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[i].name = trimmed
    }

    /// Monte ou descend un projet d'un cran dans la liste.
    mutating func shiftProject(_ id: String, by offset: Int) {
        var ordered = sortedProjects
        guard let from = ordered.firstIndex(where: { $0.id == id }), ordered.indices.contains(from + offset) else { return }
        ordered.swapAt(from, from + offset)
        for (position, project) in ordered.enumerated() {
            if let i = projects.firstIndex(where: { $0.id == project.id }) { projects[i].position = position }
        }
    }

    /// Supprime le projet. Ses tâches ne sont pas perdues : elles passent en fin d'Inbox.
    mutating func deleteProject(_ id: String) {
        guard projects.contains(where: { $0.id == id }) else { return }
        projects.removeAll { $0.id == id }
        var next = nextPosition(parentID: nil, projectID: nil)
        for i in tasks.indices where tasks[i].projectID == id {
            tasks[i].projectID = nil
            if tasks[i].parentID == nil {
                tasks[i].position = next
                next += 1
            }
        }
    }

    // MARK: Tâches

    /// Ajoute une tâche en fin de liste. Une sous-tâche prend le projet de sa parente.
    @discardableResult
    mutating func addTask(title: String, projectID: String?, parentID: String? = nil, now: Date = .now, id: String = UUID().uuidString) -> TodoTask? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var project = projectID
        if let parentID {
            guard let parent = self[parentID] else { return nil }
            project = parent.projectID
        }
        if let id = project, !projects.contains(where: { $0.id == id }) { project = nil }
        let task = TodoTask(
            id: id,
            title: trimmed,
            projectID: project,
            parentID: parentID,
            position: nextPosition(parentID: parentID, projectID: project),
            createdAt: now
        )
        tasks.append(task)
        return task
    }

    /// Remplace la tâche du même identifiant. Un titre vide garde l'ancien titre.
    /// Changer de projet emmène les sous-tâches ; une sous-tâche reste dans le projet de sa parente.
    mutating func update(_ task: TodoTask) {
        guard let i = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updated = task
        let trimmed = updated.title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.title = trimmed.isEmpty ? tasks[i].title : trimmed
        updated.priority = min(max(updated.priority, 1), 4)
        updated.due = updated.due.map { Calendar.current.startOfDay(for: $0) }
        if let parentID = updated.parentID, let parent = self[parentID] {
            updated.projectID = parent.projectID
        } else if let id = updated.projectID, !projects.contains(where: { $0.id == id }) {
            updated.projectID = nil
        }
        let moved = tasks[i].projectID != updated.projectID
        if moved, updated.parentID == nil {
            updated.position = nextPosition(parentID: nil, projectID: updated.projectID)
        }
        tasks[i] = updated
        if moved {
            for id in descendants(of: task.id) {
                if let j = tasks.firstIndex(where: { $0.id == id }) { tasks[j].projectID = updated.projectID }
            }
        }
    }

    /// Coche la tâche et ses sous-tâches encore ouvertes.
    mutating func complete(_ id: String, at date: Date = .now) {
        for target in [id] + descendants(of: id) {
            if let i = tasks.firstIndex(where: { $0.id == target }), tasks[i].completedAt == nil {
                tasks[i].completedAt = date
            }
        }
    }

    /// Rouvre une tâche cochée, et ses parentes si elles l'étaient aussi.
    mutating func reopen(_ id: String) {
        var next: String? = id
        var guardCount = 0
        while let current = next, let i = tasks.firstIndex(where: { $0.id == current }), guardCount < 20 {
            tasks[i].completedAt = nil
            next = tasks[i].parentID
            guardCount += 1
        }
    }

    /// Supprime la tâche et ses sous-tâches.
    mutating func delete(_ id: String) {
        let dropped = Set([id] + descendants(of: id))
        tasks.removeAll { dropped.contains($0.id) }
    }

    mutating func setBlocked(_ id: String, _ blocked: Bool) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].isBlocked = blocked
    }

    /// Place `id` juste avant `target` parmi les tâches de même niveau, ou en fin de liste sans cible.
    /// Sans effet si les deux tâches ne sont pas au même niveau.
    mutating func move(_ id: String, before target: String?) {
        guard let task = self[id], target != id else { return }
        var ordered = siblings(parentID: task.parentID, projectID: task.projectID).filter { $0.id != id }
        if let target {
            guard let to = ordered.firstIndex(where: { $0.id == target }) else { return }
            ordered.insert(task, at: to)
        } else {
            ordered.append(task)
        }
        for (position, sibling) in ordered.enumerated() {
            if let i = tasks.firstIndex(where: { $0.id == sibling.id }) { tasks[i].position = position }
        }
    }

    /// Tâches de même niveau, ouvertes et terminées, dans l'ordre.
    func siblings(parentID: String?, projectID: String?) -> [TodoTask] {
        tasks
            .filter { task in
                guard task.parentID == parentID else { return false }
                return parentID != nil || task.projectID == projectID
            }
            .sorted { $0.position < $1.position }
    }

    /// Toutes les sous-tâches, à toutes les profondeurs, ouvertes ou non.
    func descendants(of id: String) -> [String] {
        var result: [String] = []
        var queue = [id]
        while let current = queue.popLast(), result.count < 10_000 {
            let children = tasks.filter { $0.parentID == current }.map(\.id)
            result += children
            queue += children
        }
        return result
    }

    private func nextPosition(parentID: String?, projectID: String?) -> Int {
        (siblings(parentID: parentID, projectID: projectID).map(\.position).max() ?? -1) + 1
    }

    // MARK: Réunions

    /// Ajoute une réunion. Sans titre, elle s'appelle « Réunion ».
    @discardableResult
    mutating func addMeeting(title: String, start: Date, end: Date, id: String = UUID().uuidString) -> Meeting? {
        guard end > start else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let meeting = Meeting(id: id, title: trimmed.isEmpty ? "Réunion" : trimmed, start: start, end: end)
        meetings.append(meeting)
        return meeting
    }

    mutating func deleteMeeting(_ id: String) {
        meetings.removeAll { $0.id == id }
    }

    /// Oublie les réunions finies avant `date`.
    mutating func pruneMeetings(endedBefore date: Date) {
        meetings.removeAll { $0.end < date }
    }

    /// Réunions d'un jour, par heure de début.
    func meetings(on day: Date, calendar: Calendar = .current) -> [Meeting] {
        meetings
            .filter { calendar.isDate($0.start, inSameDayAs: day) }
            .sorted { $0.start < $1.start }
    }

    /// Réunions qui finissent après `now`, par heure de début.
    func upcomingMeetings(after now: Date) -> [Meeting] {
        meetings.filter { $0.end > now }.sorted { $0.start < $1.start }
    }
}
