# Done

App macOS personnelle (SwiftUI, SwiftData, macOS 14+) qui transforme les tâches Todoist en sessions Pomodoro. Lire `docs/vision.md` et `docs/spec.md` avant de proposer une fonctionnalité : la spec classe ce qui est MVP, plus tard ou hors périmètre. Pour toute modification d'interface, suivre `docs/design-system.md` (maquettes v9 « Verre » dans `docs/design/Done-Ecrans-v9.html`).

## Langue

- Interface, commentaires et documentation en français. Identifiants Swift en anglais.
- Textes d'interface courts et directs, sans point d'exclamation.

## Architecture

- `Done/Core/` : logique pure, sans SwiftUI, SwiftData ni AppKit. Les règles de choix (`Planner`), les stats et le décodage Todoist vivent ici. Garder cette séparation : c'est ce qui permet de tester la logique hors de l'app.
- `Done/State/` : `AppModel` (tâches, projets, plan du jour) et `FocusEngine` (machine à états du minuteur). Classes `@Observable @MainActor`, injectées par `.environment(...)`.
- `Done/Data/Records.swift` : modèles SwiftData. Les enums sont stockés en `String` brut (`outcomeRaw`, `reasonRaw`).
- `Done/Services/` : `TodoistClient` (API v1, token Bearer), `Keychain`, `Notifier`, `DoNotDisturb` (lance les raccourcis `Done Focus On` / `Done Focus Off` via `/usr/bin/shortcuts`), `TeamsStatus` (statut Teams via Microsoft Graph, avec `PKCE`), `SystemBridge` (seul fichier qui importe AppKit côté logique, y compris la feuille de connexion Microsoft).
- Dans `FocusEngine`, tout changement de phase passe par `transition(to:)`, qui synchronise « Ne pas déranger », le statut Teams et la protection contre App Nap. Ne pas assigner `phase` directement.
- `Done/Views/Theme.swift` : couleurs du design system (clair et sombre), polices (`Font.display`, `Font.mono`, `Font.text`), fonds `Backdrop`, verre (`glassBackground`, `liquidGlass`), cartes `surface(radius:)`, boutons `PillButtonStyle`, sélecteur `GlassSegmented`, logo. Utiliser `Theme.*` plutôt que les couleurs système, ces polices plutôt que `.system`, et ces composants plutôt que des styles ad hoc.
- Polices embarquées dans `Done/Fonts` (Plus Jakarta Sans, DM Sans, DM Mono, licences OFL dans `docs/fonts/`), chargées au lancement par `FontLoader`.
- Les réglages passent par `UserDefaults` (`SettingsKey`), lus dans `Rules.current` et modifiés via `@AppStorage` dans `SettingsView`.

## Todoist

- API v1 : `https://api.todoist.com/api/v1/`. Pagination par `next_cursor`, résultats dans `results` (ou `items` pour les tâches terminées).
- Priorité API inversée : 4 = P1, 1 = P4. Utiliser `displayPriority` pour l'affichage.
- Todoist reste la source de vérité. L'app lit les tâches et ne fait que trois écritures : cocher une tâche (`POST /tasks/{id}/close`), créer une sous-tâche (`POST /tasks` avec `parent_id`, découpage assisté) et remplacer les labels (`POST /tasks/{id}` avec `labels`, garde-fou des chantiers actifs).
- Le bilan du soir et le report vers le plan du lendemain sont stockés dans `UserDefaults` (`review.lastDay`, `review.carryOver`), pas dans SwiftData. La logique pure est dans `Done/Core/Rituals.swift`.
- Les notes de reprise sont dans `UserDefaults` (`resume.notes`), par identifiant de tâche, nettoyées à chaque synchro (`Done/Core/ResumeNotes.swift`). Les rappels « réunion proche » sont reprogrammés après chaque synchro (`Done/Core/MeetingReminder.swift`).

## Microsoft Graph (statut Teams)

- Seulement deux appels : `POST /users/{id}/presence/setUserPreferredPresence` (« Ne pas déranger » avec une expiration) et `clearUserPreferredPresence`. Permission déléguée `Presence.ReadWrite`, sans accord administrateur.
- Connexion par code d'autorisation avec PKCE (`MicrosoftAuth`, `PKCE`, `SystemBridge.webSignIn`), redirection `done://auth`. Le jeton de renouvellement va au trousseau, le jeton d'accès reste en mémoire.
- L'ID d'application et l'ID d'annuaire sont saisis dans les Réglages : aucun identifiant Microsoft dans le code.

## Conventions

- Swift 5 (réglage du projet), pas de dépendance externe.
- Le projet Xcode utilise un dossier synchronisé : ajouter un fichier dans `Done/` suffit.
- Pas de token, d'identifiant de tâche ni de donnée Todoist réelle dans le code ou les commits.

## Prochaines étapes utiles

- Ajouter une cible de tests unitaires et y couvrir `Planner` et `Stats` en priorité.
- Voir `docs/questions.md` pour les règles à valider à l'usage.
