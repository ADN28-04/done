import Foundation

// Suite d'une étape cochée ou bloquée, découpage en étapes et bilan du soir.

extension Planner {
    /// Suite d'une action cochée, pour ne pas perdre le fil d'une tâche découpée.
    enum FollowUp: Equatable {
        /// Étape suivante de la même tâche principale.
        case step(TodoTask)
        /// Toutes les étapes sont faites : reste à cocher la tâche principale.
        case closeRoot(TodoTask)
        /// La tâche principale est finie ou bloquée : on passe à une autre.
        case switchTask
    }

    /// Ce qui vient après `action`, une fois cochée. `index` ne la contient déjà plus.
    static func followUp(after action: TodoTask, root: TodoTask, in index: TaskIndex, rules: Rules, now: Date = .now) -> FollowUp {
        guard let liveRoot = index[root.id],
              let next = nextAction(for: liveRoot, in: index, rules: rules, now: now) else { return .switchTask }
        return next.id == liveRoot.id ? .closeRoot(liveRoot) : .step(next)
    }

    /// Ce qui vient après une étape bloquée, laissée ouverte. Tant qu'elle reste ouverte,
    /// la tâche principale ne peut pas être close : faute d'autre étape, on change de tâche.
    static func followUp(blocking action: TodoTask, root: TodoTask, in index: TaskIndex, rules: Rules, now: Date = .now) -> FollowUp {
        guard action.id != root.id else { return .switchTask }
        let next = followUp(after: action, root: root, in: index.removing(action.id), rules: rules, now: now)
        if case .closeRoot = next { return .switchTask }
        return next
    }

    /// Note de reprise d'une étape bloquée, réaffichée quand elle revient.
    static func blockedNote(_ reason: String) -> String {
        "Bloqué : \(reason.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    /// Étapes encore ouvertes au même niveau que `action`, sans elle. `nil` pour une tâche sans parent.
    static func stepsAfter(_ action: TodoTask, in index: TaskIndex) -> Int? {
        guard let parentID = action.parentID else { return nil }
        return index.children(of: parentID).filter { $0.id != action.id && !isBlocked($0) }.count
    }

    /// Toute action peut être découpée en étapes plus petites, sauf une tâche rapide.
    static func canBreakDown(action: TodoTask, root: TodoTask) -> Bool {
        action.kind != .quick && root.kind != .quick
    }

    /// Une tâche du plan sans sous-tâche gagne à être découpée en étapes, sauf si elle est déjà rapide.
    static func needsBreakdown(action: TodoTask, root: TodoTask, in index: TaskIndex) -> Bool {
        action.id == root.id
            && index.children(of: root.id).isEmpty
            && root.kind != .quick
    }
}

/// Tâches du plan à reporter au prochain plan du matin.
struct CarryOver: Codable, Equatable {
    /// Jour du bilan, au format `Format.dayKey`.
    let fromDay: String
    let taskIDs: [String]

    /// Les tâches reportées servent au premier plan qui suit le jour du bilan.
    func taskIDs(availableOn day: String) -> [String] {
        fromDay < day ? taskIDs : []
    }
}

enum Review {
    struct DaySummary: Equatable {
        var focusMinutes = 0.0
        var sessions = 0
        var checked = 0
        var interruptions = 0
    }

    enum Decision: String, CaseIterable, Identifiable {
        case tomorrow, later
        var id: String { rawValue }

        var label: String {
            switch self {
            case .tomorrow: "Demain"
            case .later: "Plus tard"
            }
        }
    }

    static func summary(_ sessions: [SessionFact], on day: Date, calendar: Calendar = .current) -> DaySummary {
        let today = sessions.filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
        return DaySummary(
            focusMinutes: Stats.totalMinutes(today),
            sessions: today.count,
            checked: today.filter { $0.outcome == .done }.count,
            interruptions: today.reduce(0) { $0 + $1.interruptions.count }
        )
    }

    /// Tâches du plan encore ouvertes, dans l'ordre du plan.
    static func unfinished(plan: [String], index: TaskIndex) -> [TodoTask] {
        plan.compactMap { index[$0] }
    }

    /// Le bilan est proposé une fois par jour, à partir de l'heure réglée, s'il y a eu un plan.
    static func isDue(now: Date, rules: Rules, hasPlan: Bool, lastReviewDay: String?, calendar: Calendar = .current) -> Bool {
        guard hasPlan, lastReviewDay != Format.dayKey(now) else { return false }
        return calendar.component(.hour, from: now) >= rules.reviewHour
    }

    static func carryOver(_ decisions: [String: Decision], plan: [String], on day: Date) -> CarryOver {
        CarryOver(fromDay: Format.dayKey(day), taskIDs: plan.filter { decisions[$0, default: .tomorrow] == .tomorrow })
    }
}
