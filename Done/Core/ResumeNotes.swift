import Foundation

/// Note laissée en quittant une tâche non finie, réaffichée quand elle revient.
struct ResumeNote: Codable, Equatable {
    let text: String
    let writtenAt: Date
}

/// Notes de reprise par identifiant de tâche. Gardées dans UserDefaults (`resume.notes`),
/// effacées quand la tâche est cochée ou supprimée.
struct ResumeNotes: Codable, Equatable {
    /// Une ligne : au-delà, la note est coupée.
    static let maxLength = 280

    private(set) var byTask: [String: ResumeNote] = [:]

    subscript(taskID: String) -> ResumeNote? { byTask[taskID] }

    /// Un texte vide efface la note. Un texte identique garde la date d'origine.
    mutating func set(_ text: String, for taskID: String, at date: Date = .now) {
        let trimmed = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxLength))
        if trimmed.isEmpty {
            byTask[taskID] = nil
        } else if byTask[taskID]?.text != trimmed {
            byTask[taskID] = ResumeNote(text: trimmed, writtenAt: date)
        }
    }

    mutating func remove(_ taskID: String) {
        byTask[taskID] = nil
    }

    /// Ne garde que les notes des tâches encore ouvertes.
    mutating func keepOnly(_ openIDs: Set<String>) {
        byTask = byTask.filter { openIDs.contains($0.key) }
    }
}
