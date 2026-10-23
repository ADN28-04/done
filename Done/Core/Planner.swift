import Foundation

/// Index en mémoire des tâches ouvertes, avec l'arborescence parent / sous-tâches.
struct TaskIndex {
    private(set) var all: [TodoistTask] = []
    private var byID: [String: TodoistTask] = [:]
    private var childrenByParent: [String: [TodoistTask]] = [:]

    init(_ tasks: [TodoistTask] = []) {
        all = tasks
        var byID: [String: TodoistTask] = [:]
        var children: [String: [TodoistTask]] = [:]
        for task in tasks {
            byID[task.id] = task
            if let parent = task.parentId {
                children[parent, default: []].append(task)
            }
        }
        self.byID = byID
        self.childrenByParent = children.mapValues { $0.sorted { $0.childOrder < $1.childOrder } }
    }

    subscript(id: String) -> TodoistTask? { byID[id] }

    func children(of id: String) -> [TodoistTask] { childrenByParent[id] ?? [] }

    func ancestors(of task: TodoistTask) -> [TodoistTask] {
        var result: [TodoistTask] = []
        var next = task.parentId
        while let id = next, let parent = byID[id], result.count < 20 {
            result.append(parent)
            next = parent.parentId
        }
        return result
    }

    func root(of task: TodoistTask) -> TodoistTask { ancestors(of: task).last ?? task }

    /// Index sans la tâche ni ses sous-tâches, après l'avoir cochée.
    func removing(_ id: String) -> TaskIndex {
        var dropped: Set<String> = [id]
        var queue = [id]
        while let next = queue.popLast() {
            for child in children(of: next) {
                if dropped.insert(child.id).inserted {
                    queue.append(child.id)
                }
            }
        }
        return TaskIndex(all.filter { !dropped.contains($0.id) })
    }

    /// Index où `task` remplace sa version précédente, après une écriture dans Todoist.
    func replacing(_ task: TodoistTask) -> TaskIndex {
        TaskIndex(all.map { $0.id == task.id ? task : $0 })
    }
}

/// Créneau lu dans Todoist : une réunion, ou un bloc de travail posé dans l'agenda.
struct Meeting: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isFocusBlock: Bool

    func contains(_ date: Date) -> Bool { start <= date && date < end }
}

/// Ce que l'écran Focus propose de faire maintenant.
struct Suggestion {
    enum Status: Equatable {
        case ready
        case planEmpty
        case allBlocked
        case noTimeBeforeMeeting
    }

    var status: Status
    /// Tâche du plan (ou tâche racine) à laquelle appartient l'action.
    var planTask: TodoistTask?
    /// Prochaine action concrète : la première sous-tâche faisable, ou la tâche elle-même.
    var action: TodoistTask?
    var minutes = 0
    /// Position dans le plan, à partir de 1. 0 pour une tâche hors plan.
    var position = 0
    var planCount = 0
    var note: String?
    var nextMeeting: Meeting?
    var ongoing: Meeting?
    var minutesBeforeMeeting: Int?
    var preparation: TodoistTask?

    init(status: Status) {
        self.status = status
    }
}

enum Planner {
    static func isWaiting(_ task: TodoistTask) -> Bool {
        task.hasLabel(Rules.waitingLabel)
    }

    /// Dernier jour couvert par l'horizon « Échéance proche ».
    static func horizonLimit(rules: Rules, now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: rules.horizonDays, to: today) ?? today
    }

    /// Tâche datée exprès au-delà de l'horizon : elle attend sa date, Done ne la propose pas avant.
    /// Une échéance Todoist (deadline) dans l'horizon l'emporte sur la date.
    static func isScheduledLater(_ task: TodoistTask, rules: Rules, now: Date = .now, calendar: Calendar = .current) -> Bool {
        let limit = horizonLimit(rules: rules, now: now, calendar: calendar)
        guard let day = task.due?.day, day > limit else { return false }
        if let deadline = task.deadline?.day, deadline <= limit { return false }
        return true
    }

    static func isMeeting(_ task: TodoistTask, rules: Rules) -> Bool {
        guard let due = task.due, due.hasTime, !rules.meetingPrefix.isEmpty else { return false }
        return task.content.hasPrefix(rules.meetingPrefix)
    }

    static func meetingTitle(_ task: TodoistTask, rules: Rules) -> String {
        var title = task.content
        if !rules.meetingPrefix.isEmpty, title.hasPrefix(rules.meetingPrefix) {
            title = String(title.dropFirst(rules.meetingPrefix.count))
        }
        return title.trimmingCharacters(in: CharacterSet(charactersIn: " ·:-–"))
    }

    /// Réunions et blocs du jour, triés par heure de début.
    static func meetings(in tasks: [TodoistTask], on day: Date, rules: Rules, calendar: Calendar = .current) -> [Meeting] {
        let keywords = rules.focusKeywords
        return tasks.compactMap { task -> Meeting? in
            guard isMeeting(task, rules: rules),
                  let start = task.due?.value,
                  calendar.isDate(start, inSameDayAs: day) else { return nil }
            let minutes = task.duration?.minutes ?? 30
            let title = meetingTitle(task, rules: rules)
            let lower = title.lowercased()
            return Meeting(
                id: task.id,
                title: title,
                start: start,
                end: start.addingTimeInterval(TimeInterval(minutes * 60)),
                isFocusBlock: keywords.contains { lower.contains($0) }
            )
        }
        .sorted { $0.start < $1.start }
    }

    /// Candidates du rituel du matin : P1/P2, hors Waiting, réunions et tâches datées plus tard,
    /// avec Chantier-actif ou une échéance proche. Une sous-tâche n'apparaît pas
    /// si son parent est déjà candidat.
    static func candidates(in index: TaskIndex, rules: Rules, now: Date = .now, calendar: Calendar = .current) -> [TodoistTask] {
        let limit = horizonLimit(rules: rules, now: now, calendar: calendar)
        let eligible = index.all.filter { task in
            guard !isMeeting(task, rules: rules), !isWaiting(task), task.priority >= 3,
                  !isScheduledLater(task, rules: rules, now: now, calendar: calendar) else { return false }
            if task.hasLabel(Rules.activeLabel) { return true }
            if let day = task.due?.day, day <= limit { return true }
            if let day = task.deadline?.day, day <= limit { return true }
            return false
        }
        let ids = Set(eligible.map(\.id))
        return eligible
            .filter { task in !index.ancestors(of: task).contains { ids.contains($0.id) } }
            .sorted(by: priorityOrder)
    }

    /// Priorité d'abord, puis échéance la plus proche, puis ordre alphabétique.
    static func priorityOrder(_ a: TodoistTask, _ b: TodoistTask) -> Bool {
        if a.priority != b.priority { return a.priority > b.priority }
        let dueA = a.due?.day ?? .distantFuture
        let dueB = b.due?.day ?? .distantFuture
        if dueA != dueB { return dueA < dueB }
        return a.content.localizedCompare(b.content) == .orderedAscending
    }

    /// Première action faisable en descendant dans les sous-tâches, dans l'ordre Todoist.
    /// Les sous-tâches datées plus tard sont sautées ; la tâche de départ, choisie à la main, ne l'est pas.
    /// `nil` quand tout ce qui reste est en Waiting ou daté plus tard.
    static func nextAction(for task: TodoistTask, in index: TaskIndex, rules: Rules, now: Date = .now, depth: Int = 0) -> TodoistTask? {
        guard !isWaiting(task), depth < 10 else { return nil }
        if depth > 0, isScheduledLater(task, rules: rules, now: now) { return nil }
        let children = index.children(of: task.id)
        if children.isEmpty { return task }
        for child in children {
            if let action = nextAction(for: child, in: index, rules: rules, now: now, depth: depth + 1) {
                return action
            }
        }
        return nil
    }

    /// Jour où une tâche bloquée redevient faisable, quand ce sont des sous-tâches datées plus tard
    /// qui la bloquent. `nil` si elle attend quelqu'un (Waiting).
    static func resumeDay(of task: TodoistTask, in index: TaskIndex, rules: Rules, now: Date = .now) -> Date? {
        var queue = index.children(of: task.id)
        var days: [Date] = []
        while let next = queue.popLast() {
            guard !isWaiting(next) else { continue }
            if isScheduledLater(next, rules: rules, now: now), let day = next.due?.day {
                days.append(day)
            } else {
                queue.append(contentsOf: index.children(of: next.id))
            }
        }
        return days.min()
    }

    /// Durée selon le label de l'action, puis celui de la tâche du plan.
    static func minutes(for action: TodoistTask, root: TodoistTask, rules: Rules) -> Int {
        for task in [action, root] {
            if task.hasLabel(Rules.quickLabel) { return rules.quickMinutes }
            if task.hasLabel(Rules.deepworkLabel) { return rules.deepworkMinutes }
        }
        return rules.defaultMinutes
    }

    private struct Option {
        let position: Int
        let root: TodoistTask
        let action: TodoistTask
        let minutes: Int
    }

    /// Choisit quoi proposer maintenant, en tenant compte de la prochaine réunion.
    static func suggest(
        plan: [String],
        index: TaskIndex,
        meetings: [Meeting],
        rules: Rules,
        now: Date = .now,
        ignoreMeetings: Bool = false
    ) -> Suggestion {
        let live = plan.compactMap { index[$0] }
        guard !live.isEmpty else { return Suggestion(status: .planEmpty) }

        var base = Suggestion(status: .ready)
        base.planCount = live.count
        base.ongoing = meetings.first { $0.contains(now) }
        if !ignoreMeetings, let next = meetings.first(where: { !$0.isFocusBlock && $0.start > now }) {
            base.nextMeeting = next
            base.minutesBeforeMeeting = Int(next.start.timeIntervalSince(now) / 60)
        }

        let options = live.enumerated().compactMap { offset, root -> Option? in
            guard let action = nextAction(for: root, in: index, rules: rules, now: now) else { return nil }
            return Option(position: offset + 1, root: root, action: action, minutes: minutes(for: action, root: root, rules: rules))
        }
        guard let first = options.first else {
            base.status = .allBlocked
            return base
        }

        func ready(_ option: Option, note: String? = nil) -> Suggestion {
            var suggestion = base
            suggestion.planTask = option.root
            suggestion.action = option.action
            suggestion.minutes = option.minutes
            suggestion.position = option.position
            suggestion.note = note
            return suggestion
        }

        guard let next = base.nextMeeting, let available = base.minutesBeforeMeeting else {
            return ready(first)
        }
        if first.minutes <= available {
            return ready(first)
        }

        let when = "« \(next.title) » commence à \(Format.time(next.start))"
        if let fitting = options.first(where: { $0.minutes <= available }) {
            return ready(fitting, note: "\(when) : cette tâche tient dans les \(available) min restantes.")
        }

        // Aucune tâche du plan ne tient : une tâche Quick hors plan, si elle existe.
        if rules.quickMinutes <= available {
            let quick = index.all
                .filter { task in
                    task.hasLabel(Rules.quickLabel)
                        && !isWaiting(task)
                        && !isMeeting(task, rules: rules)
                        && !isScheduledLater(task, rules: rules, now: now)
                        && index.children(of: task.id).isEmpty
                }
                .sorted(by: priorityOrder)
            if let task = quick.first {
                let option = Option(position: 0, root: index.root(of: task), action: task, minutes: rules.quickMinutes)
                return ready(option, note: "\(when) : une tâche rapide en attendant.")
            }
        }

        base.status = .noTimeBeforeMeeting
        if !next.title.isEmpty {
            base.preparation = index.all.first { task in
                !isMeeting(task, rules: rules) && task.content.localizedCaseInsensitiveContains(next.title)
            }
        }
        return base
    }
}
