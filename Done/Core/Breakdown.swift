import Foundation

/// Modèles proposés dans les Réglages. Claude Opus 5.5 par défaut.
enum ClaudeModel: String, CaseIterable, Identifiable {
    case opus = "claude-opus-5-5"
    case sonnet = "claude-sonnet-5-5"
    case haiku = "claude-haiku-5-5"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .opus: "Opus 5.5"
        case .sonnet: "Sonnet 5.5"
        case .haiku: "Haiku 5.5"
        }
    }

    /// Repli automatique sur un autre modèle si les filtres de sécurité refusent la demande.
    /// Haiku 5.5 n'en a pas.
    var supportsFallbacks: Bool { self != .haiku }
}

/// Découpage assisté par Claude : consignes, contexte de la tâche et lecture de la réponse, sans réseau.
enum Breakdown {
    /// Découpage proposé par Claude : l'approche en une phrase, puis les étapes dans l'ordre.
    struct Plan: Equatable {
        let approach: String
        let steps: [String]
    }

    /// Fichier du dossier de contexte, tel que Claude le voit dans la liste.
    struct ContextEntry: Equatable {
        /// Chemin relatif au dossier, celui que Claude renvoie pour lire le fichier.
        let path: String
        /// Taille du fichier, en Ko.
        let kilobytes: Int
        /// Première ligne des fichiers texte, pour aider Claude à choisir.
        let firstLine: String?
    }

    /// Fichier joint à la tâche, envoyé en entier avec la demande.
    struct Attachment: Equatable {
        enum Content: Equatable {
            case text(String)
            case pdf(Data)
            case image(Data, mediaType: String)
        }

        let name: String
        let content: Content
    }

    /// Méthode par défaut, modifiable dans les Réglages.
    static let defaultMethod = """
    Une action commence par un verbe à l'infinitif et nomme un résultat visible : « Lister les 9 fiches à modifier », pas « Fiches ».
    Elle tient en une session de focus d'environ 25 minutes et peut démarrer tout de suite, sans attendre quelqu'un.
    """

    // Limites de lecture : un découpage doit rester à quelques centimes.
    static let maxFilesPerRead = 5
    static let maxCharactersPerFile = 30_000
    static let maxIndexEntries = 300
    /// Nombre maximal d'allers-retours avec Claude pour un découpage.
    static let maxRounds = 5
    /// Au-delà, les étapes restantes sont ignorées : une tâche qui en demande plus est un projet.
    static let maxSteps = 10
    // Pièces jointes : choisies par la personne, donc plus généreuses que le dossier de contexte.
    static let maxAttachments = 5
    static let maxAttachmentCharacters = 60_000
    static let maxPDFBytes = 15 * 1_024 * 1_024

    // MARK: Consignes

    /// Partie stable de la demande : méthode, exemples et liste des fichiers.
    static func systemPrompt(method: String, examples: [String], files: [ContextEntry]) -> String {
        var parts = [
            """
            Tu aides une personne à finir une tâche Todoist trop large en la découpant en étapes. Done, son app de sessions de focus, créera toutes les étapes comme sous-tâches dans Todoist, dans ton ordre, puis les lui proposera une par une jusqu'à ce que la tâche soit finie.

            Découpe la tâche entière, de la première action jusqu'à la dernière qui la clôt : pas seulement le premier pas. Les étapes se suivent dans l'ordre où la personne les fera, et chacune prépare la suivante. Vise 3 à 8 étapes ; si la tâche en demande plus, regroupe les petites.

            Une bonne étape :
            - commence par un verbe à l'infinitif et nomme un résultat visible ;
            - tient en une session de focus d'environ 25 minutes ;
            - peut se faire sans attendre quelqu'un : quand il faut l'avis d'une autre personne, l'étape est l'envoi de la demande (« Envoyer la page à Camille pour relecture ») ;
            - tient sur une ligne et reprend le vocabulaire de la personne.

            Ne répète pas les sous-tâches déjà présentes dans Todoist. Donne aussi une phrase qui résume l'approche. Écris en français, sans point d'exclamation.
            """,
        ]
        let trimmedMethod = method.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMethod.isEmpty {
            parts.append("Sa méthode pour découper :\n<methode>\n\(trimmedMethod)\n</methode>")
        }
        if !examples.isEmpty {
            let lines = examples.map { "- \($0)" }.joined(separator: "\n")
            parts.append("Sous-tâches qu'elle a déjà écrites dans Todoist, pour le ton et le niveau de détail :\n<exemples>\n\(lines)\n</exemples>")
        }
        if !files.isEmpty {
            parts.append("""
            Son dossier de contexte (plan marketing, priorités, lexique, documents de travail) contient les fichiers ci-dessous. Lis avec l'outil read_context_files ceux qui peuvent préciser ce que la tâche demande ou les mots à employer, \(maxFilesPerRead) au plus par appel. Ne lis rien si la tâche est claire sans eux.
            <fichiers>
            \(indexListing(files))
            </fichiers>
            """)
        }
        return parts.joined(separator: "\n\n")
    }

    /// Partie propre à la tâche : titre, projet, parent, sous-tâches et note de reprise.
    static func taskPrompt(
        task: TodoistTask,
        projectName: String,
        parent: TodoistTask?,
        siblings: [TodoistTask],
        existing: [TodoistTask] = [],
        resumeNote: String?,
        now: Date = .now
    ) -> String {
        var lines = ["Tâche à découper : « \(task.content) »"]
        if !projectName.isEmpty { lines.append("Projet : \(projectName)") }
        let description = task.description.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty { lines.append("Description : \(description)") }
        if let parent { lines.append("Tâche parente : « \(parent.content) »") }
        if !siblings.isEmpty {
            lines.append("Autres sous-tâches encore ouvertes au même niveau : " + siblings.map { "« \($0.content) »" }.joined(separator: ", "))
        }
        if !existing.isEmpty {
            lines.append("Sous-tâches déjà présentes sous cette tâche, à ne pas répéter : " + existing.map { "« \($0.content) »" }.joined(separator: ", "))
        }
        if !task.labels.isEmpty { lines.append("Labels : " + task.labels.map { "@\($0)" }.joined(separator: ", ")) }
        if let due = Format.due(task, now: now) { lines.append("Date : \(due)") }
        if let resumeNote, !resumeNote.isEmpty { lines.append("Note laissée à la dernière session : « \(resumeNote) »") }
        return lines.joined(separator: "\n")
    }

    /// Contenu du message envoyé à Claude : les pièces jointes d'abord, puis la tâche.
    static func userContent(prompt: String, attachments: [Attachment]) -> [[String: Any]] {
        var blocks: [[String: Any]] = []
        for attachment in attachments {
            switch attachment.content {
            case .text(let text):
                let clipped = text.count > maxAttachmentCharacters
                    ? String(text.prefix(maxAttachmentCharacters)) + "\n[… coupé à \(maxAttachmentCharacters) caractères]"
                    : text
                blocks.append(["type": "text", "text": "<piece_jointe nom=\"\(attachment.name)\">\n\(clipped)\n</piece_jointe>"])
            case .pdf(let data):
                blocks.append(["type": "text", "text": "Pièce jointe : \(attachment.name)"])
                blocks.append(["type": "document", "source": ["type": "base64", "media_type": "application/pdf", "data": data.base64EncodedString()]])
            case .image(let data, let mediaType):
                blocks.append(["type": "text", "text": "Pièce jointe : \(attachment.name)"])
                blocks.append(["type": "image", "source": ["type": "base64", "media_type": mediaType, "data": data.base64EncodedString()]])
            }
        }
        var text = prompt
        if !attachments.isEmpty {
            let names = attachments.map { "« \($0.name) »" }.joined(separator: ", ")
            text += "\n\nPièces jointes ci-dessus, choisies pour cette tâche : \(names). Appuie-toi dessus en priorité."
        }
        blocks.append(["type": "text", "text": text])
        return blocks
    }

    /// Liste des fichiers, une ligne par fichier, plafonnée.
    static func indexListing(_ files: [ContextEntry]) -> String {
        var lines = files.prefix(maxIndexEntries).map { entry -> String in
            var line = "- \(entry.path) (\(max(1, entry.kilobytes)) Ko)"
            if let first = entry.firstLine, !first.isEmpty { line += " : \(first)" }
            return line
        }
        if files.count > maxIndexEntries {
            lines.append("- … et \(files.count - maxIndexEntries) autres fichiers non listés")
        }
        return lines.joined(separator: "\n")
    }

    /// Sous-tâches existantes qui servent d'exemples d'écriture, de préférence du même projet.
    static func examples(in index: TaskIndex, preferring projectID: String, excluding taskID: String, rules: Rules, limit: Int = 12) -> [String] {
        let candidates = index.all.filter { task in
            task.parentId != nil
                && task.id != taskID
                && task.parentId != taskID
                && !Planner.isMeeting(task, rules: rules)
                && !task.content.hasPrefix("Préparer")
                && (8...100).contains(task.content.count)
        }
        let sorted = candidates.sorted { a, b in
            let sameA = a.projectId == projectID
            let sameB = b.projectId == projectID
            if sameA != sameB { return sameA }
            return (a.addedAt ?? .distantPast) > (b.addedAt ?? .distantPast)
        }
        var seen = Set<String>()
        return sorted.map(\.content).filter { seen.insert($0).inserted }.prefix(limit).map { $0 }
    }

    // MARK: Réponse

    /// Lit la réponse JSON de Claude. `nil` si elle ne suit pas le format attendu ou ne contient aucune étape.
    static func parse(_ text: String) -> Plan? {
        struct Step: Decodable { let title: String }
        struct Payload: Decodable {
            let approach: String
            let steps: [Step]
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: Data(text.utf8)) else { return nil }
        var seen = Set<String>()
        let steps = payload.steps
            .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        guard !steps.isEmpty else { return nil }
        return Plan(approach: payload.approach.trimmingCharacters(in: .whitespacesAndNewlines), steps: Array(steps.prefix(maxSteps)))
    }

    /// Chemins demandés par Claude qui existent vraiment dans le dossier, sans doublon ni dépassement.
    static func allowedPaths(_ requested: [String], available: Set<String>) -> [String] {
        var seen = Set<String>()
        return requested
            .filter { available.contains($0) && seen.insert($0).inserted }
            .prefix(maxFilesPerRead)
            .map { $0 }
    }

    /// Texte d'un fichier renvoyé à Claude, coupé au-delà de la limite.
    static func fileExcerpt(path: String, text: String) -> String {
        let clipped = text.count > maxCharactersPerFile
            ? String(text.prefix(maxCharactersPerFile)) + "\n[… fichier coupé à \(maxCharactersPerFile) caractères]"
            : text
        return "<fichier chemin=\"\(path)\">\n\(clipped)\n</fichier>"
    }

    // MARK: Formats de l'API

    /// Format imposé à la réponse finale : l'approche, puis toutes les étapes dans l'ordre.
    static var outputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "approach": ["type": "string", "description": "Une phrase : comment ces étapes mènent la tâche au bout."],
                "steps": [
                    "type": "array",
                    "description": "Toutes les étapes, de la première à celle qui clôt la tâche, dans l'ordre.",
                    "items": [
                        "type": "object",
                        "properties": [
                            "title": ["type": "string", "description": "L'étape, prête à devenir une sous-tâche Todoist."],
                        ],
                        "required": ["title"],
                        "additionalProperties": false,
                    ],
                ],
            ],
            "required": ["approach", "steps"],
            "additionalProperties": false,
        ]
    }

    /// Outil qui laisse Claude lire les fichiers utiles du dossier de contexte.
    static var readFilesTool: [String: Any] {
        [
            "name": "read_context_files",
            "description": "Renvoie le texte de fichiers du dossier de contexte de la personne. Appelle-le quand un fichier de la liste peut préciser ce que la tâche demande, ses priorités ou son vocabulaire. Donne les chemins exactement comme dans la liste, \(maxFilesPerRead) au plus.",
            "strict": true,
            "input_schema": [
                "type": "object",
                "properties": [
                    "paths": [
                        "type": "array",
                        "items": ["type": "string"],
                        "description": "Chemins relatifs, tels qu'ils apparaissent dans la liste des fichiers.",
                    ],
                ],
                "required": ["paths"],
                "additionalProperties": false,
            ],
        ]
    }
}
