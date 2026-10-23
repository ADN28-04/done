# Done

App macOS personnelle (SwiftUI, SwiftData, macOS 14+) qui transforme les tâches Todoist en sessions Pomodoro. Lire `docs/vision.md` et `docs/spec.md` avant de proposer une fonctionnalité : la spec classe ce qui est MVP, plus tard ou hors périmètre. Pour toute modification d'interface, suivre `docs/design-system.md` (maquettes v9 « Verre » dans `docs/design/Done-Ecrans-v9.html`).

## Langue

- Interface, commentaires et documentation en français. Identifiants Swift en anglais.
- Textes d'interface courts et directs, sans point d'exclamation.

## Architecture

- `Done/Core/` : logique pure, sans SwiftUI, SwiftData ni AppKit. Les règles de choix (`Planner`), les stats et le décodage Todoist vivent ici. Garder cette séparation : c'est ce qui permet de tester la logique hors de l'app.
- `Done/State/` : `AppModel` (tâches, projets, plan du jour) et `FocusEngine` (machine à états du minuteur). Classes `@Observable @MainActor`, injectées par `.environment(...)`.
- `Done/Data/Records.swift` : modèles SwiftData. Les enums sont stockés en `String` brut (`outcomeRaw`, `reasonRaw`).
- `Done/Services/` : `TodoistClient` (API v1, token Bearer), `Keychain`, `Notifier`, `DoNotDisturb` (lance les raccourcis `Done Focus On` / `Done Focus Off` via `/usr/bin/shortcuts`), `ClaudeClient` (API Claude en HTTP direct), `ContextFolder` (dossier de contexte lu par Claude), `SystemBridge` (seul fichier qui importe AppKit côté logique, y compris l'extraction de texte des PDF et documents Word).
- Dans `FocusEngine`, tout changement de phase passe par `transition(to:)`, qui synchronise « Ne pas déranger » et la protection contre App Nap. Ne pas assigner `phase` directement.
- Une étape enchaînée dans le même pomodoro (`chainToNext`) ouvre sa propre `FocusSession` : `recordOffset` retire le temps des étapes précédentes. La rallonge (`extend`) est plafonnée par `Rules.maxExtensionMinutes`. Une pause obligatoire (`breakIsMandatory`) ne se passe pas ; `BreakDue` (`Done/Core/Sessions.swift`) garde la pause due avant de changer de tâche principale, et la suite d'une action cochée vient de `Planner.followUp`. Une étape bloquée (`markBlocked`) reçoit `@Waiting` puis un commentaire « Bloqué : … » (aussi gardé en note de reprise) ; sa suite vient de `Planner.followUp(blocking:)`, qui ne propose jamais de clore la tâche principale.
- `Done/Views/Theme.swift` : couleurs du design system (clair et sombre), polices (`Font.display`, `Font.mono`, `Font.text`), fonds `Backdrop`, verre (`glassBackground`, `liquidGlass`), cartes `surface(radius:)`, boutons `PillButtonStyle`, sélecteur `GlassSegmented`, logo. Utiliser `Theme.*` plutôt que les couleurs système, ces polices plutôt que `.system`, et ces composants plutôt que des styles ad hoc.
- Polices embarquées dans `Done/Fonts` (Plus Jakarta Sans, DM Sans, DM Mono, licences OFL dans `docs/fonts/`), chargées au lancement par `FontLoader`.
- Les réglages passent par `UserDefaults` (`SettingsKey`), lus dans `Rules.current` et modifiés via `@AppStorage` dans `SettingsView`.

## Todoist

- API v1 : `https://api.todoist.com/api/v1/`. Pagination par `next_cursor`, résultats dans `results` (ou `items` pour les tâches terminées).
- Priorité API inversée : 4 = P1, 1 = P4. Utiliser `displayPriority` pour l'affichage.
- Todoist reste la source de vérité. L'app lit les tâches et ne fait que quatre écritures : cocher une tâche (`POST /tasks/{id}/close`), créer une sous-tâche (`POST /tasks` avec `parent_id`, découpage assisté), remplacer les labels (`POST /tasks/{id}` avec `labels`, garde-fou des chantiers actifs et étape bloquée) et commenter une tâche (`POST /comments` avec `task_id` et `content`, étape bloquée).
- Le bilan du soir et le report vers le plan du lendemain sont stockés dans `UserDefaults` (`review.lastDay`, `review.carryOver`), pas dans SwiftData. La logique pure est dans `Done/Core/Rituals.swift`.
- Les notes de reprise sont dans `UserDefaults` (`resume.notes`), par identifiant de tâche, nettoyées à chaque synchro (`Done/Core/ResumeNotes.swift`). Les rappels « réunion proche » sont reprogrammés après chaque synchro (`Done/Core/MeetingReminder.swift`).

## API Claude (découpage assisté)

- `POST https://api.anthropic.com/v1/messages`, en-tête `anthropic-version: 2026-10-21` (pas de `temperature`, `top_p` ni `top_k`), clé dans le trousseau (`Keychain.anthropicAccount`). Il n'y a pas de SDK Swift officiel : appels HTTP directs, corps en JSON à clés triées pour garder le cache valide.
- Modèle par défaut `claude-opus-5-5`, effort `medium`, repli `fallbacks: "default"` avec l'en-tête `anthropic-beta: server-side-fallback-2026-07-01` (pas pour Haiku 5.5). Réponse imposée par `output_config.format` (schéma dans `Breakdown.outputSchema`).
- Claude lit le dossier de contexte avec l'outil strict `read_context_files`, limité aux chemins de la liste. Le contenu des réponses repart tel quel (blocs de réflexion compris) ; au dernier tour, `tool_choice: none` impose une réponse. Consignes et limites dans `Done/Core/Breakdown.swift`.
- Pièces jointes d'une tâche : chemins gardés dans `UserDefaults` (`attachments.byTask`, `Done/Core/TaskAttachments.swift`), chargées par `AttachmentLoader` et envoyées dans le premier message utilisateur avant la tâche (blocs `document` pour les PDF, `image` en JPEG, texte sinon), jamais dans un message `assistant`.
- Toujours traiter `stop_reason` (`refusal`, `max_tokens`) avant de lire la réponse.

## Conventions

- Swift 5 (réglage du projet), pas de dépendance externe.
- Le projet Xcode utilise un dossier synchronisé : ajouter un fichier dans `Done/` suffit.
- Pas de token, d'identifiant de tâche ni de donnée Todoist réelle dans le code ou les commits.

## Prochaines étapes utiles

- Ajouter une cible de tests unitaires et y couvrir `Planner` et `Stats` en priorité.
- Voir `docs/questions.md` pour les règles à valider à l'usage.
