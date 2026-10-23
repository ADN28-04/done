import Foundation

/// Fichiers joints à chaque tâche pour le découpage avec Claude : des chemins sur le Mac,
/// gardés dans UserDefaults (`attachments.byTask`) et retirés quand la tâche disparaît.
struct TaskAttachments: Codable, Equatable {
    private(set) var byTask: [String: [String]] = [:]

    subscript(taskID: String) -> [String] { byTask[taskID] ?? [] }

    /// Ajoute sans doublon, dans la limite de `Breakdown.maxAttachments`.
    /// Renvoie les chemins refusés faute de place.
    @discardableResult
    mutating func add(_ paths: [String], to taskID: String) -> [String] {
        var current = self[taskID]
        var refused: [String] = []
        for path in paths where !current.contains(path) {
            if current.count < Breakdown.maxAttachments {
                current.append(path)
            } else {
                refused.append(path)
            }
        }
        byTask[taskID] = current.isEmpty ? nil : current
        return refused
    }

    mutating func remove(_ path: String, from taskID: String) {
        let remaining = self[taskID].filter { $0 != path }
        byTask[taskID] = remaining.isEmpty ? nil : remaining
    }

    mutating func removeAll(for taskID: String) {
        byTask[taskID] = nil
    }

    /// Ne garde que les pièces jointes des tâches encore ouvertes.
    mutating func keepOnly(_ openIDs: Set<String>) {
        byTask = byTask.filter { openIDs.contains($0.key) }
    }
}
