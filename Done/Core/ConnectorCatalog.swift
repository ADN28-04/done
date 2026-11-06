import Foundation

/// La liste des outils telle que Claude la voit : noms, descriptions et schémas des arguments.
extension ConnectorTools {
    static let instructions = """
    Done est l'app de tâches et de minuteur Pomodoro de l'utilisateur, sur ce Mac. Ce connecteur lit et \
    modifie ses tâches, projets, étiquettes, notes, réunions, jours d'absence et son plan du jour. Il ne \
    supprime jamais rien : pour retirer quelque chose, propose à l'utilisateur de le faire dans Done.

    Repères :
    - Commence par get_overview : date du jour, plan du jour, échéances, réunions.
    - Priorité de 1 (P1, la plus urgente) à 4 (P4). Type de travail : normal, quick (rapide) ou deepwork.
    - Une tâche sans projet ni étiquette est dans l'Inbox. Les sous-tâches s'appellent des étapes : une \
    étape suit le projet de sa tâche et ne porte pas d'étiquette.
    - Projets sur deux niveaux au plus (projet, sous-projet). Un projet se désigne par son identifiant, son \
    nom ou « Projet › Sous-projet ».
    - Dates au format AAAA-MM-JJ, heures locales au format AAAA-MM-JJTHH:MM.
    - Notes en Markdown ; [[Titre]] relie une note à une autre. Pour compléter une note, préfère append \
    (update_note) à la réécriture du contenu.
    - Le plan du jour tient en \(Rules.maxPlanSize) tâches au plus.
    - Avant de créer une tâche ou une note, vérifie qu'elle n'existe pas déjà (list_tasks, list_notes).
    - Écris en français, court et direct, sans point d'exclamation.
    """

    static let catalog: [MCPTool] = [
        MCPTool(
            name: "get_overview",
            title: "Point de la journée",
            description: "Point de la journée : date et heure, absence, plan du jour, tâches dues aujourd'hui ou en retard, réunions du jour, tâches cochées aujourd'hui, nombre de tâches ouvertes et dans l'Inbox, note du jour. À appeler en premier.",
            schema: ToolSchema.object([:]),
            readOnly: true
        ),
        MCPTool(
            name: "list_tasks",
            title: "Chercher des tâches",
            description: "Cherche des tâches principales, avec leurs étapes ouvertes et un extrait de leurs notes. Filtres combinables : projet (sous-projets compris), étiquette, Inbox, texte, échéance, état. Sans filtre : toutes les tâches ouvertes, par priorité puis échéance.",
            schema: ToolSchema.object([
                "project": ToolSchema.text("Identifiant, nom ou chemin « Projet › Sous-projet ». « inbox » pour l'Inbox."),
                "tag": ToolSchema.text("Nom d'étiquette."),
                "inbox": ToolSchema.flag("Seulement l'Inbox (ni projet ni étiquette)."),
                "query": ToolSchema.text("Mots à trouver dans le titre, les notes, les étapes, le projet ou les étiquettes (tous les mots, sans tenir compte des accents)."),
                "due_before": ToolSchema.text("Échéance au plus tard ce jour (AAAA-MM-JJ)."),
                "status": ToolSchema.choice(["open", "done", "all"], "open (par défaut), done ou all."),
                "done_since": ToolSchema.text("Cochées depuis ce jour (AAAA-MM-JJ), avec status done ou all."),
                "limit": ToolSchema.integer("Nombre maximum de tâches (100 par défaut).", min: 1, max: 500),
            ]),
            readOnly: true
        ),
        MCPTool(
            name: "get_task",
            title: "Lire une tâche",
            description: "Tout sur une tâche : notes, étapes (cochées comprises), tâche parente, notes rattachées, note de reprise laissée dans Done.",
            schema: ToolSchema.object(["id": ToolSchema.text("Identifiant de la tâche.")], required: ["id"]),
            readOnly: true
        ),
        MCPTool(
            name: "list_projects",
            title: "Projets et étiquettes",
            description: "Projets et sous-projets avec leurs identifiants, le nombre de tâches ouvertes (un projet compte celles de ses sous-projets) et leur page de documentation ; étiquettes en usage ; nombre de tâches dans l'Inbox.",
            schema: ToolSchema.object([:]),
            readOnly: true
        ),
        MCPTool(
            name: "get_calendar",
            title: "Calendrier",
            description: "Jours à venir, jour par jour : réunions, absences et échéances (les retards comptent pour aujourd'hui). Done oublie les réunions des semaines passées.",
            schema: ToolSchema.object([
                "start": ToolSchema.text("Premier jour (AAAA-MM-JJ), aujourd'hui par défaut."),
                "days": ToolSchema.integer("Nombre de jours (7 par défaut).", min: 1, max: 31),
            ]),
            readOnly: true
        ),
        MCPTool(
            name: "list_notes",
            title: "Chercher des notes",
            description: "Cherche des notes, les plus récemment modifiées d'abord : titre, type, rattachements, extrait. Types : note, meeting, decision, person, reference, project (page de documentation d'un projet), journal (note du jour).",
            schema: ToolSchema.object([
                "kind": ToolSchema.choice(NoteKind.allCases.map(\.rawValue), "Type de note."),
                "project": ToolSchema.text("Projet de rattachement (sous-projets compris) : identifiant, nom ou chemin."),
                "tag": ToolSchema.text("Étiquette de note."),
                "task_id": ToolSchema.text("Notes rattachées à cette tâche."),
                "query": ToolSchema.text("Mots à trouver dans le titre, le contenu ou les étiquettes."),
                "limit": ToolSchema.integer("Nombre maximum de notes (50 par défaut).", min: 1, max: 300),
            ]),
            readOnly: true
        ),
        MCPTool(
            name: "read_note",
            title: "Lire une note",
            description: "Lit une note en entier : contenu Markdown, rattachements, liens [[Titre]] sortants et notes qui la citent.",
            schema: ToolSchema.object(["note": ToolSchema.text("Identifiant ou titre exact de la note.")], required: ["note"]),
            readOnly: true
        ),
        MCPTool(
            name: "create_task",
            title: "Créer une tâche",
            description: "Crée une tâche avec tous ses détails et, si besoin, ses étapes. Avec parent_id, crée une étape d'une tâche existante : elle suit son projet et ne porte pas d'étiquette.",
            schema: ToolSchema.object([
                "title": ToolSchema.text("Titre, court et actionnable."),
                "notes": ToolSchema.text("Notes de la tâche."),
                "project": ToolSchema.text("Projet : identifiant, nom ou chemin « Projet › Sous-projet ». Sans projet ni étiquette, la tâche va dans l'Inbox."),
                "parent_id": ToolSchema.text("Tâche parente, pour créer une étape."),
                "priority": ToolSchema.integer("1 (P1, la plus urgente) à 4 (P4, par défaut).", min: 1, max: 4),
                "kind": ToolSchema.choice(["normal", "quick", "deepwork"], "Type de travail, normal par défaut."),
                "due": ToolSchema.text("Échéance (AAAA-MM-JJ)."),
                "tags": ToolSchema.texts("Étiquettes (tâche principale seulement)."),
                "steps": ToolSchema.texts("Étapes à créer sous la tâche, dans l'ordre."),
            ], required: ["title"]),
            readOnly: false
        ),
        MCPTool(
            name: "update_task",
            title: "Modifier une tâche",
            description: "Modifie une tâche : seuls les champs donnés changent. Changer le projet d'une tâche emmène ses étapes.",
            schema: ToolSchema.object([
                "id": ToolSchema.text("Identifiant de la tâche."),
                "title": ToolSchema.text("Nouveau titre."),
                "notes": ToolSchema.text("Remplace les notes."),
                "append_notes": ToolSchema.text("Ajoute ce texte à la fin des notes."),
                "project": ToolSchema.text("Projet (identifiant, nom ou chemin), ou « inbox » pour retirer le projet."),
                "priority": ToolSchema.integer("1 (P1) à 4 (P4).", min: 1, max: 4),
                "kind": ToolSchema.choice(["normal", "quick", "deepwork"], "Type de travail."),
                "due": ToolSchema.text("Échéance (AAAA-MM-JJ), chaîne vide pour la retirer."),
                "tags": ToolSchema.texts("Remplace les étiquettes (liste vide pour les retirer)."),
                "blocked": ToolSchema.flag("Bloquée : Done ne la propose plus tant qu'elle n'est pas débloquée."),
            ], required: ["id"]),
            readOnly: false
        ),
        MCPTool(
            name: "complete_task",
            title: "Cocher une tâche",
            description: "Coche une tâche et ses étapes encore ouvertes. Done la sort du plan du jour.",
            schema: ToolSchema.object(["id": ToolSchema.text("Identifiant de la tâche.")], required: ["id"]),
            readOnly: false
        ),
        MCPTool(
            name: "reopen_task",
            title: "Rouvrir une tâche",
            description: "Rouvre une tâche cochée, et ses parentes si elles l'étaient aussi.",
            schema: ToolSchema.object(["id": ToolSchema.text("Identifiant de la tâche.")], required: ["id"]),
            readOnly: false
        ),
        MCPTool(
            name: "set_today_plan",
            title: "Fixer le plan du jour",
            description: "Fixe le plan du jour : \(Rules.maxPlanSize) tâches ouvertes au plus, dans l'ordre où les faire. mode replace remplace le plan, append ajoute à la fin. Done applique le plan dès qu'il est ouvert.",
            schema: ToolSchema.object([
                "task_ids": ToolSchema.texts("Identifiants des tâches, dans l'ordre."),
                "mode": ToolSchema.choice(["replace", "append"], "replace (par défaut) ou append."),
            ], required: ["task_ids"]),
            readOnly: false
        ),
        MCPTool(
            name: "create_project",
            title: "Créer un projet",
            description: "Crée un projet, ou un sous-projet avec parent. Un sous-projet ne contient pas d'autre projet.",
            schema: ToolSchema.object([
                "name": ToolSchema.text("Nom du projet."),
                "parent": ToolSchema.text("Projet parent (identifiant ou nom), pour créer un sous-projet."),
            ], required: ["name"]),
            readOnly: false
        ),
        MCPTool(
            name: "update_project",
            title: "Modifier un projet",
            description: "Renomme un projet ou le range : parent en fait un sous-projet, une chaîne vide le remonte au premier niveau.",
            schema: ToolSchema.object([
                "project": ToolSchema.text("Projet à modifier : identifiant, nom ou chemin."),
                "name": ToolSchema.text("Nouveau nom."),
                "parent": ToolSchema.text("Nouveau projet parent, ou chaîne vide pour le premier niveau."),
            ], required: ["project"]),
            readOnly: false
        ),
        MCPTool(
            name: "rename_tag",
            title: "Renommer une étiquette",
            description: "Renomme une étiquette sur toutes les tâches. Si le nouveau nom existe déjà, les deux étiquettes se fondent.",
            schema: ToolSchema.object([
                "from": ToolSchema.text("Nom actuel."),
                "to": ToolSchema.text("Nouveau nom."),
            ], required: ["from", "to"]),
            readOnly: false
        ),
        MCPTool(
            name: "create_note",
            title: "Créer une note",
            description: "Crée une note Markdown ([[Titre]] relie à une autre note). Une page de projet (kind project) par projet, une note du jour (kind journal) par jour. Avec meeting_id, crée la note d'une réunion de Done : titre, date et plan de note sont préremplis. Le titre est rendu unique.",
            schema: ToolSchema.object([
                "kind": ToolSchema.choice(NoteKind.allCases.map(\.rawValue), "Type : note (par défaut), meeting, decision, person, reference, project, journal."),
                "title": ToolSchema.text("Titre. Facultatif pour une page de projet, une note du jour ou une note de réunion."),
                "body": ToolSchema.text("Contenu en Markdown."),
                "project": ToolSchema.text("Projet de rattachement (obligatoire pour une page de projet)."),
                "tags": ToolSchema.texts("Étiquettes de la note."),
                "task_ids": ToolSchema.texts("Tâches rattachées."),
                "date": ToolSchema.text("Jour (AAAA-MM-JJ) ou moment (AAAA-MM-JJTHH:MM) : réunion, note du jour."),
                "meeting_id": ToolSchema.text("Réunion de Done dont c'est la note."),
            ]),
            readOnly: false
        ),
        MCPTool(
            name: "update_note",
            title: "Modifier une note",
            description: "Modifie une note : seuls les champs donnés changent. append ajoute du texte à la fin (à préférer pour compléter), body remplace tout le contenu.",
            schema: ToolSchema.object([
                "note": ToolSchema.text("Identifiant ou titre exact de la note."),
                "title": ToolSchema.text("Nouveau titre."),
                "body": ToolSchema.text("Remplace tout le contenu."),
                "append": ToolSchema.text("Ajoute ce Markdown à la fin."),
                "kind": ToolSchema.choice(NoteKind.creatable.map(\.rawValue), "Nouveau type."),
                "project": ToolSchema.text("Projet de rattachement, ou chaîne vide pour le retirer."),
                "tags": ToolSchema.texts("Remplace les étiquettes."),
                "task_ids": ToolSchema.texts("Remplace les tâches rattachées."),
                "date": ToolSchema.text("Jour ou moment, chaîne vide pour le retirer."),
            ], required: ["note"]),
            readOnly: false
        ),
        MCPTool(
            name: "add_meeting",
            title: "Ajouter une réunion",
            description: "Ajoute une réunion au calendrier de Done, qui en tient compte pour proposer des sessions. Heures locales AAAA-MM-JJTHH:MM ; donner end ou duration_minutes.",
            schema: ToolSchema.object([
                "title": ToolSchema.text("Titre de la réunion."),
                "start": ToolSchema.text("Début (AAAA-MM-JJTHH:MM)."),
                "end": ToolSchema.text("Fin (AAAA-MM-JJTHH:MM)."),
                "duration_minutes": ToolSchema.integer("Durée en minutes, à la place de end.", min: 5, max: 720),
            ], required: ["title", "start"]),
            readOnly: false
        ),
        MCPTool(
            name: "update_meeting",
            title: "Modifier une réunion",
            description: "Modifie le titre ou les horaires d'une réunion. Un nouveau début sans nouvelle fin garde la durée.",
            schema: ToolSchema.object([
                "id": ToolSchema.text("Identifiant de la réunion."),
                "title": ToolSchema.text("Nouveau titre."),
                "start": ToolSchema.text("Nouveau début (AAAA-MM-JJTHH:MM)."),
                "end": ToolSchema.text("Nouvelle fin (AAAA-MM-JJTHH:MM)."),
            ], required: ["id"]),
            readOnly: false
        ),
        MCPTool(
            name: "set_absence",
            title: "Marquer une absence",
            description: "Marque un jour comme absence (congé, férié) : Done n'y propose rien. Change le libellé si le jour est déjà marqué.",
            schema: ToolSchema.object([
                "date": ToolSchema.text("Jour (AAAA-MM-JJ)."),
                "label": ToolSchema.text("Libellé, « Absence » par défaut."),
            ], required: ["date"]),
            readOnly: false
        ),
    ]
}

/// Petits constructeurs de schémas JSON pour les arguments des outils.
enum ToolSchema {
    static func object(_ properties: [String: JSONValue], required: [String] = []) -> JSONValue {
        var fields: [String: JSONValue] = ["type": "object", "properties": .object(properties)]
        if !required.isEmpty { fields["required"] = .array(required.map { .string($0) }) }
        return .object(fields)
    }

    static func text(_ description: String) -> JSONValue {
        .object(["type": "string", "description": .string(description)])
    }

    static func texts(_ description: String) -> JSONValue {
        .object(["type": "array", "items": .object(["type": "string"]), "description": .string(description)])
    }

    static func flag(_ description: String) -> JSONValue {
        .object(["type": "boolean", "description": .string(description)])
    }

    static func integer(_ description: String, min: Int, max: Int) -> JSONValue {
        .object(["type": "integer", "minimum": .int(min), "maximum": .int(max), "description": .string(description)])
    }

    static func choice(_ values: [String], _ description: String) -> JSONValue {
        .object(["type": "string", "enum": .array(values.map { .string($0) }), "description": .string(description)])
    }
}
