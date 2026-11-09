import Foundation

/// Export des tâches, depuis Réglages › Données : un Markdown lisible (par projet, puis par
/// étiquette, étapes en retrait, cases à cocher) et un CSV pour un tableur ou un autre gestionnaire.
/// Les tâches ouvertes seulement, ou aussi les tâches faites. Chaque tâche n'apparaît qu'une fois.
enum TaskExport {
    enum Kind: CaseIterable {
        case markdown
        case csv

        var fileExtension: String {
            switch self {
            case .markdown: "md"
            case .csv: "csv"
            }
        }
    }

    /// « Done - tâches 2026-11-09 », sans extension : le panneau d'enregistrement l'ajoute.
    static func baseName(now: Date = .now) -> String {
        "Done - tâches \(Format.dayKey(now))"
    }

    /// « Done - tâches 2026-11-09.md ».
    static func fileName(_ kind: Kind, now: Date = .now) -> String {
        "\(baseName(now: now)).\(kind.fileExtension)"
    }

    static func text(_ kind: Kind, store: TaskStore, includeDone: Bool, now: Date = .now) -> String {
        switch kind {
        case .markdown: markdown(store, includeDone: includeDone, now: now)
        case .csv: csv(store, includeDone: includeDone)
        }
    }

    // MARK: Sections

    /// Une ligne de l'export : la tâche et sa profondeur (0 pour une tâche, 1 pour une étape…).
    struct Row: Equatable {
        let task: TodoTask
        let depth: Int
    }

    /// Un titre et ses lignes. Niveau 2 pour l'Inbox, un projet ou une étiquette ; 3 pour un sous-projet.
    struct Section: Equatable {
        let title: String
        let level: Int
        let rows: [Row]
    }

    /// L'Inbox, puis les projets dans l'ordre des listes (chacun suivi de ses sous-projets), puis les
    /// tâches sans projet rangées sous leur première étiquette. Dans chaque groupe, les tâches ouvertes
    /// dans leur ordre, puis les tâches faites, la plus récente d'abord ; chaque tâche suivie de ses étapes.
    static func sections(_ store: TaskStore, includeDone: Bool) -> [Section] {
        let kept = store.tasks.filter { includeDone || $0.isOpen }
        let keptIDs = Set(kept.map(\.id))
        let children = Dictionary(grouping: kept.filter { $0.parentID.map(keptIDs.contains) ?? false }) { $0.parentID ?? "" }
        // Une étape dont la tâche n'est pas exportée (faite, ou disparue) devient une tâche à part entière.
        let roots = kept.filter { !($0.parentID.map(keptIDs.contains) ?? false) }

        func rows(_ tasks: [TodoTask], depth: Int) -> [Row] {
            ordered(tasks).flatMap { task in
                [Row(task: task, depth: depth)] + rows(children[task.id] ?? [], depth: depth + 1)
            }
        }
        // Projet et étiquettes viennent de la tâche principale : une étape n'a pas d'étiquette à elle.
        func projectID(_ task: TodoTask) -> String? {
            store.project(store.rootTask(of: task).projectID)?.id
        }
        func tags(_ task: TodoTask) -> [String] {
            store.rootTask(of: task).tags
        }

        var sections: [Section] = []
        let inbox = roots.filter { projectID($0) == nil && tags($0).isEmpty }
        if !inbox.isEmpty {
            sections.append(Section(title: "Inbox", level: 2, rows: rows(inbox, depth: 0)))
        }
        for project in store.topLevelProjects {
            let own = rows(roots.filter { projectID($0) == project.id }, depth: 0)
            let subsections = store.subprojects(of: project.id).compactMap { sub -> Section? in
                let subRows = rows(roots.filter { projectID($0) == sub.id }, depth: 0)
                return subRows.isEmpty ? nil : Section(title: sub.name, level: 3, rows: subRows)
            }
            guard !own.isEmpty || !subsections.isEmpty else { continue }
            sections.append(Section(title: project.name, level: 2, rows: own))
            sections += subsections
        }
        let tagged = Dictionary(grouping: roots.filter { projectID($0) == nil && !tags($0).isEmpty }) { tags($0)[0] }
        for tag in tagged.keys.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }) {
            sections.append(Section(title: "#\(tag)", level: 2, rows: rows(tagged[tag] ?? [], depth: 0)))
        }
        return sections
    }

    /// Ouvertes dans leur ordre, puis faites, la plus récente d'abord.
    private static func ordered(_ tasks: [TodoTask]) -> [TodoTask] {
        tasks.filter(\.isOpen).sorted { $0.position < $1.position }
            + tasks.filter { !$0.isOpen }.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    // MARK: Markdown

    static func markdown(_ store: TaskStore, includeDone: Bool, now: Date = .now) -> String {
        let sections = sections(store, includeDone: includeDone)
        let all = sections.flatMap(\.rows).map(\.task)
        let open = all.filter(\.isOpen).count
        let done = all.count - open
        var count = count(open, "tâche ouverte", "tâches ouvertes")
        if includeDone { count += " et " + self.count(done, "faite", "faites") }

        var lines = ["# Tâches", "", "Export de Done du \(Format.fullDay(now)) : \(all.isEmpty ? "aucune tâche" : count)."]
        for section in sections {
            lines += ["", String(repeating: "#", count: section.level) + " " + section.title]
            guard !section.rows.isEmpty else { continue }
            lines.append("")
            for row in section.rows {
                let indent = String(repeating: "  ", count: row.depth)
                let box = row.task.isOpen ? "- [ ] " : "- [x] "
                let details = details(row.task, isStep: row.depth > 0)
                lines.append(indent + box + singleLine(row.task.title) + (details.isEmpty ? "" : " · " + details.joined(separator: " · ")))
                let notes = row.task.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                for note in notes.isEmpty ? [] : notes.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
                    let text = note.trimmingCharacters(in: .whitespaces)
                    lines.append(text.isEmpty ? "" : indent + "  " + text)
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Ce qui s'écarte des valeurs par défaut : priorité, type, échéance, répétition, étiquettes, blocage, fin.
    private static func details(_ task: TodoTask, isStep: Bool) -> [String] {
        var parts: [String] = []
        if task.priority < 4 { parts.append("P\(task.priority)") }
        if task.kind != .normal { parts.append(task.kind.label) }
        if let due = task.due { parts.append("échéance \(Format.fullDay(due))") }
        if let recurrence = task.recurrence { parts.append(recurrence.label) }
        if !isStep { parts += task.tags.map { "#\($0)" } }
        if task.isBlocked && task.isOpen { parts.append("bloquée") }
        if let completed = task.completedAt { parts.append("faite le \(Format.fullDay(completed))") }
        return parts
    }

    private static func singleLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    private static func count(_ value: Int, _ singular: String, _ plural: String) -> String {
        "\(value) \(value > 1 ? plural : singular)"
    }

    // MARK: CSV

    static let csvColumns = ["Titre", "Tâche parente", "Projet", "Étiquettes", "Priorité", "Type", "Échéance", "Répétition", "Bloquée", "Faite le", "Créée le", "Notes"]

    /// CSV séparé par des virgules (RFC 4180), en UTF-8 avec la marque d'ordre des octets pour que les
    /// tableurs lisent les accents. Les dates en clé de jour (« 2026-11-09 »), dans l'ordre du Markdown.
    static func csv(_ store: TaskStore, includeDone: Bool) -> String {
        let rows = sections(store, includeDone: includeDone).flatMap(\.rows)
        let lines = [csvColumns] + rows.map { row -> [String] in
            let task = row.task
            let root = store.rootTask(of: task)
            return [
                singleLine(task.title),
                row.depth > 0 ? task.parentID.flatMap { store[$0] }.map { singleLine($0.title) } ?? "" : "",
                store.projectPath(root.projectID) ?? "",
                root.tags.joined(separator: ", "),
                "P\(task.priority)",
                task.kind.label,
                task.due.map(Format.dayKey) ?? "",
                task.recurrence?.label ?? "",
                task.isBlocked ? "oui" : "",
                task.completedAt.map(Format.dayKey) ?? "",
                Format.dayKey(task.createdAt),
                task.notes,
            ]
        }
        return "\u{FEFF}" + lines.map { $0.map(csvField).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// Entre guillemets quand il le faut : virgule, guillemet ou retour à la ligne ; guillemets doublés.
    static func csvField(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
