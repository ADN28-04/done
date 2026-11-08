Done est une app macOS de tâches et de pomodoros. Direction « Jardin » : un outil de travail chaleureux. Du papier crème, une encre vert-brun pour le texte, un vert profond pour ce qui agit, un tournesol pour la joie, une brique pour les seules alertes. L'écran reste calme ; c'est le geste qui fait plaisir : cocher une tâche, finir un pomodoro, boucler le plan du jour.

## Principes

- Une seule chose forte par écran : `displayXL` (Fraunces) pour l'action proposée, ou `numericXL` (Archivo) pour le minuteur. Tout le reste est en `body`, `callout` ou `caption`.
- Calme au repos, joyeux à l'arrivée. Les couleurs vives (`sun`) et le rebond (`ease-spring`) sont réservés aux réussites : tâche cochée, pomodoro terminé, plan du jour bouclé. Une vue qu'on regarde sans agir ne bouge pas.
- Pas d'ombre sur les cartes, seulement un liseré `borderSubtle`. `shadowRaised` sert à la carte de fin de pomodoro et à la saisie flottante.
- Pas de fond derrière les dates, les durées et les étiquettes : `InfoChip` et `TagChip` sont du texte `textSecondary` avec une icône.
- Pas de capitales espacées : les étiquettes de section (`label`) sont en casse normale.
- Les nombres restent en Archivo, en chiffres tabulaires (`font-variant-numeric: tabular-nums`, `monospacedDigit` dans SwiftUI), jamais en Fraunces.
- Un seul bouton principal (`actionPrimary`) par vue.
- Le code ne cite jamais une couleur de marque ni une couleur système : seulement les rôles ci-dessous, les styles de texte et les composants.

## Contenu

- Interface en français, textes courts et directs, sans point d'exclamation. Verbes à l'infinitif sur les boutons : « Lancer le focus », « Cocher la tâche », « Ajouter ».
- La chaleur passe par les faits, pas par les adjectifs : « 3e pomodoro aujourd'hui », « Plan du jour terminé. Tout ce qui était prévu est fait. » Pas de « Bravo », pas de « Super ».
- Casse de phrase partout : « Plan du jour », « Échéances et retards », « Fait aujourd'hui ».
- Formats : « 1 h 30 », « 45 min », « 14:00 », minuteur « 18:42 », date courte « mar. 3 nov. », dates relatives « Auj. », « Demain », « Hier ».
- Messages vides et d'état en une phrase : « Aucune tâche ouverte. », « En pause ».
- Pas d'emoji : le soleil est une icône, pas un caractère.

## Couleurs

La marque tient en cinq couleurs, qui n'apparaissent jamais sous leur nom dans le code : Crème #F7F3E8, Encre #23281F, Vert profond #2F6B4F, Tournesol #F6C343, Brique #A3332E. Le code passe par des rôles, qui changent de valeur entre les thèmes Clair et Sombre.

- Fonds : `bgCanvas` pour la fenêtre, `bgSunken` pour la barre latérale et les pistes, `surfaceDefault` pour les cartes et les champs, `surfaceHover` au survol, `surfaceSelected` pour la navigation active.
- Texte : `textPrimary` pour le texte courant, `textSecondary` pour les métadonnées, dates et durées, `textDisabled` pour ce qui est inactif seulement.
- Action : `actionPrimary` (survol `actionPrimaryHover`, appui `actionPrimaryPressed`) avec `actionOnPrimary` pour le bouton principal et la case cochée. En sombre, le vert s'éclaircit et le texte posé dessus devient vert nuit, pas blanc. `focusRing` pour le focus et les cibles de dépôt.
- États : `stateActive`, `stateActiveText` et `stateActiveTint` pour les priorités, les tuiles du plan et les barres ; `stateBlocked` pour « Bloquée » ; `stateDone` et `stateOnDone` pour ce qui recule ; `stateWaiting` pour les emplacements libres, en pointillé.
- Joie : `sun` en plein ou en forme (soleil, pétales, pastilles de série), jamais en texte ; `sunTint` et `sunText` pour « Aujourd'hui », « Fait » et les messages de réussite ; `onSun` pour ce qui est posé sur `sun`.
- Alerte : `stateRisk`, `stateRiskTint`, `stateRiskText`, seulement pour une échéance dépassée et une erreur. Jamais pour une réunion, jamais pour la fin d'un pomodoro, jamais pour l'heure courante.
- Tournesol et brique ne se confondent pas : clartés très différentes, et une icône différente (soleil, triangle) à chaque fois.
- Toutes les paires texte et fond passent AA dans les deux thèmes : `textSecondary` sur `bgCanvas` 5,62:1 en clair et 7,63:1 en sombre, `actionOnPrimary` sur `actionPrimary` 6,29:1 et 7,88:1, `sunText` sur `sunTint` 6,86:1 et 8,63:1. `borderControl`, `focusRing` et les anneaux passent 3:1. `sun` seul sur le papier clair ne fait que 1,5:1 : c'est pour cela qu'il ne porte jamais un sens seul.

## Typographie

Deux familles, sous licence OFL :

- `display` : Fraunces, dans sa version douce (axe SOFT à 100, WONK à 0), variable en graisse et en taille optique. Pour `displayXL`, `displayL` et `displayM` seulement : l'action proposée, les titres d'écran, les titres de carte et de feuille. Ses courbes rondes donnent sa chaleur à l'app.
- `sans` : Archivo Regular, Medium et SemiBold pour `title`, `body`, `bodyStrong`, `callout`, `caption` et `label`, les boutons et la navigation.
- Nombres : Archivo pour les quatre styles `numeric…`, en chiffres tabulaires, pour que les colonnes et le minuteur ne bougent pas en largeur. `numericXL` passe en Regular (au lieu de Light) pour tenir face à Fraunces.

Un libellé reste dans un style de texte, même dans une puce. Fraunces ne descend jamais sous `displayM` (23).

## Mesures

- Espacements sur une grille de 4, avec `s2` et `s6` pour les détails : `s8` entre lignes, `s12` dans une ligne et entre les puces, `s16` dans une carte, `s24` pour les marges de panneau, `s32` entre sections, `s40` pour les marges d'écran.
- Rayons doux : `xs` (5) pour la case à cocher et le segment choisi, `chip` (8) pour les puces, `sm` (10) pour les boutons, champs, réunions et la navigation, `md` (14) pour les lignes et les cartes, `lg` (20) pour les panneaux et les feuilles. Pas de pilule, sauf la barre de progression.
- Contours : `border-hairline` en `borderSubtle` pour les cartes, en `borderDefault` pour les boutons secondaires, en `borderControl` pour les champs ; `border-checkbox` pour la case et le pointillé `stateWaiting` ; `border-focus` en `focusRing`.
- Hauteurs fixes : `control-height` (32), `control-compact` (26), `chip-height` (22), `checkbox-size` (18), `row-height` (48), `sidebar-width` (228), `topbar-height` (52).

## Mouvement

Le mouvement dit « c'est fait » ; il ne décore pas. Il suit trois règles :

- Ce qui arrive ralentit en se posant (`ease-out`). Ce qui se déplace accélère puis freine (`ease-in-out`). Seules les réussites rebondissent (`ease-spring`), et une seule fois.
- Rien ne bouge sans action de la personne, sauf l'anneau du minuteur.
- Avec « Réduire les animations » (macOS), on garde les fondus et on retire échelles, rebonds et éclats.

Durées : `dur-instant` (90 ms) pour l'appui, `dur-fast` (160 ms) pour le survol et les coches, `dur-base` (260 ms) pour les puces et les segments, `dur-slow` (420 ms) pour les cartes et les feuilles, `dur-celebrate` (900 ms) pour l'éclat de tournesol.

Équivalents SwiftUI, pour `Theme.swift` :

| Token | CSS | SwiftUI |
| --- | --- | --- |
| `ease-out` + `dur-fast` | `160ms cubic-bezier(0.2, 0.8, 0.2, 1)` | `.easeOut(duration: 0.16)` |
| `ease-out` + `dur-slow` | `420ms cubic-bezier(0.2, 0.8, 0.2, 1)` | `.smooth(duration: 0.42)` |
| `ease-in-out` + `dur-base` | `260ms cubic-bezier(0.65, 0, 0.35, 1)` | `.easeInOut(duration: 0.26)` |
| `ease-spring` + `dur-base` | `260ms cubic-bezier(0.34, 1.56, 0.64, 1)` | `.spring(response: 0.3, dampingFraction: 0.55)` |

Les moments animés :

- Cocher une tâche (`TaskCheckbox`, `TaskRow`) : la case rebondit, la coche se trace, huit pétales `sun` partent, le titre se barre, « Fait » arrive en rebondissant, puis la ligne glisse vers « Fait aujourd'hui ».
- Fin de pomodoro (`PomodoroDone`) : la carte monte, l'anneau se referme, la coche se trace, l'éclat part, la pastille de série rebondit.
- Plan du jour terminé : l'encadré de réussite (`NoticeBox`, ton `success`) arrive en fondu, le soleil de « Aujourd'hui » fait un seul éclat.
- Pause : le fond passe à `pomodoroBreakBg` et l'anneau à `pomodoroBreak` en `dur-slow`, ensemble.
- Sélecteur (`Segmented`) : le segment choisi glisse vers la nouvelle option.
- Boutons et cases : ils se tassent à l'appui (`dur-instant`).

## Iconographie

- L'app utilise les SF Symbols d'Apple, en graisse Medium ou SemiBold, à 9 à 16 pt, en `textSecondary` dans les puces et en `textPrimary` dans les boutons. Symboles en usage : `calendar`, `clock`, `tag`, `checkmark`, `nosign`, `exclamationmark.triangle`, `info.circle`, `sun.max`, `calendar.day.timeline.left`, `doc.text`, `folder`, `chevron.down`, `chevron.right`.
- `sun.max` devient le signe de la journée : dans la navigation (« Aujourd'hui », en `sunText`), dans la puce « Aujourd'hui » et dans l'encadré de réussite.
- Les SF Symbols ne sont pas livrés ici : les aperçus des composants les remplacent par des tracés simples au trait, en `currentColor`.
- Une icône double toujours une couleur d'état : soleil pour « Aujourd'hui », coche pour « Fait », interdit pour « Bloquée », triangle pour l'alerte.

## Logo

- `done-app-icon.svg` : carré arrondi en dégradé de vert (#3B7A5B en haut, #204F3A en bas), anneau crème à 24 % et arc crème de 300° partant du haut, un minuteur presque refermé. Dans l'ouverture, un soleil tournesol : la tâche est presque faite, la journée se lève. Pour le Dock, le Finder et toute vignette de l'app.
- `done-glyph.svg` : le même anneau, le même arc et le même soleil, en une seule encre noire, pour la navigation et la barre de menus en image « template » qui prend la couleur du système.
- Le soleil reste un disque plein, sans rayons : il doit se lire à 16 px. Ne pas recolorer l'icône, ne pas déplacer le soleil.
- L'ancien logo indigo de la v5 est gardé dans le groupe Logos v5, pour mémoire.

## Composants

Les composants sont en SwiftUI dans l'app ; leurs aperçus ici sont des rendus HTML et CSS (`components/bundle.css`, classes `d-…`), animés comme dans l'app. `Button`, `IconButton`, `Stepper` et `Segmented` pour agir ; `Field` et `TaskCheckbox` pour saisir ; `StateChip`, `InfoChip`, `TagChip` et `PriorityChip` sur les lignes ; `Card` et `NoticeBox` pour regrouper et signaler ; `NavItem` pour la barre latérale ; `TaskRow` pour une ligne de tâche ; `MeetingBlock` pour le calendrier ; `ProgressRing`, `ProgressBar` et `PomodoroDone` pour le pomodoro.

## En avance sur le code

- Ce design system décrit la direction Jardin ; `Done/Views/Theme.swift` (commit `fc5fd9f`) est encore en v5, indigo et Archivo SemiCondensed. Les noms des rôles n'ont pas changé : le report dans le code consiste surtout à changer les valeurs de `DoneColor`, `DoneRadius` et `DoneTextStyle`, et à ajouter `sun`, `onSun`, `sunTint`, `sunText`.
- À remplacer dans l'app : `AppIcon` (16 à 1024), `DoneGlyph` (18 et 36) et `AccentColor` (`stateActive`), à partir des SVG du groupe Logos.
- À ajouter dans l'app : la police Fraunces (fichier `fonts/Fraunces-Soft-Variable.woff2`, ou les TTF de Google Fonts) chargée par `FontLoader`, le genre `today` de `StateChip`, le ton `success` de `NoticeBox`, la carte `PomodoroDone` et les animations décrites plus haut.
- Une nouvelle synchronisation depuis GitHub remettrait les valeurs v5 : la faire seulement après le report dans `Theme.swift`.
- Les SF Symbols ne sont pas copiés (voir Iconographie).
