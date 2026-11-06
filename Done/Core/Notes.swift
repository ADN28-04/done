import Foundation

/// Type d'une note. Les cinq premiers se choisissent ; la page de projet et le journal sont créés
/// par Done (depuis la vue d'un projet, depuis Aujourd'hui).
enum NoteKind: String, CaseIterable, Identifiable {
    case note
    case meeting
    case decision
    case person
    case reference
    case project
    case journal

    var id: String { rawValue }

    /// Les types qu'on choisit en créant une note.
    static let creatable: [NoteKind] = [.note, .meeting, .decision, .person, .reference]

    var label: String {
        switch self {
        case .note: "Note"
        case .meeting: "Réunion"
        case .decision: "Décision"
        case .person: "Personne"
        case .reference: "Référence"
        case .project: "Page de projet"
        case .journal: "Journal"
        }
    }

    /// Pluriel, pour le filtre de l'écran Notes.
    var plural: String {
        switch self {
        case .note: "Notes"
        case .meeting: "Réunions"
        case .decision: "Décisions"
        case .person: "Personnes"
        case .reference: "Références"
        case .project: "Pages de projet"
        case .journal: "Journal"
        }
    }

    /// Symbole SF du type.
    var symbol: String {
        switch self {
        case .note: "doc.text"
        case .meeting: "person.2"
        case .decision: "checkmark.seal"
        case .person: "person"
        case .reference: "link"
        case .project: "folder"
        case .journal: "sun.max"
        }
    }
}

/// Une note : un fichier Markdown, avec un en-tête pour le type et les rattachements.
struct Note: Identifiable, Equatable {
    let id: String
    var kind: NoteKind
    var title: String
    var body: String
    /// Projet de rattachement (pour une page de projet : son projet).
    var projectID: String?
    var tags: [String]
    /// Tâches de rattachement.
    var taskIDs: [String]
    /// Réunion et journal : le moment concerné.
    var date: Date?
    /// Réunion : la réunion de Done d'où vient la note, tant qu'elle existe.
    var meetingID: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        kind: NoteKind = .note,
        title: String,
        body: String = "",
        projectID: String? = nil,
        tags: [String] = [],
        taskIDs: [String] = [],
        date: Date? = nil,
        meetingID: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.projectID = projectID
        self.tags = tags
        self.taskIDs = taskIDs
        self.date = date
        self.meetingID = meetingID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: Format du fichier

/// Un fichier de note : un en-tête entre deux lignes « --- » (une clé par ligne), puis le corps
/// en Markdown. La lecture est tolérante : sans en-tête, tout le fichier est le corps d'une note simple.
enum NoteFormat {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func serialize(_ note: Note) -> String {
        var lines = ["---", "id: \(note.id)", "type: \(note.kind.rawValue)", "title: \(oneLine(note.title))"]
        if let project = note.projectID { lines.append("project: \(project)") }
        if !note.tags.isEmpty { lines.append("tags: \(note.tags.map(oneLine).joined(separator: ", "))") }
        if !note.taskIDs.isEmpty { lines.append("tasks: \(note.taskIDs.joined(separator: ", "))") }
        if let date = note.date { lines.append("date: \(iso.string(from: date))") }
        if let meeting = note.meetingID { lines.append("meeting: \(meeting)") }
        lines.append("created: \(iso.string(from: note.createdAt))")
        lines.append("updated: \(iso.string(from: note.updatedAt))")
        lines.append("---")
        return lines.joined(separator: "\n") + "\n\n" + note.body.trimmingCharacters(in: .newlines) + "\n"
    }

    /// `fallbackTitle` (le nom du fichier) et `modified` servent quand l'en-tête manque.
    static func parse(_ text: String, fallbackID: String, fallbackTitle: String, modified: Date) -> Note {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        var fields: [String: String] = [:]
        var body = normalized
        if normalized.hasPrefix("---\n"), let end = normalized.range(of: "\n---", range: normalized.index(normalized.startIndex, offsetBy: 4)..<normalized.endIndex) {
            let header = normalized[normalized.index(normalized.startIndex, offsetBy: 4)..<end.lowerBound]
            for line in header.split(separator: "\n") {
                guard let colon = line.firstIndex(of: ":") else { continue }
                let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                fields[key] = value
            }
            body = String(normalized[end.upperBound...])
            if body.hasPrefix("\n") { body.removeFirst() }
        }
        func list(_ key: String) -> [String] {
            (fields[key] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        func date(_ key: String) -> Date? { fields[key].flatMap(iso.date(from:)) }
        let title = fields["title"].flatMap { $0.isEmpty ? nil : $0 } ?? fallbackTitle
        return Note(
            id: fields["id"].flatMap { $0.isEmpty ? nil : $0 } ?? fallbackID,
            kind: fields["type"].flatMap(NoteKind.init(rawValue:)) ?? .note,
            title: title,
            body: body.trimmingCharacters(in: .newlines),
            projectID: fields["project"].flatMap { $0.isEmpty ? nil : $0 },
            tags: list("tags"),
            taskIDs: list("tasks"),
            date: date("date"),
            meetingID: fields["meeting"].flatMap { $0.isEmpty ? nil : $0 },
            createdAt: date("created") ?? modified,
            updatedAt: date("updated") ?? modified
        )
    }

    /// Nom de fichier lisible tiré du titre, sans caractère gênant pour le Finder.
    static func fileStem(for title: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?*\"<>|").union(.newlines).union(.controlCharacters)
        let cleaned = title.components(separatedBy: forbidden).joined(separator: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let trimmed = String(cleaned.prefix(80)).trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        return trimmed.isEmpty ? "Sans titre" : trimmed
    }

    private static func oneLine(_ text: String) -> String {
        text.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
}

// MARK: Liens

/// Liens entre notes : [[Titre]] dans le corps. Titres comparés sans casse, accents ni espaces superflus.
enum NoteLinks {
    /// Les titres cités, dans l'ordre, sans doublon.
    static func titles(in body: String) -> [String] {
        var result: [String] = []
        var rest = body[...]
        while let open = rest.range(of: "[["), let close = rest.range(of: "]]", range: open.upperBound..<rest.endIndex) {
            let title = rest[open.upperBound..<close.lowerBound].trimmingCharacters(in: .whitespaces)
            if !title.isEmpty, !title.contains("\n"), !result.contains(where: { key($0) == key(title) }) {
                result.append(title)
            }
            rest = rest[close.upperBound...]
        }
        return result
    }

    static func key(_ title: String) -> String {
        RemindersInbox.matchKey(title)
    }

    static func resolve(_ title: String, in notes: [Note]) -> Note? {
        let wanted = key(title)
        return notes.first { key($0.title) == wanted }
    }

    /// Un titre libre parmi `notes` : « Titre », sinon « Titre 2 », « Titre 3 »…, pour que [[Titre]]
    /// désigne une seule note.
    static func uniqueTitle(_ title: String, among notes: [Note], excluding id: String? = nil) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "Sans titre" : trimmed
        let others = Set(notes.filter { $0.id != id }.map { key($0.title) })
        var candidate = base
        var counter = 2
        while others.contains(key(candidate)) {
            candidate = "\(base) \(counter)"
            counter += 1
        }
        return candidate
    }

    /// Les notes qui citent celle-ci par [[Titre]].
    static func backlinks(to note: Note, in notes: [Note]) -> [Note] {
        let wanted = key(note.title)
        return notes
            .filter { $0.id != note.id && titles(in: $0.body).contains { key($0) == wanted } }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
}

// MARK: Modèles

/// Le texte de départ des notes créées par Done : page de projet, note de réunion, note du jour.
enum NoteTemplates {
    static let projectPage = "## Objectif\n\n## Contexte\n\n## Liens utiles\n"

    static func meetingTitle(_ meeting: Meeting) -> String {
        "\(meeting.title), \(Format.dayAndMonth(meeting.start))"
    }

    static func meetingBody(_ meeting: Meeting) -> String {
        "\(Format.time(meeting.start))–\(Format.time(meeting.end))\n\n## Ordre du jour\n\n## Notes\n\n## Décisions\n\n## Actions\n\n- [ ] "
    }

    static func journalTitle(_ day: Date) -> String {
        "Journal du \(Format.fullDay(day))"
    }
}

// MARK: Markdown

/// Un bloc de Markdown, pour l'aperçu. Le texte garde sa mise en forme en ligne (gras, italique,
/// liens), que la vue interprète.
enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet(indent: Int, text: String)
    case numbered(number: Int, indent: Int, text: String)
    /// Case à cocher ; `line` est l'indice de sa ligne dans le corps, pour la cocher depuis l'aperçu.
    case task(checked: Bool, indent: Int, text: String, line: Int)
    case quote(String)
    case code(String)
    case rule
}

enum MarkdownBlocks {
    static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var quote: [String] = []
        var code: [String]?

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))) }
            if !quote.isEmpty { blocks.append(.quote(quote.joined(separator: "\n"))) }
            paragraph = []
            quote = []
        }

        for (index, raw) in lines.enumerated() {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if var open = code {
                if trimmed.hasPrefix("```") {
                    blocks.append(.code(open.joined(separator: "\n")))
                    code = nil
                } else {
                    open.append(raw)
                    code = open
                }
                continue
            }
            if trimmed.hasPrefix("```") {
                flush()
                code = []
                continue
            }
            if trimmed.isEmpty {
                flush()
                continue
            }
            let indent = (raw.prefix { $0 == " " || $0 == "\t" }.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }) / 2
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flush()
                blocks.append(.rule)
            } else if let level = headingLevel(trimmed) {
                flush()
                blocks.append(.heading(level: level, text: String(trimmed.dropFirst(level + 1)).trimmingCharacters(in: .whitespaces)))
            } else if trimmed.hasPrefix(">") {
                if !paragraph.isEmpty { flush() }
                quote.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
            } else if let item = listItem(trimmed) {
                flush()
                if let checked = item.checked {
                    blocks.append(.task(checked: checked, indent: indent, text: item.text, line: index))
                } else if let number = item.number {
                    blocks.append(.numbered(number: number, indent: indent, text: item.text))
                } else {
                    blocks.append(.bullet(indent: indent, text: item.text))
                }
            } else {
                if !quote.isEmpty { flush() }
                paragraph.append(trimmed)
            }
        }
        if let open = code { blocks.append(.code(open.joined(separator: "\n"))) }
        flush()
        return blocks
    }

    /// Coche ou décoche la case de la ligne `line` ; le reste du texte ne bouge pas.
    static func toggleTask(in text: String, line: Int) -> String {
        var lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(line) else { return text }
        let current = lines[line]
        for (from, to) in [("[ ]", "[x]"), ("[x]", "[ ]"), ("[X]", "[ ]")] {
            if let range = current.range(of: from) {
                lines[line] = current.replacingCharacters(in: range, with: to)
                return lines.joined(separator: "\n")
            }
        }
        return text
    }

    private static func headingLevel(_ line: String) -> Int? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...3).contains(hashes), line.dropFirst(hashes).first == " " else { return nil }
        return hashes
    }

    private static func listItem(_ line: String) -> (text: String, checked: Bool?, number: Int?)? {
        for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
            let rest = String(line.dropFirst(2))
            for (box, checked) in [("[ ] ", false), ("[x] ", true), ("[X] ", true)] where rest.hasPrefix(box) {
                return (String(rest.dropFirst(4)), checked, nil)
            }
            if rest == "[ ]" { return ("", false, nil) }
            if rest == "[x]" || rest == "[X]" { return ("", true, nil) }
            return (rest, nil, nil)
        }
        let digits = line.prefix { $0.isNumber }
        if !digits.isEmpty, let number = Int(digits), line.dropFirst(digits.count).hasPrefix(". ") {
            return (String(line.dropFirst(digits.count + 2)), nil, number)
        }
        return nil
    }
}
