import Foundation

// MARK: Plan du jour partagé

/// Le plan du jour publié par Done dans `plan.json` à chaque changement, pour le connecteur Claude :
/// le plan lui-même vit dans la base locale de l'app, que seul Done ouvre.
struct PlanSnapshot: Codable, Equatable {
    /// Clé de jour (« 2026-11-06 »).
    var day: String
    var taskIDs: [String]
    var doneIDs: [String]
}

/// Le plan du jour voulu par Claude, déposé dans `plan-request.json`. Done l'applique dès qu'il le
/// voit, puis efface le fichier.
struct PlanRequest: Codable, Equatable {
    var day: String
    var taskIDs: [String]
    var requestedAt: Date
}

enum SharedPlan {
    struct Current: Equatable {
        var taskIDs: [String]
        var doneIDs: [String]
        /// Vrai tant que Done n'a pas appliqué la demande de Claude.
        var pending: Bool
    }

    /// Le plan du jour tel que Claude doit le voir : sa demande en attente, sinon le plan publié par
    /// Done. Un plan d'un autre jour ne compte pas.
    static func current(snapshot: PlanSnapshot?, request: PlanRequest?, day: String) -> Current {
        let published = snapshot?.day == day ? snapshot : nil
        if let request, request.day == day {
            return Current(taskIDs: request.taskIDs, doneIDs: published?.doneIDs ?? [], pending: true)
        }
        return Current(taskIDs: published?.taskIDs ?? [], doneIDs: published?.doneIDs ?? [], pending: false)
    }

    /// Ce que Done retient d'une demande : les tâches encore ouvertes, sans doublon, dans la limite
    /// du plan. `nil` si la demande date d'un autre jour ou ne garde aucune tâche.
    static func accepted(_ request: PlanRequest, openIDs: Set<String>, today: String) -> [String]? {
        guard request.day == today else { return nil }
        var ids: [String] = []
        for id in request.taskIDs where openIDs.contains(id) && !ids.contains(id) {
            ids.append(id)
        }
        return ids.isEmpty ? nil : Array(ids.prefix(Rules.maxPlanSize))
    }
}

// MARK: Accès aux données

/// Ce que lit et écrit le connecteur. `ConnectorFiles` (Services) le branche sur les fichiers de
/// Done ; les tests passent par une version en mémoire.
protocol ConnectorWorkspace {
    func loadTasks() throws -> TaskStore
    /// Relit les tâches, applique le changement et les réécrit, sans qu'une autre écriture ne
    /// s'intercale. Si `change` lève une erreur, rien n'est écrit.
    func updateTasks<T>(_ change: (inout TaskStore) throws -> T) throws -> T
    func loadNotes() -> [Note]
    /// Écrit une note, nouvelle ou modifiée ; son fichier suit son titre.
    func writeNote(_ note: Note) throws
    func planSnapshot() -> PlanSnapshot?
    func planRequest() -> PlanRequest?
    func requestPlan(_ request: PlanRequest) throws
    /// Note de reprise laissée dans Done, en lecture seule.
    func resumeNote(for taskID: String) -> String?
}

// MARK: Arguments

/// Les arguments d'un appel, lus avec indulgence : `null` vaut absent, un nombre peut arriver en texte,
/// une liste peut arriver en texte séparé par des virgules.
struct ToolArguments {
    let values: [String: JSONValue]

    init(_ values: [String: JSONValue]) {
        self.values = values
    }

    /// Présent et non nul.
    func has(_ key: String) -> Bool {
        values[key].map { !$0.isNull } ?? false
    }

    func string(_ key: String) throws -> String? {
        guard let value = values[key], !value.isNull else { return nil }
        switch value {
        case .string(let text): return text
        case .int(let number): return String(number)
        default: throw ToolFailure("« \(key) » doit être un texte.")
        }
    }

    /// Un texte non vide, sans espaces autour.
    func required(_ key: String) throws -> String {
        guard let text = try string(key)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw ToolFailure("« \(key) » est obligatoire.")
        }
        return text
    }

    func int(_ key: String) throws -> Int? {
        guard let value = values[key], !value.isNull else { return nil }
        guard let number = value.int else { throw ToolFailure("« \(key) » doit être un nombre entier.") }
        return number
    }

    func bool(_ key: String) throws -> Bool? {
        guard let value = values[key], !value.isNull else { return nil }
        guard let flag = value.bool else { throw ToolFailure("« \(key) » doit valoir true ou false.") }
        return flag
    }

    func strings(_ key: String) throws -> [String]? {
        guard let value = values[key], !value.isNull else { return nil }
        switch value {
        case .array(let items):
            return try items.map { item in
                guard let text = item.string else { throw ToolFailure("« \(key) » doit être une liste de textes.") }
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        case .string(let text):
            return text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        default:
            throw ToolFailure("« \(key) » doit être une liste de textes.")
        }
    }
}

// MARK: Dates et désignations

enum ConnectorFormat {
    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }

    private static let stampFormatter = formatter("yyyy-MM-dd'T'HH:mm")
    /// Les formats longs d'abord : un format court pourrait lire le début d'une heure plus précise.
    private static let localParsers = ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"].map(formatter)

    /// Heure locale lisible et relisible : « 2026-11-06T14:30 ».
    static func stamp(_ date: Date) -> String {
        stampFormatter.string(from: date)
    }

    /// Un jour : « AAAA-MM-JJ », « today » / « aujourd'hui » ou « tomorrow » / « demain ».
    static func day(_ text: String, field: String, now: Date, calendar: Calendar = .current) throws -> Date {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let today = calendar.startOfDay(for: now)
        switch trimmed.lowercased().replacingOccurrences(of: "’", with: "'") {
        case "today", "aujourd'hui": return today
        case "tomorrow", "demain": return calendar.date(byAdding: .day, value: 1, to: today) ?? today
        default: break
        }
        let key = trimmed.count > 10 && trimmed.dropFirst(10).first == "T" ? String(trimmed.prefix(10)) : trimmed
        guard key.count == 10, let date = Format.date(fromDayKey: key) else {
            throw ToolFailure("« \(field) » : date attendue au format AAAA-MM-JJ, reçu « \(text) ».")
        }
        return date
    }

    /// Une heure : locale (« 2026-11-06T14:30 ») ou ISO 8601 avec fuseau.
    static func moment(_ text: String, field: String) throws -> Date {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Avec un fuseau (« Z », « +01:00 »), l'heure est absolue : elle passe avant les formats locaux.
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: trimmed) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: trimmed) { return date }
        for parser in localParsers {
            if let date = parser.date(from: trimmed) { return date }
        }
        throw ToolFailure("« \(field) » : heure attendue au format AAAA-MM-JJTHH:MM (heure locale), reçu « \(text) ».")
    }

    /// Un jour seul (« 2026-11-06 ») ou une heure (« 2026-11-06T14:30 »).
    static func dayOrMoment(_ text: String, field: String, now: Date) throws -> Date {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count == 10 || !trimmed.contains(where: \.isNumber) {
            return try day(trimmed, field: field, now: now)
        }
        return try moment(trimmed, field: field)
    }

    /// Le texte sur une ligne, coupé à `length` caractères.
    static func excerpt(_ text: String, _ length: Int) -> String {
        let flat = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return flat.count > length ? String(flat.prefix(length)) + "…" : flat
    }

    /// « Inbox » (ou « boîte de réception ») désigne l'Inbox, pas un projet.
    static func isInbox(_ reference: String) -> Bool {
        ["inbox", "boite de reception"].contains(RemindersInbox.matchKey(reference))
    }

    /// Un projet désigné par son identifiant, son nom ou son chemin « Projet › Sous-projet »
    /// (« > » ou « / » acceptés), sans tenir compte de la casse ni des accents.
    static func project(_ reference: String, in store: TaskStore) throws -> Project {
        let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = store.project(trimmed) { return exact }
        let parts = trimmed.components(separatedBy: CharacterSet(charactersIn: "›>/"))
            .map { RemindersInbox.matchKey($0) }
            .filter { !$0.isEmpty }
        func path(_ project: Project) -> [String] {
            let own = RemindersInbox.matchKey(project.name)
            guard let parent = store.project(project.parentID) else { return [own] }
            return [RemindersInbox.matchKey(parent.name), own]
        }
        let byPath = store.projects.filter { path($0) == parts }
        if byPath.count == 1 { return byPath[0] }
        if parts.count == 1 {
            let byName = store.projects.filter { RemindersInbox.matchKey($0.name) == parts[0] }
            if byName.count == 1 { return byName[0] }
            if byName.count > 1 {
                let choices = byName.map { "« \(store.projectPath($0.id) ?? $0.name) » (\($0.id))" }.joined(separator: ", ")
                throw ToolFailure("Plusieurs projets s'appellent « \(trimmed) » : \(choices). Précise l'identifiant ou le chemin.")
            }
        }
        throw ToolFailure("Projet introuvable : « \(trimmed) ». La liste des projets est dans list_projects ; create_project en crée un.")
    }

    /// Une étiquette existante, quelle que soit la casse.
    static func tag(_ name: String, in store: TaskStore) throws -> String {
        let wanted = RemindersInbox.matchKey(name)
        var seen = Set<String>()
        let all = store.tasks.flatMap(\.tags).filter { seen.insert($0).inserted }
        if let found = all.first(where: { RemindersInbox.matchKey($0) == wanted }) { return found }
        throw ToolFailure("Étiquette introuvable : « \(name) ». Étiquettes en usage : \(store.tags.joined(separator: ", ")).")
    }

    static func priority(_ value: JSONValue?) throws -> Int? {
        guard let value, !value.isNull else { return nil }
        var number = value.int
        if number == nil, let text = value.string?.trimmingCharacters(in: .whitespaces).uppercased(), text.hasPrefix("P") {
            number = Int(text.dropFirst())
        }
        guard let number, (1...4).contains(number) else {
            throw ToolFailure("« priority » va de 1 (P1, la plus urgente) à 4 (P4).")
        }
        return number
    }

    static func kind(_ text: String?) throws -> TaskKind? {
        guard let text else { return nil }
        switch RemindersInbox.matchKey(text) {
        case "normal", "normale": return .normal
        case "quick", "rapide": return .quick
        case "deepwork", "deep work", "deep": return .deepwork
        default: throw ToolFailure("« kind » vaut normal, quick ou deepwork.")
        }
    }

    static func noteKind(_ text: String?) throws -> NoteKind? {
        guard let text else { return nil }
        let key = RemindersInbox.matchKey(text)
        if let kind = NoteKind(rawValue: key) { return kind }
        if let kind = NoteKind.allCases.first(where: { RemindersInbox.matchKey($0.label) == key }) { return kind }
        let names = NoteKind.allCases.map(\.rawValue).joined(separator: ", ")
        throw ToolFailure("Type de note inconnu : « \(text) ». Types : \(names).")
    }
}
