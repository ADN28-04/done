import Foundation

/// Un rappel de la liste de capture (« Done » par défaut), tel que Rappels le donne.
struct ReminderItem: Equatable {
    let id: String
    var title: String
    var notes = ""
    var url: String?
    /// Jour d'échéance, s'il y en a un.
    var due: Date?
    /// Priorité de Rappels : 0 aucune, 1 à 4 haute, 5 moyenne, 6 à 9 basse.
    var priority = 0
    var isCompleted = false
}

/// Ce qu'un rappel fait dans Done.
enum ReminderAction: Equatable {
    /// Nouvelle tâche, dans l'Inbox.
    case create(TaskDraft)
    /// La tâche ouverte du même titre, avec les détails du rappel.
    case update(TodoTask)
    /// Rappel coché : la tâche ouverte du même titre est cochée.
    case complete(String)
    /// Rien à faire : titre vide, ou rappel coché sans tâche correspondante.
    case ignore
    /// Plusieurs tâches ouvertes portent ce titre : le rappel attend qu'on le précise.
    case ambiguous(Int)
}

/// Règles de la boîte d'arrivée Rappels. Un rappel au titre d'une tâche ouverte (casse, accents et
/// espaces ignorés) la met à jour, ou la coche s'il est coché ; sinon il devient une tâche de l'Inbox.
/// Le rappel est ensuite supprimé de Rappels, sauf s'il est ambigu.
enum RemindersInbox {
    static func action(for item: ReminderItem, in store: TaskStore) -> ReminderAction {
        guard !matchKey(item.title).isEmpty else { return .ignore }
        let matches = store.openTasks(titled: item.title)
        if matches.count > 1 { return .ambiguous(matches.count) }
        if item.isCompleted {
            return matches.first.map { .complete($0.id) } ?? .ignore
        }
        let extra = details(of: item)
        guard var task = matches.first else {
            return .create(TaskDraft(
                title: item.title,
                notes: extra,
                priority: priority(fromReminder: item.priority) ?? 4,
                due: item.due
            ))
        }
        if let due = item.due { task.due = due }
        if let priority = priority(fromReminder: item.priority) { task.priority = priority }
        if !extra.isEmpty, !task.notes.contains(extra) {
            task.notes = task.notes.isEmpty ? extra : task.notes + "\n\n" + extra
        }
        return .update(task)
    }

    /// Haute : P1, moyenne : P2, basse : P3. Sans priorité, la tâche garde la sienne (P4 si elle est nouvelle).
    static func priority(fromReminder value: Int) -> Int? {
        switch value {
        case 1...4: 1
        case 5: 2
        case 6...9: 3
        default: nil
        }
    }

    /// Notes et lien du rappel, à reporter dans les notes de la tâche.
    static func details(of item: ReminderItem) -> String {
        [item.notes.trimmingCharacters(in: .whitespacesAndNewlines), item.url ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// Clé de comparaison des titres : sans casse, sans accents, espaces réduits.
    static func matchKey(_ title: String) -> String {
        title.split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
    }
}

extension TaskStore {
    /// Tâches ouvertes, étapes comprises, dont le titre correspond (casse, accents et espaces ignorés).
    func openTasks(titled title: String) -> [TodoTask] {
        let key = RemindersInbox.matchKey(title)
        guard !key.isEmpty else { return [] }
        return openTasks.filter { RemindersInbox.matchKey($0.title) == key }
    }
}
