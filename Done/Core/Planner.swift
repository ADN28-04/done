import Foundation

/// Index en mémoire des tâches ouvertes, avec l'arborescence parent / sous-tâches.
struct TaskIndex {
    private(set) var all: [TodoTask] = []
    private var byID: [String: TodoTask] = [:]
    private var childrenByParent: [String: [TodoTask]] = [:]

    init(_ tasks: [TodoTask] = []) {
        all = tasks
        var byID: [String: TodoTask] = [:]
        var children: [String: [TodoTask]] = [:]
        for task in tasks {
            byID[task.id] = task
            if let parent = task.parentID {
                children[parent, default: []].append(task)
            }
        }
        self.byID = byID
        self.childrenByParent = children.mapValues { $0.sorted { $0.position < $1.position } }
    }

    subscript(id: String) -> TodoTask? { byID[id] }

    func children(of id: String) -> [TodoTask] { childrenByParent[id] ?? [] }

    func ancestors(of task: TodoTask) -> [TodoTask] {
        var result: [TodoTask] = []
        var next = task.parentID
        while let id = next, let parent = byID[id], result.count < 20 {
            result.append(parent)
            next = parent.parentID
        }
        return result
    }

    func root(of task: TodoTask) -> TodoTask { ancestors(of: task).last ?? task }

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
    var planTask: TodoTask?
    /// Prochaine action concrète : la première sous-tâche faisable, ou la tâche elle-même.
    var action: TodoTask?
    var minutes = 0
    /// Position dans le plan, à partir de 1. 0 pour une tâche hors plan.
    var position = 0
    var planCount = 0
    var note: String?
    var nextMeeting: Meeting?
    var ongoing: Meeting?
    var minutesBeforeMeeting: Int?
    var preparation: TodoTask?

    init(status: Status) {
        self.status = status
    }
}

enum Planner {
    static func isBlocked(_ task: TodoTask) -> Bool {
        task.isBlocked
    }

    /// Dernier jour couvert par l'horizon « Échéance proche ».
    static func horizonLimit(rules: Rules, now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: rules.horizonDays, to: today) ?? today
    }

    /// Tâche datée exprès au-delà de l'horizon : elle attend sa date, Done ne la propose pas avant.
    static func isScheduledLater(_ task: TodoTask, rules: Rules, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let day = task.due else { return false }
        return day > horizonLimit(rules: rules, now: now, calendar: calendar)
    }

    /// Candidates du rituel du matin : les tâches P1 et P2, et toutes celles dont l'échéance est proche
    /// ou dépassée. Ni bloquées, ni datées plus tard. Une sous-tâche n'apparaît pas si son parent
    /// est déjà candidat.
    static func candidates(in index: TaskIndex, rules: Rules, now: Date = .now, calendar: Calendar = .current) -> [TodoTask] {
        let limit = horizonLimit(rules: rules, now: now, calendar: calendar)
        let eligible = index.all.filter { task in
            guard !isBlocked(task), !isScheduledLater(task, rules: rules, now: now, calendar: calendar) else { return false }
            if task.priority <= 2 { return true }
            if let day = task.due, day <= limit { return true }
            return false
        }
        let ids = Set(eligible.map(\.id))
        return eligible
            .filter { task in !index.ancestors(of: task).contains { ids.contains($0.id) } }
            .sorted(by: priorityOrder)
    }

    /// Priorité d'abord, puis échéance la plus proche, puis ordre alphabétique.
    static func priorityOrder(_ a: TodoTask, _ b: TodoTask) -> Bool {
        if a.priority != b.priority { return a.priority < b.priority }
        let dueA = a.due ?? .distantFuture
        let dueB = b.due ?? .distantFuture
        if dueA != dueB { return dueA < dueB }
        return a.title.localizedCompare(b.title) == .orderedAscending
    }

    /// Première action faisable en descendant dans les sous-tâches, dans l'ordre de la liste.
    /// Les sous-tâches datées plus tard sont sautées ; la tâche de départ, choisie à la main, ne l'est pas.
    /// `nil` quand tout ce qui reste est bloqué ou daté plus tard.
    static func nextAction(for task: TodoTask, in index: TaskIndex, rules: Rules, now: Date = .now, depth: Int = 0) -> TodoTask? {
        guard !isBlocked(task), depth < 10 else { return nil }
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

    /// Jour où une tâche redevient faisable, quand ce sont des sous-tâches datées plus tard
    /// qui la bloquent. `nil` si ce sont des étapes bloquées.
    static func resumeDay(of task: TodoTask, in index: TaskIndex, rules: Rules, now: Date = .now) -> Date? {
        var queue = index.children(of: task.id)
        var days: [Date] = []
        while let next = queue.popLast() {
            guard !isBlocked(next) else { continue }
            if isScheduledLater(next, rules: rules, now: now), let day = next.due {
                days.append(day)
            } else {
                queue.append(contentsOf: index.children(of: next.id))
            }
        }
        return days.min()
    }

    /// Durée selon le type de l'action, puis celui de la tâche du plan.
    static func minutes(for action: TodoTask, root: TodoTask, rules: Rules) -> Int {
        for task in [action, root] {
            switch task.kind {
            case .quick: return rules.quickMinutes
            case .deepwork: return rules.deepworkMinutes
            case .normal: continue
            }
        }
        return rules.defaultMinutes
    }

    private struct Option {
        let position: Int
        let root: TodoTask
        let action: TodoTask
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
        if !ignoreMeetings, let next = meetings.first(where: { $0.start > now }) {
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

        // Aucune tâche du plan ne tient : une tâche rapide hors plan, si elle existe.
        if rules.quickMinutes <= available {
            let quick = index.all
                .filter { task in
                    task.kind == .quick
                        && !isBlocked(task)
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
                !isBlocked(task) && task.title.localizedCaseInsensitiveContains(next.title)
            }
        }
        return base
    }
}
