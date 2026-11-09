Done est une app macOS de tâches et de pomodoros. Direction « Mymind » : un tableau de bord calme et moderne, où la journée tient sur un seul écran. Une toile presque blanche, une encre graphite, des cartes qui flottent, une serif élégante pour les titres, la braise pour la marque et les réussites, le cobalt pour ce qui est actif. L'écran reste posé ; c'est le geste qui fait plaisir : cocher une tâche, finir un pomodoro, boucler le plan du jour.

## Principes

- Ma journée est l'écran d'accueil (`ControlCenter`) : prochaine action, ligne de temps, plan du jour, échéances, notes et focus du jour, dans six cartes widget. Les autres écrans (Calendrier, Notes, Listes, Stats) s'ouvrent depuis le `Rail` ou le lien en haut à droite de chaque carte.
- Une seule chose forte par écran : le titre d'accueil en `displayXL`, puis la prochaine action en `displayL`. Tout le reste est en `body`, `callout` ou `caption`.
- Un seul bouton principal (`actionPrimary`, pilule d'encre) par écran : « Lancer le focus » sur Ma journée.
- Tout ce qui se clique est une pilule (`pill`). Les cartes sont de grands rectangles doux (`lg`, 24) avec un liseré et une ombre très légère (`shadowCard`).
- Calme au repos, joyeux à l'arrivée : la braise (`accent`) et le rebond (`ease-spring`) sont réservés aux réussites et à la marque.
- Pas de fond derrière les dates et les durées d'une ligne : `InfoChip` et `TagChip` restent du texte avec une icône. La pilule colorée (`TagPill`) est pour les cartes.
- Pas de capitales espacées. Les nombres sont en Nunito Sans, dont les chiffres sont déjà à chasse fixe.
- Le code ne cite jamais une couleur de marque ni une couleur système : seulement les rôles ci-dessous, les styles de texte et les composants.

## Contenu

- Interface en français, textes courts et directs, sans point d'exclamation. Verbes à l'infinitif sur les boutons : « Lancer le focus », « Capturer », « Découper… ».
- Le titre d'accueil dit la journée en une phrase de faits : « Bonjour Adnan, trois tâches et deux réunions aujourd'hui. » Nombres en lettres jusqu'à dix. Pas de « Bravo ».
- Casse de phrase partout : « Plan du jour », « Échéances et retards », « Toutes les notes ».
- Formats : « 1 h 30 », « 45 min », « 14:00 », minuteur « 18:42 », date courte « mar. 3 nov. », dates relatives « Auj. », « Demain », « Hier ».
- Les textes d'aide donnent un vrai exemple : « Appeler le transporteur demain P2 ».
- Pas d'emoji.

## Couleurs

La marque reprend les couleurs de mymind et tient en cinq couleurs, qui n'apparaissent jamais sous leur nom dans le code : Toile #F9FAFC, Encre #24272D, Braise #FF5924, Cobalt #1573DD, Rose des halos #F078A0. Le code passe par des rôles, qui changent de valeur entre les thèmes Clair et Sombre.

- Fonds : `bgCanvas` pour la fenêtre, avec deux halos en dégradé radial (`haloWarm` en haut à droite, `haloPink` en bas à gauche) ; `bgSunken` pour le rail et les pistes ; `surfaceDefault` pour les cartes ; `surfaceHover` et `surfaceSelected`.
- Texte : `textPrimary`, `textSecondary` (métadonnées, et la salutation en italique), `textDisabled` pour ce qui est inactif seulement.
- Action : `actionPrimary` et `actionOnPrimary`, une pilule d'encre, inversée en sombre. `focusRing` en cobalt, qui est aussi l'AccentColor de macOS.
- Marque et joie : `accent` (braise) en plein ou en forme : bouton + du rail, anneau du minuteur, heure courante, soleil de « Aujourd'hui », pétales, pastilles de série. Jamais en texte : il ne fait que 3,1:1 sur blanc. Pour du texte, `accentText` sur `accentTint`.
- Actif : `stateActive` (cobalt) pour les tuiles du plan, les barres et les liens ; `stateActiveText` et `stateActiveTint` pour P1 et l'information.
- Fait : `success`, `successTint`, `successText` pour la puce « Fait ».
- Alerte : `stateRisk`, `stateRiskTint`, `stateRiskText`, seulement pour une échéance dépassée et une erreur, toujours avec le triangle. La braise et l'alerte sont deux rouges-orangés : l'alerte est nettement plus sombre en clair et plus claire en sombre, n'est jamais sur un bouton, et porte toujours son icône.
- Notes : une teinte de carte par type (`cardBlush`, `cardSlate`, `cardSage`, `cardParchment`) et une couleur d'étiquette (`tagPink`, `tagYellow` en plus des rôles).
- Toutes les paires texte et fond passent AA dans les deux thèmes, teintes de cartes comprises : `textSecondary` sur `bgCanvas` 5,61:1 en clair et 8,07:1 en sombre, `actionOnPrimary` sur `actionPrimary` 14,97:1 et 15,74:1, `accentText` sur `accentTint` 5,21:1 et 7,47:1, `stateOnActive` sur `stateActive` 4,64:1 et 6,56:1. `borderControl`, `focusRing`, `accent` et les anneaux passent 3:1.

## Typographie

Trois familles libres (licence OFL), choisies pour approcher celles de mymind (Louize pour les titres, Avenir et Nunito pour l'interface) :

- `display` : Newsreader, variable en graisse et en taille optique, avec son italique. Pour `displayXL`, `displayL`, `displayM` et `noteTitle`. Medium (500), approche serrée. La salutation du titre d'accueil passe en italique.
- `sans` : Nunito Sans, variable. Regular pour le texte, SemiBold pour les libellés et les titres de tâche, Bold pour `title` et `label`, Light pour les grands chiffres (`numericXL`, `numericL`). Ses chiffres sont à chasse fixe par défaut : le minuteur et les colonnes ne bougent pas.
- `mono` : Courier Prime, pour `noteMono` seulement : le corps du journal et des notes rapides dans la mosaïque, comme un brouillon tapé à la machine.
- `timer` : Oswald SemiBold (600), pour les chiffres du minuteur de session seulement, en cases de largeur fixe (voir `maquettes/minuteur-de-focus.html`).

Newsreader ne descend jamais sous `noteTitle` (17) et ne sert jamais aux nombres.

## Mesures

- Espacements sur une grille de 4 : `s12` dans une ligne, `s16` entre les cartes, 20 × 22 dans une carte, 30 × 36 autour de l'écran.
- Rayons : `xs` (6) pour la case à cocher, `sm` (12) pour les champs, tuiles et réunions, `md` (18) pour les lignes, notes et encadrés, `lg` (24) pour les cartes et feuilles, `pill` pour tout ce qui se clique et les puces.
- Contours : `border-hairline` en `borderSubtle` pour les cartes, en `borderDefault` pour les pilules secondaires, en `borderControl` pour les champs ; `border-focus` en `focusRing` ; `border-ring` (6) pour les anneaux, fins comme le logo.
- Hauteurs fixes : `control-height` (34), `control-compact` (28), `chip-height` (22), `checkbox-size` (18), `row-height` (48), `rail-width` (84), `rail-button` (44), `capture-height` (54).

## Mouvement

Le mouvement dit « c'est fait » ; il ne décore pas.

- Ce qui arrive ralentit en se posant (`ease-out`). Ce qui se déplace accélère puis freine (`ease-in-out`). Seules les réussites rebondissent (`ease-spring`), une seule fois.
- Rien ne bouge sans action de la personne, sauf l'anneau du minuteur, l'heure courante et deux mouvements d'ambiance très lents : les halos qui dérivent et le soleil de la date qui fait un tour à l'ouverture.
- Avec « Réduire les animations » (macOS), on garde les fondus et on retire échelles, rebonds, éclats et ambiance.

Durées : `dur-instant` (90 ms) pour l'appui, `dur-fast` (160 ms) pour le survol et les coches, `dur-base` (260 ms) pour les puces, les segments et le fondu entre écrans, `dur-slow` (420 ms) pour les cartes et les feuilles, `dur-celebrate` (900 ms) pour l'éclat ; pour l'ambiance, `dur-sun-turn` (4 s) et `dur-halo-drift` (22 et 26 s).

| Token | CSS | SwiftUI |
| --- | --- | --- |
| `ease-out` + `dur-fast` | `160ms cubic-bezier(0.2, 0.8, 0.2, 1)` | `.easeOut(duration: 0.16)` |
| `ease-out` + `dur-slow` | `420ms cubic-bezier(0.2, 0.8, 0.2, 1)` | `.smooth(duration: 0.42)` |
| `ease-in-out` + `dur-base` | `260ms cubic-bezier(0.65, 0, 0.35, 1)` | `.easeInOut(duration: 0.26)` |
| `ease-spring` + `dur-base` | `260ms cubic-bezier(0.34, 1.56, 0.64, 1)` | `.spring(response: 0.3, dampingFraction: 0.55)` |

Les moments animés : cocher une tâche (`TaskCheckbox`, `TaskRow` : rebond, coche tracée, éclat braise, rose et jaune, titre barré, « Fait »), la fin de pomodoro (`PomodoroDone`), le plan terminé (`NoticeBox` ton `success`), la pause (fond et anneau ensemble), le sélecteur (`Segmented`), l'appui sur une pilule ou un bouton du rail.

## Iconographie

- L'app utilise les SF Symbols d'Apple, au trait, en graisse Regular ou Medium, à 10 à 19 pt : `textSecondary` dans les puces, `textPrimary` dans les pilules, 19 dans le rail. Symboles en usage : `plus`, `sun.max`, `calendar`, `doc.text`, `list.bullet`, `chart.bar`, `gearshape`, `magnifyingglass`, `clock`, `tag`, `checkmark`, `nosign`, `exclamationmark.triangle`, `info.circle`, `folder`, `arrow.up`, `play.fill`.
- Les SF Symbols ne sont pas livrés ici : les aperçus les remplacent par des tracés simples au trait, en `currentColor`.
- Une icône double toujours une couleur d'état : soleil pour « Aujourd'hui », coche pour « Fait », interdit pour « Bloquée », triangle pour l'alerte.

## Logo

- `done-app-icon.svg` : carré arrondi blanc, réchauffé d'un halo braise en haut à droite et d'un halo rose en bas à gauche, comme la toile de l'app. Dessus, un anneau fin en encre (trait de 30 sur 824) ouvert sur 60°, et un point braise dans l'ouverture. Pour le Dock, le Finder et le bas du rail.
- `done-glyph.svg` : le même anneau fin et le même point, en une seule encre noire, pour la barre de menus en image « template ».
- Le trait reste fin : ne pas l'épaissir pour les petites tailles, c'est le point braise qui se lit à 16 px.
- Les logos précédents sont gardés pour mémoire dans les groupes Logos Jardin et Logos v5.

## Composants

Les composants sont en SwiftUI dans l'app ; leurs aperçus ici sont des rendus HTML et CSS (`components/bundle.css`, classes `d-…`), animés comme dans l'app.

- Écran : `ControlCenter` (Ma journée), `Rail`, `Greeting`, `DayTimeline`, `CaptureBar`, `SearchField`.
- Agir : `Button`, `IconButton`, `Stepper`, `Segmented`.
- Saisir : `Field`, `TaskCheckbox`.
- Puces : `StateChip`, `InfoChip`, `TagChip`, `PriorityChip`, `TagPill`.
- Regrouper : `Card`, `NoticeBox`, `NoteCard`.
- Listes : `NavItem`, `TaskRow`.
- Calendrier et pomodoro : `MeetingBlock`, `ProgressRing`, `ProgressBar`, `PomodoroDone`.

## En avance sur le code

- Ce design system décrit la direction Mymind ; `Done/Views/Theme.swift` (commit `fc5fd9f`) est encore en v5. Les noms des rôles existants n'ont pas changé ; s'ajoutent `accent`, `onAccent`, `accentTint`, `accentText`, `success`, `successTint`, `successText`, `tagPink`, `tagYellow`, les quatre teintes de cartes et les deux halos.
- À construire dans l'app : l'écran Ma journée (qui remplace Focus, Aujourd'hui et Plan du jour comme écran d'arrivée), le rail, la barre de saisie, la recherche ⌘K, la mosaïque de notes, et l'écran Listes qui accueille projets et étiquettes.
- Polices à embarquer en TTF : Newsreader, Nunito Sans, Courier Prime et Oswald SemiBold (instances statiques dans `fonts/`).
- Une nouvelle synchronisation depuis GitHub remettrait les valeurs v5 : la faire seulement après le report dans `Theme.swift`.
