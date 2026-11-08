import Foundation

/// Recherche globale (⌘K) : tâches ouvertes, notes et réunions, sans tenir compte des majuscules ni des
/// accents. Tous les mots de la recherche doivent se trouver dans la fiche. Un titre qui commence par
/// la recherche passe devant, puis un titre qui contient tous les mots, puis le reste (projet et
/// étiquettes d'une tâche, texte d'une note).
enum GlobalSearch {
    struct Results: Equatable {
        var tasks: [TodoTask] = []
        var notes: [Note] = []
        var meetings: [Meeting] = []

        var isEmpty: Bool { tasks.isEmpty && notes.isEmpty && meetings.isEmpty }
        var count: Int { tasks.count + notes.count + meetings.count }
    }

    /// Les résultats de `query`, `limit` au plus par groupe. Une recherche vide ne trouve rien.
    static func run(
        _ query: String,
        tasks: [TodoTask],
        projectName: (String) -> String?,
        notes: [Note],
        meetings: [Meeting],
        limit: Int = 5
    ) -> Results {
        let words = fold(query).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return Results() }
        let whole = words.joined(separator: " ")

        func rank(title: String, other: String) -> Int? {
            let title = fold(title)
            if title.hasPrefix(whole) { return 0 }
            if words.allSatisfy({ title.contains($0) }) { return 1 }
            let all = title + " " + fold(other)
            return words.allSatisfy({ all.contains($0) }) ? 2 : nil
        }

        let foundTasks = tasks
            .filter(\.isOpen)
            .compactMap { task -> (TodoTask, Int)? in
                let other = ([task.projectID.flatMap(projectName)].compactMap { $0 } + task.tags).joined(separator: " ")
                return rank(title: task.title, other: other).map { (task, $0) }
            }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 < b.1 }
                if a.0.priority != b.0.priority { return a.0.priority < b.0.priority }
                return a.0.title.localizedStandardCompare(b.0.title) == .orderedAscending
            }
            .prefix(limit)
            .map(\.0)

        let foundNotes = notes
            .compactMap { note -> (Note, Int)? in
                rank(title: note.title, other: note.body + " " + note.tags.joined(separator: " ")).map { (note, $0) }
            }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 < b.1 }
                return a.0.updatedAt > b.0.updatedAt
            }
            .prefix(limit)
            .map(\.0)

        let foundMeetings = meetings
            .compactMap { meeting -> (Meeting, Int)? in
                rank(title: meeting.title, other: "").map { (meeting, $0) }
            }
            .sorted { a, b in
                if a.1 != b.1 { return a.1 < b.1 }
                return a.0.start < b.0.start
            }
            .prefix(limit)
            .map(\.0)

        return Results(tasks: Array(foundTasks), notes: Array(foundNotes), meetings: Array(foundMeetings))
    }

    /// Minuscules, sans accents.
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
    }
}
