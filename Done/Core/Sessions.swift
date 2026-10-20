import Foundation

enum SessionOutcome: String, Codable {
    case inProgress
    /// La tâche a été cochée dans Todoist.
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
