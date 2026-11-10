# Design system : Done v7 « Mymind »

Référence : `docs/design/mymind/design-system/`, avec `README.md`, `tokens.json` et, pour chaque composant, `components/<Nom>/README.md` et un aperçu HTML animé (`preview.html`, classes `d-…` de `components/bundle.css`). L'écran cible est rendu dans `docs/design/mymind/ma-journee-clair.png` et `ma-journee-sombre.png`. Le passage depuis la v6 est décrit dans `docs/design/mymind/HANDOFF.md`. Dans le code, tout passe par `Done/Views/Theme.swift`, plus `HomeComponents.swift` pour les pièces de l'écran Ma journée.

L'esprit : un tableau de bord calme et moderne, où la journée tient sur un seul écran. Une toile presque blanche, une encre graphite, des cartes qui flottent, une serif élégante pour les titres, la braise pour la marque et les réussites, le cobalt pour ce qui est actif. L'écran reste posé ; c'est le geste qui fait plaisir : cocher une tâche, finir un pomodoro, boucler le plan du jour.

## Principes

- Ma journée est l'écran d'accueil : prochaine action, ligne de temps, plan du jour, échéances, notes et focus du jour, dans six cartes widget. Les autres écrans (Calendrier, Notes, Listes, Stats) s'ouvrent depuis le rail ou le lien en haut à droite de chaque carte.
- Une seule chose forte par écran : le titre d'accueil en `displayXL`, puis la prochaine action en `displayL` ; en session, le minuteur en `numericXL`. Le reste est en `body`, `callout` ou `caption`.
- Un seul bouton principal (`actionPrimary`, pilule d'encre) par écran : « Lancer le focus » sur Ma journée.
- Tout ce qui se clique est une pilule (`DoneRadius.pill`). Les cartes sont de grands rectangles doux (`lg`, 24) avec un liseré et une ombre très légère (`shadowCard`).
- Calme au repos, joyeux à l'arrivée : la braise (`accent`) et le rebond sont réservés aux réussites et à la marque. Une vue qu'on regarde sans agir ne bouge pas.
- Pas de fond derrière les dates et les durées d'une ligne : `InfoChip` et `TagChip` restent du texte avec une icône. La pilule colorée (`TagPill`) est pour les cartes.
- Pas de capitales espacées. Les nombres sont en Nunito Sans, jamais en Newsreader ; seule exception, les chiffres du minuteur de session, en Oswald SemiBold.
- Le code ne cite jamais une couleur de marque ni une couleur système : seulement les rôles de `DoneColor`, les styles de texte et les composants.

## Contenu

- Interface en français, textes courts et directs, sans point d'exclamation. Verbes à l'infinitif sur les boutons : « Lancer le focus », « Capturer », « Découper… ».
- Le titre d'accueil dit la journée en une phrase de faits : « Bonjour Camille, trois tâches et deux réunions aujourd'hui. » Nombres en lettres jusqu'à dix. Pas de « Bravo », pas de « Super ».
- La salutation, à la manière de Claude, dépend de la situation (congé, retour, deuxième ouverture, plan bouclé), du jour (lundi matin, vendredi, week-end) et du moment (très tôt, matin, midi, après-midi, fin de journée, soir, nuit) : « Salut Adnan, », « Un café d'abord ? », « Deuxième mi-temps. », « Il se fait tard, Adnan. ». Le prénom n'est pas partout. Après un point ou une question, la phrase de faits prend une majuscule. La formule reste la même tout un moment de la journée, et jamais celle de la veille (`DayGreeting`).
- Casse de phrase partout : « Plan du jour », « Échéances et retards », « Toutes les notes ».
- Formats : « 1 h 30 », « 45 min », « 14:00 », minuteur « 18:42 », date courte « mar. 3 nov. », dates relatives « Auj. », « Demain », « Hier » (`Format.chipDate`), rang « 1er », « 2e » (`Format.ordinal`).
- Les textes d'aide donnent un vrai exemple : « Appeler le transporteur demain P2 ».
- Pas d'emoji : le soleil est une icône, pas un caractère.

## Couleurs

La marque tient en cinq couleurs, qui n'apparaissent jamais sous leur nom dans le code : Toile #F9FAFC, Encre #24272D, Braise #FF5924, Cobalt #1573DD, Rose des halos #F078A0. Le code passe par des rôles (`DoneColor`), qui changent de valeur entre clair et sombre. En sombre, la pilule principale s'inverse : fond clair, texte sombre.

| Rôle | Clair | Sombre | Usage |
|---|---|---|---|
| `bgCanvas` | #F9FAFC | #0F1012 | Fond de fenêtre, des feuilles, du panneau de la barre de menus |
| `haloWarm` / `haloPink` | braise à 22 % / rose à 20 % | braise à 12 % / rose à 10 % | Halos de la toile, en haut à droite et en bas à gauche (`DoneCanvas`) |
| `bgSunken` | #F1F3F7 | #0B0C0E | Rail, colonne des listes, pistes, pilules de genre, blocs de code, jour d'absence |
| `surfaceDefault` | #FFFFFF | #18191C | Cartes, champs, boutons secondaires, segment choisi |
| `surfaceHover` | #F3F5F9 | #202226 | Survol |
| `surfaceSelected` | #E5EAF2 | #232A36 | Navigation active, ligne choisie au clavier, genre choisi |
| `borderSubtle` | #E6E8EE | #2A2C31 | Liseré des cartes, séparateurs, traits d'heure |
| `borderDefault` | #D6DAE2 | #383B42 | Boutons secondaires, recherche, tuile vide |
| `borderControl` | #8B91A0 | #7D8494 | Champs et case à cocher (3:1) |
| `textPrimary` | #24272D | #EEF0F4 | Texte principal |
| `textSecondary` | #5D6575 | #A3A9B6 | Métadonnées, salutation en italique, dates et durées |
| `textDisabled` | #AFB5C1 | #4F5560 | Désactivé, réunion passée |
| `actionPrimary` (survol, appui) | #24272D (#3A3E46, #111316) | #EEF0F4 (#FFFFFF, #D5D8DE) | Bouton principal, case cochée, bouton du rail choisi, envoi de la barre de saisie |
| `actionOnPrimary` | #FFFFFF | #15171A | Texte et coche sur `actionPrimary` |
| `actionDisabled` | #ECEEF3 | #202226 | Bouton principal ou case désactivés |
| `focusRing` | #1573DD | #5AA2F0 | Focus, cible de dépôt, champ actif ; c'est aussi l'`AccentColor` de macOS |
| `accent` / `onAccent` | #FF5924 / #2B0F04 | #FF6A3D / #2B0F04 | Braise, en plein ou en forme seulement : « Capturer » du rail, pétales, pastilles de série, heure courante, soleil de Ma journée |
| `accentTint` / `accentText` | #FFECE4 / #B33A0C | #3A1D14 / #FF9B77 | « Aujourd'hui », encadré de réussite, focus fait, position dans le plan |
| `stateActive` / `stateOnActive` | #1573DD / #FFFFFF | #5AA2F0 / #0B1A2C | Plein actif : tuile du plan, barres |
| `stateActiveText` / `stateActiveTint` | #0F5BB5 / #E7F0FC | #91C2F7 / #16243A | P1, liens des cartes, liens [[Titre]], encadré d'information |
| `success` / `successTint` / `successText` | #3D8C4A / #E4EFDC / #2D6B33 | #6CC07A / #1B2B1D / #9FD6A5 | Puce « Fait » |
| `stateBlocked` / `stateOnBlocked` | #ECEEF3 / #24272D | #23262B / #EEF0F4 | Puce « Bloquée » |
| `stateWaiting` | #8B91A0 | #7D8494 | Pointillé : créneau libre, nouvelle note, emplacement libre |
| `stateRisk`, `stateRiskTint`, `stateRiskText` | #D2313C, #FDEAEA, #8F1A24 | #F0646B, #3A1B1E, #FCC4C7 | Alerte : échéance dépassée, erreur, toujours avec le triangle |
| `stateDone` / `stateOnDone` | #F1F3F7 / #5D6575 | #141518 / #A3A9B6 | Terminé, réunion passée |
| `tagPink`, `tagYellow` | #B8336A, #8A5D00 | #F08AB3, #F2C25C | Étiquettes des notes (Décision, Journal) et pétales |
| `cardBlush`, `cardSlate`, `cardSage`, `cardParchment` | #FFF1F1, #E5EAF2, #DDE9D3, #F3F0E7 | #251A1A, #1A1F29, #19221A, #1F1D18 | Teintes des cartes de note (Journal, Réunion, Personne, Référence et page de projet) |
| `meetingBg`, `meetingHatch` | #E5EAF2, cobalt à 14 % | #1C2230, cobalt à 16 % | Réunion à venir, hachurée |
| `meetingNow` / `meetingOnNow` | #24272D / #FFFFFF | #EEF0F4 / #15171A | Réunion en cours, en encre |
| `pomodoroFocus` | #F4511F | #FF6A3D | Barre du minuteur et anneaux de concentration, en braise |
| `pomodoroBreak` / `pomodoroBreakBg` | #1573DD / #EEF4FC | #5AA2F0 / #101A27 | Barre et fond de la pause, en cobalt |
| `pomodoroTrack` / `pomodoroPaused` | #E6E8EE / #AFB5C1 | #2A2C31 / #4F5560 | Piste des anneaux et des barres ; minuteur à l'arrêt |

Les rôles `sun`, `onSun`, `sunTint` et `sunText` de la v6 restent déclarés comme alias de la braise, pour ne renommer aucun rôle ; plus aucun composant ne s'en sert.

Règles :

- `accent` ne porte jamais de texte : il ne fait que 3,1:1 sur blanc. Pour du texte, `accentText` sur `accentTint`.
- La braise et l'alerte sont deux rouges-orangés : l'alerte est nettement plus sombre en clair et plus claire en sombre, n'est jamais sur un bouton, et porte toujours son triangle. Une icône double toujours la couleur (soleil pour « Aujourd'hui », coche pour « Fait », interdit pour « Bloquée », triangle pour l'alerte).
- Toutes les paires texte et fond passent AA dans les deux thèmes, teintes de cartes comprises : `textSecondary` sur `bgCanvas` 5,61:1 en clair et 8,07:1 en sombre, `actionOnPrimary` sur `actionPrimary` 14,97:1 et 15,74:1, `accentText` sur `accentTint` 5,21:1 et 7,47:1, `stateOnActive` sur `stateActive` 4,64:1 et 6,56:1. `borderControl`, `focusRing`, `accent` et les anneaux passent 3:1. Ne pas « corriger » une couleur sans recalculer ces ratios.

## Typographie

Quatre familles sous licence OFL (licences dans `docs/fonts/`), embarquées en TTF statiques dans `Done/Fonts` et chargées au lancement par `FontLoader` :

- **Newsreader**, Medium, pour les titres : `NewsreaderDisplay-Medium` pour `displayXL` et `displayL`, `NewsreaderText-Medium` pour `displayM` et `noteTitle`. L'italique (`NewsreaderDisplay-MediumItalic`, `Font.doneItalic`) sert à la salutation de Ma journée. Newsreader ne descend jamais sous `noteTitle` (17) et ne sert jamais aux nombres.
- **Nunito Sans** pour l'interface : Regular pour le texte, SemiBold pour les libellés et les titres de tâche, Bold pour `title`, `label` et la navigation active, Light pour les grands chiffres. Ses chiffres sont à chasse fixe ; les styles `numeric…` ajoutent `monospacedDigit` pour le garantir.
- **Courier Prime**, pour `noteMono` seulement : le corps du journal et des notes simples dans la mosaïque, comme un brouillon tapé à la machine.
- **Oswald SemiBold** (`Oswald-SemiBold`, `Font.timer`), pour les chiffres du minuteur de session seulement (`FocusTimer`) : des chiffres étroits et gras qui se lisent de loin. Nulle part ailleurs.

Dans le code, `.doneText(.style)` applique la police, l'interlignage et l'interlettrage. `Font.sans(taille, graisse)` sert hors échelle (boutons, puces, navigation), avec `.monospacedDigit()` pour un nombre isolé. Nunito Sans n'a pas de Medium : `.medium` donne SemiBold.

| Style | Police | Taille / interligne | Usage |
|---|---|---|---|
| `displayXL` | Newsreader Display Medium, -0,02 em | 46/50 | Titre d'accueil de Ma journée, action en session |
| `displayL` | Newsreader Display Medium, -0,015 em | 32/38 | Prochaine action, titres d'écran |
| `displayM` | Newsreader Text Medium, -0,01 em | 22/28 | Titres de feuille, états de la carte Prochaine action, note ouverte, colonne des listes |
| `noteTitle` | Newsreader Text Medium | 17/22 | Titre d'une carte de note |
| `title` | Nunito Sans Bold | 16/22 | Titre de panneau, tâche parente |
| `body` / `bodyStrong` | Nunito Sans Regular / SemiBold | 14/20 | Texte courant / titre de tâche |
| `callout` | Nunito Sans Regular | 13/18 | Texte d'appoint, encadrés, extraits de note |
| `caption` | Nunito Sans Regular | 12/16 | Métadonnées |
| `label` | Nunito Sans Bold, casse normale | 12/16 | Étiquettes de section et en-têtes de carte (`Eyebrow`) |
| `numericXL` | Nunito Sans Light, -0,02 em | 60/64 | Minuteur, total de la semaine |
| `numericL` | Nunito Sans Light, -0,02 em | 44/48 | Grand chiffre d'une carte (focus du jour) |
| `numericM` / `numericS` | Nunito Sans SemiBold | 14/20, 12/16 | Valeurs en ligne / dates, durées, heures, compteurs |
| `noteMono` | Courier Prime Regular | 13/19 | Corps du journal et des notes simples, dans la mosaïque |

## Mesures

- **Espacements** (`DoneSpace`) : grille de 4, avec 2 et 6 pour les détails. 12 dans une ligne, 16 entre les cartes, 22 × 20 dans une carte widget, 36 × 30 autour de Ma journée.
- **Rayons** (`DoneRadius`) :
  - `xs` 6 : case à cocher, tuile numérotée, barres de la semaine ;
  - `sm` 12 : champs, réunions et blocs de la ligne de temps, créneaux libres ;
  - `md` 18 : lignes de tâche, cartes de note, encadrés, cartes à plat des feuilles, résultats de recherche ;
  - `lg` 24 : cartes widget, feuilles, carte de fin de pomodoro ;
  - `pill` (et `chip`, son alias) : tout ce qui se clique, puces, étiquettes, recherche, barre de saisie, boutons du rail.
- **Contours** : 1 en `borderSubtle` (cartes), `borderDefault` (pilules secondaires, recherche) ou `borderControl` (champs) ; 1,5 pour la case à cocher et le pointillé `stateWaiting` ; 2 en `focusRing` (focus, cible de dépôt, champ actif) ; 6 pour les anneaux, fins comme le logo.
- **Hauteurs fixes** : contrôle 34, contrôle compact 28, puce 22, case à cocher 18, tuile 24, segment 26, recherche 38, ligne de tâche 48, barre de saisie 54. Rail de 84 avec des boutons de 44, colonne des listes de 240, minuteur de 142 sur une règle de 1000 au plus, anneau de la carte Prochaine action de 86, retrait d'une étape de 28 par niveau.
- **Ombres**, teintées de l'encre en clair, noires en sombre :
  - `shadowCard` et `shadowCardNear` (0 10 30 à 6 %, plus 0 1 2 à 5 % ; 30 % et 40 % en sombre) : cartes widget (`doneCard`), barre de saisie, boutons du rail ;
  - `shadowRaised` et `shadowRaisedNear` (0 20 50 à 14 %, plus 0 4 10 à 6 % ; 55 % et 35 % en sombre) : `doneRaised`, la carte de fin de pomodoro, et le rail qui passe par-dessus une session ;
  - `shadowControl` (0 1 2 à 10 % ; 45 % en sombre) : segment choisi du sélecteur.

## Mouvement

Le mouvement dit « c'est fait » ; il ne décore pas.

- Ce qui arrive ralentit en se posant (ease-out). Ce qui se déplace accélère puis freine (ease-in-out). Seules les réussites rebondissent (ease-spring), et une seule fois.
- Rien ne bouge sans action de la personne, sauf le minuteur (sa barre, la lueur de la dernière minute, le clignotement en pause), l'heure courante et deux mouvements d'ambiance très lents, purement cosmétiques : les halos de la toile qui dérivent (hors session, fenêtre au premier plan) et le soleil de la date qui fait un tour à l'ouverture de Ma journée. Maquette validée : `docs/design/mymind/maquettes/ambiance-ma-journee.html`.
- Avec « Réduire les animations » (macOS), il ne reste que des fondus : pas d'échelle, de rebond ni d'éclat. Chaque vue animée lit `accessibilityReduceMotion` ; `DoneMotion.motion(_:reduced:)` remplace un mouvement par `DoneMotion.fade`.

`DoneMotion` reprend les tokens de durée et de courbe, avec les équivalents SwiftUI de la référence :

| Token | `DoneMotion` | SwiftUI | Usage |
|---|---|---|---|
| ease-out, `dur-instant` (90 ms) | `press` | `.easeOut(duration: 0.09)` | Appui : bouton à 0,97, bouton rond à 0,94, case à 0,88 |
| ease-out, `dur-fast` (160 ms) | `hover`, `fade` | `.easeOut(duration: 0.16)` | Survol, coche, couleur d'état ; fondu de repli |
| ease-out, `dur-base` (260 ms) | `appear` | `.easeOut(duration: 0.26)` | Encadré, résultats de recherche, confirmation de la barre de saisie, trait du titre barré |
| ease-in-out, `dur-base` | `move` | `.easeInOut(duration: 0.26)` | Segment choisi, section repliable, rail |
| ease-spring, `dur-base` | `pop` | `.spring(response: 0.3, dampingFraction: 0.55)` | Case cochée, puce « Fait », pastille de série |
| ease-out, `dur-slow` (420 ms) | `arrive` | `.smooth(duration: 0.42)` | Carte, feuille, fond de la pause |
| ease-in-out, `dur-slow` | `travel` | `.easeInOut(duration: 0.42)` | Ligne qui quitte sa liste |
| ease-out, `dur-celebrate` (900 ms) | `burst` | `.easeOut(duration: 0.9)` | Éclat des réussites |
| ease-out, `dur-base` | `screen` | `.easeOut(duration: 0.26)` | Fondu léger quand on change d'écran (gardé avec « Réduire les animations ») |
| ease-out, `dur-sun-turn` (4 s, après 0,3 s) | `sunTurn` | `.timingCurve(0.2, 0.8, 0.2, 1, duration: 4)` | Le soleil de la date fait un tour à l'ouverture de Ma journée |
| `dur-halo-drift` (22 s et 26 s) | `haloDriftWarm`, `haloDriftPink` | `keyframeAnimator`, quatre `CubicKeyframe` | Chaque halo trace une petite ellipse (20 à 30 points, échelle de 1 à 1,07), en contretemps |

Pièces communes, dans `Theme.swift` : `donePress` (appui, et `DonePressStyle` pour la case), `doneArrive` (fondu à l'apparition, avec une montée de 12 pour une carte), `CheckMarkShape` (coche à tracer avec `.trim`), `SunBurst` (halo `accentTint` et huit pétales braise, rose et jaune qui partent une fois chaque fois que son compteur augmente).

Les moments animés :

- **Cocher une tâche** : la case se tasse, rebondit et sa coche se trace ; huit pétales partent ; le titre se barre de gauche à droite ; « Fait » remplace les puces en rebondissant ; une seconde plus tard, la ligne quitte sa liste en glissant vers le bas. Rouvrir ne rejoue rien.
- **Fin de pomodoro** : la carte monte de 12 et apparaît ; l'anneau se referme ; la coche se trace et l'éclat part ; la pastille du pomodoro qui vient de finir rebondit.
- **Plan du jour bouclé** : la barre du plan se remplit (`arrive`) et un petit éclat part de son bout ; l'encadré de réussite arrive en fondu ; le soleil de Ma journée dans le rail fait un seul éclat.
- **Changer d'écran** : l'écran quitté s'efface pendant que le nouveau apparaît, en fondu léger (`screen`).
- **Ambiance** : halos en dérive lente et tour du soleil de la date, immobiles avec « Réduire les animations », pendant une session et quand la fenêtre n'est pas au premier plan (halos).
- **Pause** : le fond passe à `pomodoroBreakBg`, les halos s'effacent et la vue de pause arrive, ensemble, en `dur-slow`.
- **Sélecteur** : le segment choisi glisse vers la nouvelle option.
- **Pilules et boutons du rail** : ils se tassent à l'appui ; le survol change le fond en `dur-fast`.

## Iconographie

- SF Symbols, au trait, en graisse Regular ou Medium, de 10 à 19 pt : `textSecondary` dans les puces, `textPrimary` dans les pilules, 19 dans le rail. Symboles en usage : `plus`, `sun.max`, `calendar`, `doc.text`, `list.bullet`, `chart.bar`, `gearshape`, `magnifyingglass`, `clock`, `tag`, `checkmark`, `checkmark.square`, `nosign`, `exclamationmark.triangle`, `info.circle`, `folder`, `tray`, `arrow.up`, `arrow.clockwise`, `play.fill`, `ellipsis`, `chevron.down`, `chevron.right`, `chevron.left`.
- `sun.max` est le signe de la journée : bouton Ma journée du rail, ligne de date de la salutation (en braise), puce « Aujourd'hui », encadré de réussite.
- La coche animée est un tracé (`CheckMarkShape`), pour pouvoir se dessiner ; la coche des puces reste le symbole `checkmark`.

## Composants

### Agir et saisir (`Theme.swift`)

- **Boutons** (`DoneButtonStyle`) : pilule de 34, marge 16, texte 14 SemiBold. Principal en `actionPrimary` (un seul par vue), secondaire sur surface avec contour `borderDefault`, discret en texte seul (marge 10). Variante `compact` de 28, marge 12, texte 13.
- **Bouton à icône** (`DoneIconButtonStyle`) : rond de 34, icône de 14, contour `borderDefault`, appui à 0,94.
- **Stepper** (`DoneStepper`) : « − » et « + » en boutons compacts.
- **Sélecteur** (`DoneSegmented`) : piste `bgSunken` en pilule, marge 3 ; segment de 26 en pilule sur `surfaceDefault` avec `shadowControl`, qui glisse d'une option à l'autre (`matchedGeometryEffect`).
- **Champ** (`doneField`) : hauteur 34 (36 pour l'ajout des listes), rayon `sm`, marge 12, contour `borderControl` ; contour `focusRing` de 2 au focus.
- **Case à cocher** (`TaskCheckbox`) : carré de 18, rayon `xs`, contour 1,5 en `borderControl`. La coche apparaît en filigrane au survol ; cochée, plein `actionPrimary` et coche `actionOnPrimary`. Avec `bursts`, l'éclat accompagne la coche. Sert aussi aux cases des notes Markdown.

### Puces et étiquettes

- **`StateChip`** : pilule de 22, marge 8, icône 10, texte 12 SemiBold, jamais de contour.
  - `active`, « Aujourd'hui » : soleil, `accentText` sur `accentTint` ;
  - `doneToday`, « Fait » : coche, `successText` sur `successTint`, pour une tâche qu'on vient de cocher ;
  - `blocked`, « Bloquée » : interdit, sur `stateBlocked` ;
  - `risk` : triangle, sur `stateRiskTint` ;
  - `done` : coche et texte `stateOnDone` sans fond, pour ce qui a été fait un autre jour.
- **`InfoChip`** : date (calendrier), durée (horloge) ou répétition (`arrow.clockwise`, « Chaque lundi »), icône et texte secondaires sans fond ; en texte d'alerte une fois l'échéance dépassée.
- **`PriorityChip`** : P1 SemiBold sur teinte active ; P2 en texte actif seul ; rien pour P3 et P4.
- **`TagChip`** : icône `tag` et nom en texte secondaire, sans fond, dans les lignes de tâche. Dans la vue d'une étiquette, celle-ci n'est pas répétée.
- **`TagPill`** : pilule de 22 à contour coloré, marge 10, 12 SemiBold, texte et contour de la même couleur sur fond transparent. Le type d'une note (`NoteKind.tagColor`), ou une étiquette dans une carte (`textSecondary`).
- **Éditeur d'étiquettes** (`TagEditor`, dans la carte des détails) : jetons sur teinte active avec une croix, un champ « Ajouter » et le menu des étiquettes existantes. Absent pour une étape.

### Regrouper

- **Cartes** : `doneCard` (surface, liseré `borderSubtle`, rayon `lg`, `shadowCard`) ; `doneCard(flat: true)` sans ombre, dans une feuille ou une autre carte, souvent en rayon `md` ; `doneRaised` (rayon `lg`, `shadowRaised`) pour la carte de fin de pomodoro seulement.
- **Carte widget** (`WidgetCard`, `HomeView.swift`) : `doneCard` avec des marges de 22 × 20 ; en tête, l'`Eyebrow` à gauche (avec un accessoire éventuel, comme la position dans le plan) et un lien en `stateActiveText` 12 SemiBold à droite, qui ouvre l'écran complet.
- **Encadré** (`NoticeBox`) : sans contour, rayon `md`, marges 14 × 10, texte `callout`, icône de 11 ; arrive en fondu.
  - `info` : « i », `stateActiveText` sur `stateActiveTint` ;
  - `success` : soleil, `accentText` sur `accentTint`, pour le plan du jour terminé ;
  - `error` : triangle, `stateRiskText` sur `stateRiskTint`.
- **Carte de note** (`NoteCard`, `NoteViews.swift`) : rayon `md`, marges 16 × 14. `TagPill` du type, titre en `noteTitle`, extrait sur trois lignes (`callout` secondaire, ou `noteMono` en `textPrimary` pour le journal et les notes simples), jusqu'à trois cases cliquables (de 14). Teinte selon le type : Journal `cardBlush` (étiquette `tagYellow`), Réunion `cardSlate` (`stateActiveText`), Personne `cardSage` (`successText`), Référence et page de projet `cardParchment` (`textSecondary`), Note (`accentText`) et Décision (`tagPink`) sur `surfaceDefault` avec un liseré. La tuile « Nouvelle note… » (`NewNoteTile`) est en pointillé `stateWaiting`.
- **Mosaïque** (`MasonryLayout`) : chaque carte dans la colonne la plus courte, écart de 10 ; quatre colonnes au plus dans l'écran Notes (220 de large au moins), deux dans Ma journée.
- **Toile** (`DoneCanvas`) : `bgCanvas` et les deux halos en dégradé radial (`haloWarm` centré à 210 du bord droit et 30 sous le haut, `haloPink` à 190 du bord gauche et 110 sous le bas), qui dérivent lentement hors session (`drifts`). Pendant la pause, `pomodoroBreakBg`, sans halos.

### Listes et lignes

- **Ligne de tâche** : hauteur 48, rayon `md`.
  - Au survol, `surfaceHover` ; au clavier, la ligne choisie passe en `surfaceSelected`.
  - Titre (`TaskTitle`) en `bodyStrong` sur deux lignes au plus, métadonnées en `caption` : liste, puis « N étapes ».
  - Puces à droite (`TaskChips`), espacées de 12 : priorité, « Aujourd'hui » ou « Bloquée », étiquettes, échéance, répétition, durée.
  - Dans les cartes de Ma journée (Plan du jour, Échéances et retards), la ligne a deux étages (`TaskRowContent(stacked: true)`) : le titre sur toute la largeur, puis la liste et les puces, qui passent à la ligne si la place manque (`FlowLayout`, écarts de 12 et 4). La case et la tuile restent sur la première ligne du titre ; marges de 12 × 8. Les puces ne poussent jamais le titre ni la carte.
  - Étapes en retrait de 28 par niveau.
  - Cocher passe par `AppModel.completeSoon` : la tâche reste ouverte une seconde, le temps de l'animation, puis elle est cochée. Recliquer pendant cette seconde annule ; quitter Done enregistre aussitôt les coches en attente. `TaskRowTrailing` remplace les puces par « Fait ».
- **Tuile numérotée** (`NumberTile`) : 24, rayon `xs`. Pleine `stateActive` pour une place dans le plan, en contour `borderDefault` pour un emplacement libre.
- **Raccourcis** (`KeyCap`, `ShortcutHint`, `ListShortcutHints`) : les touches en texte seul, 12 SemiBold à 60 % de la couleur qui les entoure, comme le « ⌘K » de la recherche ; le verbe suit en `caption` secondaire. À droite du titre d'une liste : « ↑ ↓ Choisir », « Espace Cocher », « ↩ Ouvrir », « ⌘ ↑ ↓ Déplacer ».
- **Élément de liste** (`NavItem`) : pilule de 34, marge 12, icône 16, compteur `numericS` à droite. Actif en `surfaceSelected` et en Bold ; cible de dépôt avec un contour `focusRing` de 2. Ne sert plus qu'à la colonne de l'écran Listes.

### Calendrier et pomodoro

- **Bloc réunion** (`MeetingBlock`, `Hatching`) : rayon `sm`. Hachuré à venir (traits de 1,5 à 45° tous les 6), plein `meetingNow` en cours, `stateDone` une fois passé. Moins de 30 min : titre et créneau sur une ligne (`singleLine`). La pastille de réunion de la session (`MeetingPill`) suit les mêmes règles.
- **Ligne de temps** (`DayTimeline`, `HourLabels`, `DayTimeline.swift`) : plage horaire en paramètre (de 8 h à 19 h par défaut). Réunions et blocs de travail se glissent (heure, et jour au calendrier) et s'étirent par leur bord bas (curseur de redimensionnement), au quart d'heure ; pendant le geste, l'élément suit avec un contour `focusRing` de 2, `shadowRaised` et le créneau visé, et pâlit si le geste vise le passé. Une tâche déposée sur la grille y prend un bloc ; la grille survolée passe en `stateActiveTint`. Focus fait en `accentTint`, titre en `accentText` ; heure courante en braise, un point de 8 et un trait de 2, avec l'heure en `accentText` dans la gouttière (`HourLabels(now:)`). Créneaux libres de 30 min ou plus (`showsFreeSlots`) en pointillé `stateWaiting`, avec « 2 pomodoros possibles » ; cliquables avec `onFreeSlot`.
- **Bloc de travail** (`WorkBlockView`) : rayon `sm`, `stateActiveTint` avec un filet `stateActive` de 3 à gauche, le titre de la tâche précédé de `checkmark.square` et le créneau en `stateActiveText` ; une tâche faite passe en `stateDone`, barrée. La fiche (`WorkBlockSheet`) reprend celle d'une réunion : tâche en `displayM`, jour et horaire, « Retirer le bloc », « Ouvrir la tâche », « Lancer le pomodoro », « Enregistrer ».
- **Réunion récurrente** : une flèche `arrow.clockwise` devant le titre de chaque occurrence ; la fiche affiche « Réunion · Chaque lundi » et une ligne « Répétition » (`RecurrenceMenu`).
- **Anneau et barre** : `ProgressRing` (voir Pomodoro) ; `ProgressBar`, hauteur 6, en capsule, plein `stateActive` sur `pomodoroTrack`.

### Écran Ma journée (`HomeComponents.swift`)

- **Salutation** (`Greeting`) : ligne de date (soleil braise, jour, date et semaine en 13 SemiBold secondaire), puis le titre en `displayXL` : la salutation en italique `textSecondary`, le résumé en `textPrimary`. Deux lignes au plus, 820 de large au plus. La formule et la phrase viennent de `DaySummary` (Core).
- **Recherche** (`SearchField`, `GlobalSearchBox`) : pilule de 38, 260 de large, contour `borderDefault` (`focusRing` de 2 au focus), loupe de 15, « ⌘K » à droite. Les résultats s'ouvrent dessous dans une carte de 380 (rayon `md`), groupés par Tâches, Notes, Réunions, cinq au plus par groupe ; la ligne choisie en `surfaceSelected`. La recherche est `GlobalSearch` (Core).
- **Barre de saisie** (`CaptureBar`, `HomeCaptureBar`) : pilule de 54 sur `surfaceDefault`, liseré et `shadowCard`. À gauche un + et le texte ; à droite les genres (Tâche, Note, Réunion) en pilules de 38 avec leur icône (`surfaceSelected` pour le genre choisi, `bgSunken` pour les autres) et l'envoi, rond de 38 en `actionPrimary`. Après un ajout, la puce « Ajoutée dans Inbox » reste 2 s au-dessus.
- **Rail** (`Rail`, `RailDestination`) : 84 de large, sur `bgSunken` à 70 % avec flou (`ultraThinMaterial`), trait `borderSubtle` à droite. Boutons ronds de 44, espacés de 10, icônes de 19 : « Capturer » en braise, puis Ma journée, Calendrier, Notes, Listes et Stats ; en bas, Réglages et le logo. L'écran affiché est plein `actionPrimary`, les autres sur `surfaceDefault` avec `shadowCard`. Listes porte une pastille braise avec le nombre de tâches de l'Inbox. Pendant une session qui tourne ailleurs, le minuteur remplace le logo. Chaque bouton dit son nom et son raccourci au survol.

Le rail, la salutation et la barre de saisie ont des aperçus Xcode (`#Preview`) dans `HomeComponents.swift`.

## Ma journée

`HomeView` (⌘1), l'écran d'arrivée. Sur la toile et ses halos :

- **En-tête** : la salutation à gauche ; la recherche et « Capturer » (pilule secondaire avec « ⌘N ») à droite.
- **Grille** : six cartes widget en trois colonnes (1,25 / 1 / 1), deux rangées qui se partagent la hauteur, écart de 16. Sous 1 150 de large utile, deux colonnes de 300 de haut qui défilent, la carte Notes en dernier.
  1. **Prochaine action** : la position dans le plan (« • Tâche 1 sur 3 » en `accentText` sur `accentTint`), l'étape en `displayL`, sa tâche (« étape 2 sur 5 »), ses puces, la note de reprise, un anneau de 86 en braise avec la durée (un clic en propose une autre), « Lancer le focus », « Découper… », un menu « … » (Changer de tâche, Passer) et le temps libre avant la prochaine réunion. Selon la journée : bilan du soir (à l'heure du réglage, avec « Plus tard »), jour de congé avec « Travailler quand même », pas de plan, plan terminé, plan bloqué, pas le temps avant une réunion, pause due.
  2. **Ma journée** : la ligne de temps, de l'heure courante moins une jusqu'à 19:00, à 40 par heure, avec les créneaux libres ; un clic sur un créneau libre lance la prochaine action, ailleurs il propose une réunion. Lien « Calendrier ».
  3. **Plan du jour** : barre d'avancement suivie du compte (« 1 sur 3 » en `numericS` secondaire), tâches faites en haut (barrées, « Fait »), puis les tâches ouvertes avec case et tuile numérotée. Une tâche glissée depuis les échéances (ou une liste) rejoint le plan. Lien « Modifier » (ou « Choisir ») vers le Plan du jour, en feuille.
  4. **Échéances et retards** : ce qui tombe aujourd'hui ou est en retard, hors plan. Lien « Tout voir » vers le Calendrier.
  5. **Notes** : la mosaïque à deux colonnes, le journal du jour en premier (ou « Journal du jour… »), puis les notes récentes et « Nouvelle note… ». Lien « Toutes les notes ».
  6. **Focus aujourd'hui** : le temps de focus en `numericL`, les pastilles de série en braise et « 3e pomodoro », les tâches cochées, l'Inbox à trier, les barres de la semaine (aujourd'hui en `stateActive`, les autres en `stateActiveTint`). Lien « Stats ».
- **Barre de saisie** en bas.
- **Clavier** : ↑ ↓ parcourent le plan puis les échéances, Espace coche, ↩ ouvre la fiche. À l'ouverture, aucune ligne n'est choisie : la première flèche choisit la première (↓) ou la dernière (↑), comme dans les listes.

## Listes

`ListsView` (⌘4) : la colonne des listes, 240 sur `bgSunken`, titre « Listes » en `displayM`, puis l'Inbox, la section « Projets » (chaque projet suivi de ses sous-projets en retrait de 16, repliables par un chevron, puis « Nouveau projet ») et la section « Étiquettes ». Chaque section se replie d'un clic sur son titre, et Done s'en souvient. Chaque entrée porte son nombre de tâches ouvertes. Clic droit pour renommer, réordonner, ranger ou supprimer ; on y glisse une tâche pour la ranger. À droite, la liste choisie (`TaskListView`).

La vue d'un projet montre d'abord ses propres tâches, puis un groupe par sous-projet : titre en `title` avec l'icône `folder` et le nombre de tâches (un clic ouvre le sous-projet), puis la carte de ses lignes.

## Notes

- **Écran** : titre « Notes » en `displayL`, champ de recherche, filtre « Type : … » et « Nouvelle » en haut ; dessous, la mosaïque des cartes de note, fermée par « Nouvelle note… ». Une note ouverte prend toute la largeur, avec « Toutes les notes » pour revenir.
- **Note** : puce du type, « Modifiée … » en `caption`, titre en `displayM` sans contour, carte des rattachements (`DetailRow`, à plat), puis le contenu. Aperçu (`MarkdownView`) : titres en `displayM`, `title` et `bodyStrong` ; texte en `body` ; cases `TaskCheckbox` ; citations avec un filet de 3 en `borderDefault` ; code sur `bgSunken` ; liens [[Titre]] en texte actif. Édition : `TextEditor` en `body`, contour `focusRing` de 2.
- **Ailleurs** : carte « Documentation » en haut de la vue d'un projet ; carte Notes de Ma journée ; « Prendre des notes » dans la fiche d'une réunion ; liste « Notes » dans la fiche d'une tâche. Une note ouverte ailleurs que dans l'écran Notes s'affiche dans une feuille (`NoteSheet`, 760 × 680) avec « Retour » quand on suit un lien.

## Calendrier

- **Colonnes** : une par jour, du lundi au vendredi, séparées par un trait `borderSubtle`, après une gouttière pour les heures (`numericS`, texte secondaire ; l'heure courante en `accentText` dans la semaine en cours).
- **En-tête de jour** : le jour (texte actif pour aujourd'hui), puis une ligne `caption` : l'absence (icône `sun.max`), sinon le focus du jour, sinon « Aujourd'hui ». Menu « … » discret à droite, et le même menu au clic droit.
- **Échéances** : une petite carte par tâche (`PriorityChip` et titre en `callout`), en texte d'alerte quand elle est en retard. Le jour survolé pendant un glisser-déposer prend la teinte active.
- **Grille** : de 8 h à 19 h, étirée sur toute la hauteur, avec au moins 44 par heure (en dessous, elle défile). Un clic sur un créneau propose « Nouvelle réunion » ou « Bloquer pour une tâche… ». Réunions en `MeetingBlock`, blocs en `WorkBlockView` ; focus passé en `accentTint` ; deux événements qui se chevauchent se partagent la largeur ; heure courante en braise, jamais en couleur d'alerte. Jour d'absence : fond `bgSunken`.

## Navigation

- **Rail** à gauche de la fenêtre, sous les feux. Raccourcis : ⌘1 Ma journée, ⌘2 Calendrier, ⌘3 Notes, ⌘4 Listes (la dernière ouverte), ⌘5 Stats, ⌘, Réglages, ⌘N saisie complète, ⌘K recherche (depuis un autre écran, ⌘K ramène à Ma journée).
- **Session** : lancer le focus fait passer Ma journée en plein écran (minuteur, interruption, fin de session, pause), sans rail ; le rail revient par-dessus, avec son ombre, quand la souris touche le bord gauche. Si l'on change d'écran pendant une session, elle continue : le minuteur s'affiche en bas du rail, et un clic dessus (ou ⌘1) ramène à la session. Une réunion en cours s'affiche en haut de l'écran de session pendant une interruption.
- Le minuteur reste aussi dans la barre de menus, même fenêtre fermée.

## Pomodoro

- **Minuteur** (`FocusTimer`, maquette validée : `docs/design/mymind/maquettes/minuteur-de-focus.html`, piste C « Grands chiffres ») :
  - Le temps restant en Oswald SemiBold de 142 (`Font.timer`), minutes sur deux chiffres (« 08:42 »), sur une ligne de 142. Chaque chiffre dans une case de 0,503 em (le chiffre le plus large moins 0,04 em), les deux-points dans une case de 0,251 em : les chiffres sont serrés et ne bougent pas d'une seconde à l'autre. `textPrimary`, `textSecondary` à l'arrêt.
  - À 22 dessous, une règle de 1000 au plus (seule sa longueur suit la place), de 0 à gauche à la durée de la session à droite : une graduation par minute (2 × 11 en `textSecondary` toutes les 5 min, 1,2 × 6 en `textDisabled` sinon, à 18 sous le haut de la règle), un chiffre toutes les 5 min (toutes les 10 au-delà de 30 min) en Nunito Sans SemiBold 12 secondaire, sans unité ; le premier calé à gauche, le dernier à droite.
  - Sur la piste `pomodoroTrack` de 11, une barre ancrée à gauche dont le bout avance vers 0 et pointe les minutes qui restent ; elle glisse d'une seconde à l'autre (`DoneMotion.tick`).
  - En concentration : `pomodoroFocus`, en braise. Dans la dernière minute, une lueur `accentTint` de 21 de haut va et vient sous la barre (`timerGlow`, de 0,35 à 0,9).
  - À l'arrêt : `pomodoroPaused`, « En pause » dessous, et les chiffres clignotent lentement (`timerBlink`, de 1 à 0,35).
  - En pause : l'écran passe sur `pomodoroBreakBg` et la barre en `pomodoroBreak`, cobalt (lueur `stateActiveTint`), avec « de pause, sur 5 min ».
  - Dessous, à 22, « sur 25 min » en Nunito Sans Bold 14 secondaire.
  - Avec « Réduire les animations », ni lueur qui bouge (elle reste à 0,6) ni clignotement.
  - Aucune couleur d'alerte, même à la fin.
- **Fin de pomodoro** (`OutcomeView`, composant `PomodoroDone` de la référence) : carte surélevée de 520 (`doneRaised`), le seul élément surélevé de Done.
  - Anneau de 56 au trait de 6 en `pomodoroFocus` qui se referme, puis une coche qui se trace au centre et l'éclat.
  - « Pomodoro terminé » (ou le titre de l'étape cochée en avance) en `displayM`, la durée et la tâche en `callout` secondaire.
  - Pour un pomodoro terminé, la série du jour : une pastille `accent` de 10 par pomodoro fait (8 au plus), une pastille vide pour le prochain, et « 3e pomodoro aujourd'hui » en `accentText`. Un pomodoro est un minuteur mené au bout, rallonges comprises (`Stats.pomodoros`).
  - Les actions de Done : « Cocher la tâche » en principal, « Encore 5 min » et « Pause, puis je reprends » en secondaire, « Bloqué… » et « Arrêter là » en discret.
- **Barre de menus** : image « template » du système. Au repos, le glyphe de Done, ou `sun.max` une fois le plan du jour bouclé, monochrome comme toutes les icônes de la barre. En concentration, un mini-anneau de 16 et le temps restant ; à l'arrêt et en pause, les icônes pause et tasse ; à la fin, l'anneau plein et « Fini ».
- **Panneau de la barre de menus** (`MenuBarView`, maquette validée : `docs/design/mymind/maquettes/panneau-barre-de-menus.html`) : 320 de large, sur `bgCanvas` avec les deux halos en plus petit et plus discrets, marges 16 × 14, écart de 14.
  - La date, comme sur Ma journée : soleil braise et « Lundi 9 novembre · semaine 46 » en Nunito Sans SemiBold 12 secondaire.
  - La capture en pilule de 40 sur `surfaceDefault`, liseré et `shadowCard` (contour `focusRing` de 2 au focus) : un +, le champ, l'envoi rond de 28 en `actionPrimary`. Dessous, « Dans : Inbox » et « Détails… », et « Ajoutée dans … » (`StateChip` « Fait ») après un ajout.
  - Une carte d'état (`PanelCard` : surface, liseré, rayon `md`, marges 16 × 14) : au repos, la prochaine action en `displayM` avec sa position (puce braise) ou la fin du bloc en cours (puce cobalt), sa ligne de contexte, durée et priorité, « Lancer le focus » (ou la pause due d'abord) et la réunion en cours ou dans l'heure ; sinon « Pas encore de plan », « Tout le plan attend », « Pas le temps avant la réunion », « Plan du jour terminé » ou le jour de congé. En session, le minuteur en petit (`FocusTimer`, `metrics: .panel` : chiffres de 60, barre de 8, une graduation toutes les 5 min), Pause ou Reprendre, et C'est fait. En pause café, la carte passe sur `pomodoroBreakBg`. En fin de pomodoro, l'anneau refermé de 40 avec la coche, la série du jour, « Cocher la tâche », « Encore 5 min » et « Pause ».
  - « Aujourd'hui » : pastilles des pomodoros, focus du jour et « Plan 2 sur 5 » en 12 SemiBold secondaire, sur une barre de 6 en `actionPrimary`, en braise une fois le plan bouclé.
  - En pied, sous un `Hairline`, « Ouvrir Done ⌘O » et « Quitter ⌘Q » en boutons discrets.

## Saisie d'une tâche

- **Formulaire de capture** (`CaptureForm`) : la fiche d'une tâche, vide, sur 560 de large. `Eyebrow` « Nouvelle tâche », titre en `displayM` sans contour, notes, carte des détails (`TaskDetailsCard`, à plat : liste, étiquettes, priorité, type, échéance, répétition), puis la carte des étapes. Annuler et Ajouter (⌘ Entrée). La fiche d'une tâche existante (`TaskEditorSheet`) reprend les mêmes composants, avec la ligne « Bloquée » en plus.
- **Fenêtre flottante** (`QuickCapturePanel`) : le même formulaire, au niveau flottant, posé un peu au-dessus du centre de l'écran où se trouve la souris, sans faire passer Done au premier plan.
- **Barre de saisie de Ma journée** et **champ d'ajout des listes** : Entrée ajoute, la fin du titre est lue par `QuickEntry`.
- **Lecture du titre** (`QuickEntry`, `QuickEntryHint`) : sous le champ, quand la fin du titre dit une échéance, une priorité, une étiquette ou une répétition, une ligne « Compris » suivie des puces lues arrive en fondu.

## Stats

- **En-tête** : « Cette semaine » en `displayL`, la période en `body` secondaire, les flèches en `DoneIconButtonStyle`.
- **Grille** : six cartes widget (`WidgetCard`, comme Ma journée), trois colonnes (1 / 1,25 / 1) sur deux rangées, écart de 16, les graphiques dans la colonne large ; sous 1 150 de large utile, deux colonnes. Les cartes d'une rangée prennent la hauteur de la plus haute, et l'écran défile.
  1. **Focus de la semaine** : le total en `numericXL` (`stateActiveText`), l'écart avec la semaine d'avant en `callout` secondaire, puis les lignes Sessions, Tâches cochées et Plans bouclés (valeur en `numericM`, en `accentText` quand des plans ont été bouclés), séparées par un `Hairline`.
  2. **Par jour** : barres de 32 en `stateActive` (piste `pomodoroTrack` pour un jour vide), la durée au-dessus en `caption`, le jour en dessous ; les pomodoros en pastilles braise de 6 (5 au plus, puis « +2 » en `accentText`). Un soleil braise au-dessus de la meilleure journée ; un petit soleil à côté des jours où le plan a été bouclé.
  3. **Pomodoros et série** : le nombre en `numericL` ; une pastille de 10 par jour ouvré (et par jour de week-end travaillé), pleine en braise avec au moins un pomodoro, cerclée `borderDefault` sinon, en pointillé pour les jours à venir ; puis Série en cours (en `accentText`), Meilleur jour et Par jour travaillé.
  4. **Par projet** : jauges `ProgressBar` de 8.
  5. **Tes meilleures heures** : la phrase en `callout`, la période en `caption` secondaire, puis une barre par heure (8 h à 19 h au moins), les meilleures heures en `stateActive`, les autres en `stateActiveTint` ; l'heure sous une barre sur deux.
  6. **Interruptions** : le nombre en `numericL`, la part des sessions sans interruption en `callout` secondaire, puis une jauge par raison.
- **Mouvement** : les barres poussent l'une après l'autre (`arrive`, 40 ms d'écart), puis le soleil de la meilleure journée rebondit (`pop`). Avec « Réduire les animations », tout arrive en fondu.

## Logo

Carré arrondi blanc, réchauffé d'un halo braise en haut à droite et d'un halo rose en bas à gauche, comme la toile de l'app. Dessus, un anneau fin en encre (trait de 30 sur 824, piste à 12 %) ouvert sur 60°, et un point braise au milieu de l'ouverture, à 330°. Le trait reste fin même petit : c'est le point braise qui se lit à 16 px. Ne pas recolorer l'icône ni déplacer le point.

- Sources vectorielles : `docs/design/icon.svg` (icône de l'app) et `docs/design/glyph.svg` (glyphe à une encre).
- Dans l'app : `DoneAppIcon` (aux proportions du SVG, couleurs fixes, en bas du rail), l'asset `AppIcon` (Dock et Finder) et l'asset `DoneGlyph`, image « template » de la barre de menus.
- La couleur d'accent du système (`AccentColor`) reprend `focusRing` : #1573DD, #5AA2F0 en sombre.

## Écarts assumés avec la référence Mymind

- **Rôles `sun*` gardés.** La consigne était de ne renommer aucun rôle : ils restent déclarés comme alias de la braise, sans usage.
- **Cocher laisse une seconde**, et la ligne cochée descend de 12 en s'effaçant, comme en v6.
- **Puce « Fait » en vert** (`successTint`), comme le handoff et la fiche `StateChip` ; la fiche `TaskRow` la montre sur `accentTint`.
- **Marge des puces à 8**, au lieu de 9.
- **Tuile numérotée en rayon `xs`** (6), au lieu de 8.
- **Touches de raccourci en texte seul**, comme `.d-kbd`, y compris à droite du titre des listes.
- **Cases des cartes de note** : la case de 18 réduite à 14 par une mise à l'échelle.
- **Pages de projet** : absentes de la fiche `NoteCard`, elles prennent la teinte des références (`cardParchment`, étiquette `textSecondary`).
- **Salutation variée** : la référence montre « Bonjour » ; Done choisit la formule selon le moment de la journée et la change d'un jour à l'autre. Le prénom vient de Réglages › Accueil, sinon du compte macOS.
- **Focus aujourd'hui sans objectif** : pas de « sur 3 h visées », Done n'a pas d'objectif de focus par jour.
- **« Tout voir » des échéances** ouvre le Calendrier, qui montre les échéances de chaque jour.
- **Bilan du soir** à l'heure réglée dans Réglages, au lieu de 18:00 fixe.
- **Barre de saisie** : `#étiquette` est compris à la fin du titre ; `#projet` ne l'est pas, et le texte d'aide n'en parle pas. Une réunion ouvre sa feuille avec le titre déjà saisi, puisque la saisie rapide ne lit pas les heures.
- **Recherche** dans l'en-tête de Ma journée seulement ; ⌘K y ramène depuis les autres écrans.
- **Pas de touche Entrée globale** pour lancer le focus : Ma journée a un champ de saisie et des listes au clavier.
- **Cartes des feuilles à plat** : les cartes posées dans une feuille ou une autre carte n'ont pas d'ombre.

## Historique

- v7 « Mymind » (novembre 2026) : toile presque blanche, encre graphite, braise et cobalt ; Newsreader, Nunito Sans et Courier Prime ; écran Ma journée et rail. Référence dans `docs/design/mymind/`.
- v6 « Jardin » : papier crème, vert profond, tournesol ; Fraunces pour l'affichage ; mouvement des réussites. Gardée pour mémoire dans `docs/design/jardin/`.
- v5 : neutres froids, indigo, une seule famille (Archivo). Gardée dans `docs/design/Done-Design-System-v5.html`.
- v4 : l'export Claude Design d'octobre 2026, gardé dans `docs/design/Done-Design-System-v4.html`.
