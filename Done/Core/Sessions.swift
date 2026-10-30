import Foundation

enum SessionOutcome: String, Codable {
    case inProgress
    /// La tâche a été cochée.
    case done
    /// Temps écoulé ou session arrêtée, tâche pas encore finie.
    case partial
    /// Session abandonnée après une interruption.
    case interrupted
    /// L'app a été quittée pendant la session.
    case abandoned
}

enum InterruptionReason: String, Codable, CaseIterable, Identifiable {
    case meeting
    case urgent
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .meeting: "Réunion"
        case .urgent: "Urgence"
        case .other: "Autre"
        }
    }

    var symbol: String {
        switch self {
        case .meeting: "person.2"
        case .urgent: "exclamationmark.triangle"
        case .other: "ellipsis.circle"
        }
    }
}

/// Vue figée d'une session enregistrée, utilisée par les calculs de stats.
struct SessionFact {
    let startedAt: Date
    let focusedSeconds: Double
    let projectName: String
    let outcome: SessionOutcome
    let interruptions: [InterruptionReason]
}

/// Pause due avant de passer à une autre tâche principale, posée à la fin d'une session
/// qui n'a pas été suivie d'une pause.
struct BreakDue: Equatable {
    let rootID: String
    let minutes: Int
    let since: Date

    /// Une autre tâche principale attend la pause ; la même tâche peut reprendre tout de suite.
    /// Le temps passé depuis la fin de la session compte comme une pause (réunion, déjeuner…).
    func blocks(rootID other: String, now: Date = .now) -> Bool {
        other != rootID && now < end
    }

    /// Minutes de pause encore dues, arrondies au-dessus.
    func remainingMinutes(now: Date = .now) -> Int {
        max(0, Int((end.timeIntervalSince(now) / 60).rounded(.up)))
    }

    private var end: Date { since.addingTimeInterval(TimeInterval(minutes * 60)) }
}
