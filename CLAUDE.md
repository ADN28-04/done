# Done

App macOS personnelle (SwiftUI, SwiftData, macOS 14+) qui gère simplement une liste de tâches et un minuteur Pomodoro. Tout reste sur le Mac : pas de Todoist, pas de serveur, pas d'IA intégrée. Lire `docs/vision.md` et `docs/spec.md` avant de proposer une fonctionnalité : la spec classe ce qui est actuel, plus tard ou hors périmètre, et l'objectif est de garder l'app simple. Pour toute modification d'interface, suivre `docs/design-system.md` (design system v5, référence dans `docs/design/Done-Design-System-v5.html`).

## Langue

- Interface, commentaires et documentation en français. Identifiants Swift en anglais.
- Textes d'interface courts et directs, sans point d'exclamation.

## Architecture

- `Done/Core/` : logique pure, sans SwiftUI, SwiftData ni AppKit. Les tâches (`TodoTask`, `Project`, `Meeting`, `TaskStore` dans `Tasks.swift`), les règles de choix (`Planner`), les rituels et les stats vivent ici. Garder cette séparation : c'est ce qui permet de tester la logique hors de l'app.
- `TaskStore` porte toutes les opérations sur les tâches (ajout, modification, cocher, rouvrir, supprimer, réordonner, projets, réunions), en fonctions pures. `AppModel.commit` les applique, reconstruit l'index des tâches ouvertes (`TaskIndex`) et réécrit le fichier. Ne pas modifier `store` autrement.
- `Done/State/` : `AppModel` (tâches, projets, réunions, plan du jour, bilan, notes de reprise) et `FocusEngine` (machine à états du minuteur). Classes `@Observable @MainActor`, injectées par `.environment(...)`.
- `Done/Data/Records.swift` : modèles SwiftData (plan du jour, sessions, interruptions). Les enums sont stockés en `String` brut (`outcomeRaw`, `reasonRaw`). `BacklogSnapshot` n'est plus utilisé mais reste déclaré pour ouvrir les bases existantes sans migration.
- `Done/Services/` : `TaskStorage` (fichier `tasks.json` dans Application Support, écriture atomique, une sauvegarde par jour gardée 30 jours, fichier illisible mis de côté et jamais écrasé), `Notifier`, `DoNotDisturb` (lance les raccourcis `Done Focus On` / `Done Focus Off` via `/usr/bin/shortcuts`), `SystemBridge` (seul fichier qui importe AppKit côté logique).
- Dans `FocusEngine`, tout changement de phase passe par `transition(to:)`, qui synchronise « Ne pas déranger » et la protection contre App Nap. Ne pas assigner `phase` directement.
- Une étape enchaînée dans le même pomodoro (`chainToNext`) ouvre sa propre `FocusSession` : `recordOffset` retire le temps des étapes précédentes. La rallonge (`extend`) est plafonnée par `Rules.maxExtensionMinutes`. Une pause obligatoire (`breakIsMandatory`) ne se passe pas ; `BreakDue` (`Done/Core/Sessions.swift`) garde la pause due avant de changer de tâche principale, et la suite d'une action cochée vient de `Planner.followUp`. Une étape bloquée (`markBlocked`) passe `isBlocked` à vrai et garde la raison en note de reprise ; sa suite vient de `Planner.followUp(blocking:)`, qui ne propose jamais de clore la tâche principale.
- `Done/Views/Theme.swift` : design system v5. Couleurs par rôle en clair et en sombre (`DoneColor.textPrimary`, `DoneColor.stateActive`…), échelle typographique (`.doneText(.body)`, `Font.done(_:)`, `Font.sans(_:_:)`), espacements (`DoneSpace`), rayons (`DoneRadius`), cartes (`doneCard`, `doneRaised`), champs (`doneField`), boutons (`DoneButtonStyle`, `DoneIconButtonStyle`), case à cocher (`TaskCheckbox`), puces (`StateChip`, `InfoChip`, `PriorityChip`), navigation (`NavItem`), réunions (`MeetingBlock`, `Hatching`), anneau (`ProgressRing`). Le code ne référence jamais une couleur de marque ni une couleur système : seulement ces rôles, ces styles de texte plutôt que `.system`, et ces composants plutôt que des styles ad hoc.
- Polices embarquées dans `Done/Fonts` (une seule famille, Archivo : SemiCondensed SemiBold pour les titres d'affichage, Regular, Medium et SemiBold pour le texte, Light pour le minuteur ; licence OFL dans `docs/fonts/`), chargées au lancement par `FontLoader`. Les nombres prennent les chiffres tabulaires (`monospacedDigit`, appliqué par les styles `numeric…`), jamais une police à chasse fixe. Étiquettes en casse normale, pas de capitales espacées.
- Les réglages passent par `UserDefaults` (`SettingsKey`), lus dans `Rules.current` et modifiés via `@AppStorage` dans `SettingsView`.

## Tâches

- Priorité de 1 (P1) à 4 (P4), sans inversion. Type de travail (`TaskKind` : normale, rapide, Deepwork) pour la durée des sessions. Échéance enregistrée comme clé de jour (« 2026-10-31 »). Une sous-tâche suit toujours le projet de sa parente.
- Le fichier JSON est lu de façon tolérante : un champ absent prend sa valeur par défaut. Tout nouveau champ doit avoir une valeur par défaut dans `init(from:)`.
- Les réunions sont saisies à la main et oubliées le lendemain. Les rappels « réunion proche » sont reprogrammés à chaque changement de réunion ou de réglage (`Done/Core/MeetingReminder.swift`).
- Le bilan du soir et le report vers le plan du lendemain sont stockés dans `UserDefaults` (`review.lastDay`, `review.carryOver`). La logique pure est dans `Done/Core/Rituals.swift`.
- Les notes de reprise sont dans `UserDefaults` (`resume.notes`), par identifiant de tâche, effacées quand la tâche est cochée ou supprimée (`Done/Core/ResumeNotes.swift`).

## Conventions

- Swift 5 (réglage du projet), pas de dépendance externe, aucun appel réseau.
- Le projet Xcode utilise un dossier synchronisé : ajouter un fichier dans `Done/` suffit.
- Pas de donnée de travail réelle (tâches, noms de collègues) dans le code ou les commits.

## Prochaines étapes utiles

- Ajouter une cible de tests unitaires et y couvrir `TaskStore`, `Planner` et `Stats` en priorité.
- Voir `docs/questions.md` pour les règles à valider à l'usage.
