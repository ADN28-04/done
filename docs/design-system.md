# Design system : Done v6 « Jardin »

Référence : `docs/design/jardin/design-system/`, avec `README.md`, `tokens.json` et, pour chaque composant, `components/<Nom>/README.md` et un aperçu HTML animé (`preview.html`, classes `d-…` de `components/bundle.css`). Ouvrir un aperçu dans un navigateur depuis le dépôt. Le passage depuis la v5 est décrit dans `docs/design/jardin/HANDOFF.md`. Dans le code, tout passe par `Done/Views/Theme.swift`.

L'esprit : un outil de travail chaleureux. Du papier crème, une encre vert-brun pour le texte, un vert profond pour ce qui agit, un tournesol pour la joie, une brique pour les seules alertes. L'écran reste calme ; c'est le geste qui fait plaisir : cocher une tâche, finir un pomodoro, boucler le plan du jour.

## Principes

- Une seule chose forte par écran : `displayXL` (Fraunces) pour l'action proposée, ou `numericXL` (Archivo) pour le minuteur. Le reste est en `body`, `callout` ou `caption`.
- Calme au repos, joyeux à l'arrivée. Le tournesol (`sun`) et le rebond sont réservés aux réussites : tâche cochée, pomodoro terminé, plan du jour bouclé. Une vue qu'on regarde sans agir ne bouge pas.
- Pas d'ombre sur les cartes, seulement un liseré `borderSubtle`. L'ombre `shadowRaised` sert à la carte de fin de pomodoro.
- Pas de fond derrière les dates, les durées et les étiquettes : `InfoChip` et `TagChip` sont du texte secondaire avec une icône.
- Pas de capitales espacées : les étiquettes de section sont en casse normale.
- Les nombres restent en Archivo, en chiffres tabulaires, jamais en Fraunces.
- Un seul bouton principal (`actionPrimary`) par vue.
- Le code ne cite jamais une couleur de marque ni une couleur système : seulement les rôles de `DoneColor`, les styles de texte et les composants.

## Contenu

- Interface en français, textes courts et directs, sans point d'exclamation. Verbes à l'infinitif sur les boutons : « Lancer le focus », « Cocher la tâche », « Ajouter ».
- La chaleur passe par les faits, pas par les adjectifs : « 3e pomodoro aujourd'hui », « Plan du jour terminé. Tout ce qui était prévu est fait. » Pas de « Bravo », pas de « Super ».
- Casse de phrase partout : « Plan du jour », « Échéances et retards », « Fait aujourd'hui ».
- Messages vides et d'état en une phrase : « Aucune tâche ouverte. », « En pause ».
- Pas d'emoji : le soleil est une icône, pas un caractère.

## Couleurs

La marque tient en cinq couleurs, qui n'apparaissent jamais sous leur nom dans le code : Crème #F7F3E8, Encre #23281F, Vert profond #2F6B4F, Tournesol #F6C343, Brique #A3332E. Le code passe par des rôles (`DoneColor`), qui changent de valeur entre clair et sombre. En sombre, le vert s'éclaircit et ce qui est posé dessus passe en vert nuit (#0F2419), pas en blanc.

| Rôle | Clair | Sombre | Usage |
|---|---|---|---|
| `bgCanvas` | #F7F3E8 | #161914 | Fond de fenêtre, du panneau de la barre de menus et de la saisie flottante |
| `bgSunken` | #EFE9DA | #11140F | Barre latérale, piste des sélecteurs, blocs de code, jour d'absence |
| `surfaceDefault` | #FFFDF7 | #1E221B | Cartes, champs, boutons secondaires, segment choisi |
| `surfaceHover` | #F3EEE0 | #272C23 | Survol |
| `surfaceSelected` | #E2EDE3 | #243529 | Navigation active, note choisie |
| `borderSubtle` | #E6DFCD | #2E3329 | Liseré des cartes, séparateurs, traits d'heure |
| `borderDefault` | #D5CDB8 | #3E4537 | Boutons secondaires, tuile vide, pastille de série vide |
| `borderControl` | #8A8473 | #858C7C | Champs et case à cocher (3:1) |
| `textPrimary` | #23281F | #ECEADF | Texte principal |
| `textSecondary` | #5C6354 | #A7AC9C | Métadonnées, légendes, étiquettes, dates et durées |
| `textDisabled` | #B4AF9F | #585E51 | Désactivé, réunion passée |
| `actionPrimary` (survol, appui) | #2F6B4F (#285E45, #204F3A) | #7CC39C (#8DCDA9, #6BB38C) | Bouton principal, case cochée |
| `actionOnPrimary` | #FFFFFF | #0F2419 | Texte et coche sur `actionPrimary` |
| `actionDisabled` | #EBE5D6 | #272C23 | Bouton principal ou case désactivés |
| `focusRing` | #2F6B4F | #8DCDA9 | Focus, cible de dépôt, champ actif |
| `stateActive` / `stateOnActive` | #3B7A5B / #FFFFFF | #7CC39C / #0F2419 | Plein actif : tuile du plan, barres, heure courante |
| `stateActiveText` | #1F5138 | #A6DBBB | Texte actif : priorités, liens [[Titre]], encadré d'information |
| `stateActiveTint` | #DCEBDF | #21362A | Teinte active : P1, encadré d'information, jetons d'étiquette, repère d'étapes |
| `sun` / `onSun` | #F6C343 / #3D2A00 | #F6C343 / #3D2A00 | Tournesol, en plein ou en forme seulement : soleil, pétales, pastilles de série |
| `sunTint` / `sunText` | #FBECC2 / #6B4A05 | #3A3016 / #F2CF6E | « Aujourd'hui », « Fait », encadré de réussite |
| `stateBlocked` / `stateOnBlocked` | #ECE6D7 / #23281F | #2A2F25 / #ECEADF | Puce « Bloquée » |
| `stateWaiting` | #8A8473 | #858C7C | Contour pointillé : emplacement libre, liste ou note vide |
| `stateRisk`, `stateRiskTint`, `stateRiskText` | #C2463F, #F8E3DE, #A3332E | #E06A63, #3A2320, #F0A29D | Alerte : échéance dépassée, erreur |
| `stateDone` / `stateOnDone` | #EFE9DA / #5C6354 | #1B1F18 / #A7AC9C | Terminé : « Fait aujourd'hui », réunion passée |
| `meetingBg`, `meetingHatch` | #EEE8D8, vert profond à 16 % | #23281F, vert clair à 16 % | Réunion à venir, hachurée |
| `meetingNow` / `meetingOnNow` | #2F6B4F / #FFFFFF | #7CC39C / #0F2419 | Réunion en cours |
| `pomodoroFocus` | #2F6B4F | #8DCDA9 | Anneau de concentration |
| `pomodoroBreak` | #B07A12 | #F2CF6E | Anneau de pause, un ocre de tournesol |
| `pomodoroBreakBg` | #FBF1D6 | #24210F | Fond de l'écran pendant la pause |
| `pomodoroTrack` | #E6DFCD | #2E3329 | Piste des anneaux et des barres |
| `pomodoroPaused` | #B4AF9F | #585E51 | Anneau à l'arrêt |

Règles :

- La couleur d'alerte n'apparaît que pour une échéance dépassée et pour les erreurs. Jamais pour une réunion, la fin d'un pomodoro ou l'heure courante.
- `sun` ne porte jamais de texte ni un sens seul : sur le papier clair, il ne fait que 1,5:1. Une icône double toujours la couleur (soleil pour « Aujourd'hui », coche pour « Fait », interdit pour « Bloquée », triangle pour l'alerte).
- Tournesol et brique ne se confondent pas : clartés très différentes, icônes différentes.
- Toutes les paires texte et fond passent AA (4,5:1) dans les deux thèmes : `textSecondary` sur `bgCanvas` 5,62:1 en clair et 7,63:1 en sombre, `actionOnPrimary` sur `actionPrimary` 6,29:1 et 7,88:1, `sunText` sur `sunTint` 6,86:1 et 8,63:1. `borderControl`, `focusRing` et les anneaux passent 3:1. Ne pas « corriger » une couleur sans recalculer ces ratios.

## Typographie

Deux familles sous licence OFL (licences dans `docs/fonts/`), embarquées dans `Done/Fonts` et chargées au lancement par `FontLoader` :

- **Fraunces**, dans sa version douce, en SemiBold (`Fraunces-SoftSemiBold.ttf`, nom PostScript `FrauncesSoft-SemiBold`), pour `displayXL`, `displayL` et `displayM` seulement : l'action proposée, les titres d'écran, de carte et de feuille. Ses courbes rondes donnent sa chaleur à l'app. Elle ne descend jamais sous `displayM` (23).
- **Archivo** Regular, Medium et SemiBold pour tout le reste : texte, boutons, navigation et nombres.

Les nombres prennent les chiffres tabulaires d'Archivo (`monospacedDigit`), appliqués d'office par les styles `numeric…` : les colonnes et le minuteur ne bougent pas en largeur. Un libellé reste dans un style de texte, même dans une puce.

Dans le code, `.doneText(.style)` applique la police, l'interlignage et l'interlettrage. `Font.sans(taille, graisse)` sert hors échelle (boutons, navigation active), avec `.monospacedDigit()` pour un nombre isolé.

| Style | Police | Taille / interligne | Usage |
|---|---|---|---|
| `displayXL` | Fraunces SemiBold, -0,01 em | 46/52 | L'action proposée sur l'écran Focus |
| `displayL` | Fraunces SemiBold, -0,005 em | 34/40 | Titres d'écran |
| `displayM` | Fraunces SemiBold | 23/28 | Titres de feuille et de carte, tâche en session, titre de note |
| `title` | Archivo SemiBold | 17/24 | Titre de panneau, tâche parente, groupe de sous-projet |
| `body` / `bodyStrong` | Archivo Regular / Medium | 14/20 | Texte courant / titre de tâche |
| `callout` | Archivo Regular | 13/18 | Texte d'appoint, encadrés |
| `caption` | Archivo Regular | 12/16 | Métadonnées |
| `label` | Archivo SemiBold, casse normale | 12/16 | Étiquettes de section (`Eyebrow`) |
| `numericXL` | Archivo Regular, -0,02 em, chiffres tabulaires | 60/64 | Minuteur, total de la semaine |
| `numericL` | Archivo Medium, -0,01 em, chiffres tabulaires | 28/32 | Totaux, minuteur de la barre de menus |
| `numericM` / `numericS` | Archivo Medium, chiffres tabulaires | 14/20, 12/16 | Valeurs en ligne / dates, durées, compteurs |

Formats : « 1 h 30 », « 45 min », « 14:00 », minuteur « 18:42 », date courte « mar. 3 nov. », dates relatives « Auj. », « Demain », « Hier » (`Format.chipDate`), rang « 1er », « 2e » (`Format.ordinal`).

## Mesures

- **Espacements** (`DoneSpace`) : grille de 4, avec 2 et 6 pour les détails. 8 entre lignes, 12 dans une ligne et entre les puces, 16 dans une carte, 24 pour les marges de panneau, 32 entre sections, 40 pour les marges d'écran.
- **Rayons** (`DoneRadius`), doux, jamais en pilule sauf la barre de progression :
  - `xs` 5 : case à cocher, segment choisi ;
  - `chip` 8 : puces d'état, de priorité et de réussite, jetons d'étiquette ;
  - `sm` 10 : boutons, champs, réunions, navigation, tuile numérotée, encadrés ;
  - `md` 14 : lignes de tâche, cartes ;
  - `lg` 20 : panneaux, feuilles, carte de fin de pomodoro, carte de la ligne de temps.
- **Contours** : 1 en `borderSubtle` (cartes), `borderDefault` (boutons secondaires) ou `borderControl` (champs) ; 1,5 pour la case à cocher, le pointillé `stateWaiting` et le trait de l'heure courante ; 2 en `focusRing` (focus, cible de dépôt, champ actif) ; 8 pour l'anneau du minuteur.
- **Hauteurs fixes** : contrôle 32, contrôle compact 26, puce 22, case à cocher 18, tuile et segment 24, ligne de tâche 48, barre du haut 52. Barre latérale de 228, anneau du minuteur de 280, retrait d'une étape de 28 par niveau.
- **Ombres**, teintées de l'encre #23281F en clair, noires en sombre :
  - `shadowCard` (0 1 2, 8 % ; 35 % en sombre) : segment choisi du sélecteur, rien d'autre ;
  - `shadowRaised` (0 14 32 à 12 %, plus 0 2 6 à 6 % ; 50 % et 30 % en sombre) : `doneRaised`, la carte de fin de pomodoro.

## Mouvement

Le mouvement dit « c'est fait » ; il ne décore pas.

- Ce qui arrive ralentit en se posant (ease-out). Ce qui se déplace accélère puis freine (ease-in-out). Seules les réussites rebondissent (ease-spring), et une seule fois.
- Rien ne bouge sans action de la personne, sauf l'anneau du minuteur.
- Avec « Réduire les animations » (macOS), il ne reste que des fondus : pas d'échelle, de rebond ni d'éclat. Chaque vue animée lit `accessibilityReduceMotion` ; `DoneMotion.motion(_:reduced:)` remplace un mouvement par `DoneMotion.fade`.

`DoneMotion` reprend les tokens de durée et de courbe, avec les équivalents SwiftUI de la référence :

| Token | `DoneMotion` | SwiftUI | Usage |
|---|---|---|---|
| ease-out, `dur-instant` (90 ms) | `press` | `.easeOut(duration: 0.09)` | Appui : bouton à 0,97, case à 0,88 |
| ease-out, `dur-fast` (160 ms) | `hover`, `fade` | `.easeOut(duration: 0.16)` | Survol, coche, couleur d'état ; fondu de repli |
| ease-out, `dur-base` (260 ms) | `appear` | `.easeOut(duration: 0.26)` | Encadré, trait du titre barré |
| ease-in-out, `dur-base` | `move` | `.easeInOut(duration: 0.26)` | Segment choisi, section repliable, barre latérale |
| ease-spring, `dur-base` | `pop` | `.spring(response: 0.3, dampingFraction: 0.55)` | Case cochée, puce « Fait », pastille de série |
| ease-out, `dur-slow` (420 ms) | `arrive` | `.smooth(duration: 0.42)` | Carte, feuille, fond de la pause |
| ease-in-out, `dur-slow` | `travel` | `.easeInOut(duration: 0.42)` | Ligne qui quitte sa liste |
| ease-out, `dur-celebrate` (900 ms) | `burst` | `.easeOut(duration: 0.9)` | Éclat de tournesol |

Pièces communes, dans `Theme.swift` : `donePress` (appui, et `DonePressStyle` pour la case), `doneArrive` (fondu à l'apparition, avec une montée de 12 pour une carte), `CheckMarkShape` (coche à tracer avec `.trim`), `SunBurst` (halo `sunTint` et huit pétales `sun` qui partent une fois chaque fois que son compteur augmente).

Les moments animés :

- **Cocher une tâche** : la case se tasse, rebondit et sa coche se trace ; huit pétales partent ; le titre se barre de gauche à droite ; « Fait » remplace les puces en rebondissant ; une seconde plus tard, la ligne quitte sa liste en glissant vers le bas. Rouvrir ne rejoue rien.
- **Fin de pomodoro** : la carte monte de 12 et apparaît ; l'anneau se referme ; la coche se trace et l'éclat part ; la pastille du pomodoro qui vient de finir rebondit.
- **Plan du jour bouclé** : l'encadré de réussite arrive en fondu ; le soleil d'« Aujourd'hui » dans la barre latérale fait un seul éclat.
- **Pause** : le fond passe à `pomodoroBreakBg` et la vue de pause arrive, ensemble, en `dur-slow`. Le passage à l'arrêt change la couleur de l'anneau au même rythme.
- **Sélecteur** : le segment choisi glisse vers la nouvelle option.
- **Boutons et cases** : ils se tassent à l'appui ; le survol change le fond en `dur-fast`.

## Iconographie

- SF Symbols, en graisse Medium ou SemiBold, de 9 à 16 pt, en texte secondaire dans les puces et en texte principal dans les boutons. Symboles en usage : `calendar`, `clock`, `tag`, `flag` (priorité lue à la saisie), `arrow.clockwise` (répétition), `checkmark`, `nosign`, `exclamationmark.triangle`, `info.circle`, `sun.max`, `calendar.day.timeline.left`, `doc.text`, `folder`, `tray`, `sidebar.left`, `chevron.down`, `chevron.right`.
- `sun.max` est le signe de la journée : dans la navigation (« Aujourd'hui », en `sunText`), dans la puce « Aujourd'hui » et dans l'encadré de réussite.
- La coche animée est un tracé (`CheckMarkShape`), pour pouvoir se dessiner ; la coche des puces reste le symbole `checkmark`.

## Composants

- **Boutons** (`DoneButtonStyle`) : hauteur 32, rayon `sm`, padding 14 ; texte Archivo 14, SemiBold pour le principal, Medium pour les autres.
  - Principal en `actionPrimary` (un seul par vue), secondaire sur surface avec contour `borderDefault`, discret en texte seul.
  - Variante `compact` de 26, texte 13, pour les lignes de réglages et le stepper.
  - `DoneIconButtonStyle` : bouton carré de 32 (nouvelle tâche, semaines), contour `borderDefault`.
- **Champ** (`doneField`) : hauteur 32 (36 pour l'ajout des listes), rayon `sm`, contour `borderControl` ; contour `focusRing` de 2 au focus.
- **Case à cocher** (`TaskCheckbox`) : carré de 18, rayon `xs`, contour 1,5 en `borderControl`. La coche apparaît en filigrane au survol ; cochée, plein `actionPrimary` et coche `actionOnPrimary`. Désactivée : `actionDisabled` et contour `borderSubtle`. Avec `bursts`, l'éclat de tournesol accompagne la coche. Sert aussi aux cases des notes Markdown.
- **Puces** : hauteur 22, rayon `chip`, jamais de contour.
  - `StateChip`, marge 8, icône 10, texte 12 Medium :
    - `active`, « Aujourd'hui » : soleil, `sunText` sur `sunTint`, pour une tâche du plan ;
    - `doneToday`, « Fait » : coche, `sunText` sur `sunTint`, pour une tâche qu'on vient de cocher ;
    - `blocked`, « Bloquée » : interdit, sur `stateBlocked` ;
    - `risk` : triangle, sur `stateRiskTint` ;
    - `done` : coche et texte `stateOnDone` sans fond, pour ce qui a été fait un autre jour.
  - `InfoChip` : date (calendrier), durée (horloge) ou répétition (`arrow.clockwise`, « Chaque lundi »), icône et texte secondaires sans fond ; en texte d'alerte une fois l'échéance dépassée.
  - `PriorityChip` : P1 SemiBold sur teinte active, marge 8 ; P2 Medium en texte actif seul ; rien pour P3 et P4.
  - `TagChip` : icône `tag` et nom en texte secondaire, sans fond. Dans la vue d'une étiquette, celle-ci n'est pas répétée sur les lignes.
- **Éditeur d'étiquettes** (`TagEditor`, dans la carte des détails) : jetons sur teinte active, rayon `chip`, avec une croix ; un champ « Ajouter » et le menu des étiquettes existantes. Absent pour une étape.
- **Ligne de tâche** : hauteur 48, rayon `md`.
  - Au survol, `surfaceHover` et poignée de déplacement.
  - Titre (`TaskTitle`) en `bodyStrong` sur deux lignes au plus, métadonnées en `caption`.
  - Puces à droite (`TaskChips`), espacées de 12 : priorité, « Aujourd'hui » ou « Bloquée », étiquettes, échéance, répétition, durée.
  - Au clavier, la ligne choisie passe en `surfaceSelected` (voir Raccourcis).
  - Étapes en retrait de 28 par niveau.
  - Cocher passe par `AppModel.completeSoon` : la tâche reste ouverte une seconde, le temps de l'animation, puis elle est cochée. Recliquer pendant cette seconde annule ; quitter Done enregistre aussitôt les coches en attente. `TaskRowTrailing` remplace les puces par « Fait ».
- **Raccourcis** (`KeyCap`, `ShortcutHint`, `ListShortcutHints`) : des touches dessinées, comme le « ⌘K » d'une recherche. Touche de 18 de haut, rayon `xs`, contour `borderDefault` sur `surfaceDefault`, Archivo 11 Medium en texte secondaire ; le verbe suit en `caption` secondaire. À droite du titre d'une liste et d'Aujourd'hui : « ↑ ↓ Choisir », « Espace Cocher », « ↩ Ouvrir », « ⌘ ↑ ↓ Déplacer ». Ils ne prennent pas la parole : pas de couleur, pas de fond plein.
- **Élément de navigation** (`NavItem`) : hauteur 32, rayon `sm`, icône 16, compteur `numericS` à droite. Actif en `surfaceSelected` et SemiBold. `iconColor` donne sa couleur propre à une icône (le soleil d'« Aujourd'hui », en `sunText`), `burstCount` lui fait faire un éclat.
- **Élément du rail** (`NavRailItem`) : case de 40 × 32, rayon `sm`, icône 16 ; actif en `surfaceSelected`, survol en `surfaceHover`. Le titre et le raccourci passent dans l'aide.
- **Bloc réunion** (`MeetingBlock`, `Hatching`) : rayon `sm`. Hachuré à venir (traits de 1,5 à 45° tous les 6, le temps est pris), plein `meetingNow` en cours, `stateDone` une fois passé. La pastille du haut (`MeetingPill`) suit les mêmes règles.
- **Tuile numérotée** (`NumberTile`) : 24, rayon `sm`. Pleine `stateActive` pour une place dans le plan, en contour `borderDefault` pour un emplacement libre.
- **Sélecteur** (`DoneSegmented`) : piste `bgSunken` de rayon `sm` ; segment de 24, rayon `xs`, sur `surfaceDefault` avec `shadowCard`, qui glisse d'une option à l'autre (`matchedGeometryEffect`).
- **Encadré** (`NoticeBox`) : sans contour, rayon `sm`, texte `callout`, icône de 11 ; arrive en fondu.
  - `info` : « i », `stateActiveText` sur `stateActiveTint` ;
  - `success` : soleil, `sunText` sur `sunTint`, pour le plan du jour terminé ;
  - `error` : triangle, `stateRiskText` sur `stateRiskTint`.
- **Cartes** : `doneCard` (surface, liseré `borderSubtle`, rayon `md`, ou `lg` pour un panneau) ; `doneRaised` (rayon `lg`, ombre `shadowRaised`) pour la carte de fin de pomodoro seulement.
- **Anneau et barre** : `ProgressRing` (voir Pomodoro) ; `ProgressBar`, hauteur 6, en capsule, plein `stateActive` sur `pomodoroTrack`.

## Aujourd'hui

- **En-tête** : « Aujourd'hui » en `displayL`, puis la date, le nombre de réunions et le focus fait en `body` secondaire.
- **Ligne de temps** : 320 de large, dans une carte (`doneCard`, rayon `lg`), la même `DayTimeline` que le calendrier avec ses heures, étirée sur la hauteur.
- **Listes** : « Plan du jour » (tuiles numérotées, « Lancer le focus » en bouton principal compact, « Modifier le plan » en secondaire), « Échéances et retards », puis « Fait aujourd'hui », replié, sur `stateDone`. Lignes de 48 : case à cocher, titre et puces, survol en `surfaceHover`. Une tâche cochée quitte sa liste en glissant.
- **Plan bouclé** : quand tout le plan du jour est coché, l'encadré `success` « Plan du jour terminé. Tout ce qui était prévu est fait. » prend la place de la liste, et le bouton devient « Ajouter au plan ».

## Notes

- **Écran** : liste de 300 à gauche (titre « Notes » en `displayL`, bouton +, champ de recherche `doneField`, filtre « Type : … » en `callout`), trait `borderSubtle`, puis la note sur 760 au plus.
- **Ligne de note** (`NoteRow`) : icône du type (13, secondaire), titre en `bodyStrong`, détails en `caption` (type, projet, moment). Choisie en `surfaceSelected`, survol en `surfaceHover`.
- **Note** : puce du type sur teinte active (rayon `chip`), « Modifiée … » en `caption`, titre en `displayM` sans contour, carte des rattachements (`DetailRow`), puis « Contenu ». Aperçu (`MarkdownView`) : titres en `displayM`, `title` et `bodyStrong` ; texte en `body` ; puces « • » secondaires ; cases `TaskCheckbox`, qui rebondissent quand on les coche ; citations avec un filet de 3 en `borderDefault` ; code sur `bgSunken` ; liens [[Titre]] en texte actif. Édition : `TextEditor` en `body`, contour `focusRing` de 2. Note vide : cadre pointillé `stateWaiting`.
- **Liens** : « Liens » et « Citée dans », en lignes de note.
- **Ailleurs** : carte « Documentation » en haut de la vue d'un projet ; bouton « Note du jour » dans l'en-tête d'Aujourd'hui ; « Prendre des notes » dans la fiche d'une réunion ; liste « Notes » dans la fiche d'une tâche. Une note ouverte ailleurs que dans l'écran Notes s'affiche dans une feuille (`NoteSheet`, 760 × 680) avec « Retour » quand on suit un lien.

## Projet et sous-projets

La vue d'un projet montre d'abord ses propres tâches, puis un groupe par sous-projet : titre en `title` avec l'icône `folder` et le nombre de tâches (un clic ouvre le sous-projet), puis la carte de ses lignes, ou « Aucune tâche ouverte. » en `callout` secondaire.

## Calendrier

- **Colonnes** : une par jour, du lundi au vendredi, séparées par un trait `borderSubtle`, après une gouttière de 44 pour les heures (`numericS`, texte secondaire).
- **En-tête de jour** : « Lun 2 » en Archivo SemiBold 15 (texte actif pour aujourd'hui), puis une ligne `caption` : l'absence (icône `sun.max`), sinon le focus du jour, sinon « Aujourd'hui ». Menu « … » discret à droite, et le même menu au clic droit.
- **Échéances** : 108 de haut, une petite carte par tâche (surface, liseré, rayon `sm`, `PriorityChip` et titre en `callout`), en texte d'alerte quand elle est en retard. Le jour survolé pendant un glisser-déposer prend la teinte active.
- **Grille** : de 8 h à 19 h, étirée sur toute la hauteur de la fenêtre, avec au moins 44 par heure (en dessous, elle défile), traits d'heure `borderSubtle`. Réunions en `MeetingBlock` qui remplit son créneau ; focus passé sur teinte active avec un filet `stateActive` de 3 à gauche et le titre en 11 Medium ; deux événements qui se chevauchent se partagent la largeur. Heure courante : un point et un trait de 1,5 en `stateActive`, jamais en couleur d'alerte. Jour d'absence : fond `bgSunken`.

## Navigation

Barre latérale de 228, sur `bgSunken`, avec un trait `borderSubtle` à droite. Le bouton `sidebar.left` à gauche de la barre du haut, ou ⌃⌘S, la réduit en un rail de 56 (`NavRailItem` : Focus, Aujourd'hui, Plan du jour, Calendrier, Inbox, Notes, puis Stats et Réglages en bas) ; survolé un instant (150 ms), le rail laisse passer la barre complète par-dessus, avec son ombre, comme en session. La barre complète porte :

- en haut, Focus (⌘1, glyphe de Done), Aujourd'hui (⌘6, soleil `sun.max` toujours en `sunText`), Plan du jour (⌘2, avec le nombre de tâches du plan), Calendrier (⌘5, `calendar.day.timeline.left`), Inbox (⌘3) et Notes (⌘7, `doc.text`) ;
- au milieu, deux sections repliables, leur titre (`Eyebrow`) suivi d'un chevron de 9 à droite : « Projets », chaque projet suivi de ses sous-projets en retrait de 16 (un chevron dans le `NavItem` du projet les replie), puis « Nouveau projet » ; « Étiquettes », une entrée par étiquette (icône `tag`). Chaque entrée porte son nombre de tâches ouvertes, celui d'un projet comptant ses sous-projets ;
- en bas, Stats (⌘4) et Réglages (⌘,).

Les feux de la fenêtre sont posés sur le haut de la barre. La barre du haut, de 52, porte au centre la pastille de réunion (Focus et Plan du jour), à droite le bouton « + » de la capture rapide (⌘N).

En session (minuteur, pause, interruption, fin), la barre latérale s'efface en glissant et revient par-dessus quand la souris touche le bord gauche. Les raccourcis restent actifs.

## Pomodoro

- **Minuteur** : anneau de 280, trait 8, qui se vide dans le sens horaire depuis midi et glisse d'une seconde à l'autre ; chiffres en `numericXL`.
  - En concentration : `pomodoroFocus`, vert profond (vert tendre en sombre).
  - À l'arrêt : `pomodoroPaused`, avec la mention « En pause ».
  - En pause : l'écran passe sur `pomodoroBreakBg`, une lumière plus chaude, et l'anneau en `pomodoroBreak`, ocre.
  - Aucune couleur d'alerte, même à la fin.
- **Fin de pomodoro** (`OutcomeView`, composant `PomodoroDone` de la référence) : carte surélevée de 520 (`doneRaised`), le seul élément surélevé de Done.
  - Anneau de 56 en `pomodoroFocus` qui se referme, puis une coche qui se trace au centre et l'éclat de tournesol.
  - « Pomodoro terminé » (ou le titre de l'étape cochée en avance) en `displayM`, la durée et la tâche en `callout` secondaire.
  - Pour un pomodoro terminé, la série du jour : une pastille `sun` de 10 par pomodoro fait (8 au plus), une pastille vide pour le prochain, et « 3e pomodoro aujourd'hui » en `sunText`. Un pomodoro est un minuteur mené au bout, rallonges comprises (`Stats.pomodoros`) ; une tâche cochée avant la fin ne compte pas.
  - Les actions de Done : « Cocher la tâche » en principal, « Encore 5 min » et « Pause, puis je reprends » en secondaire, « Bloqué… » et « Arrêter là » en discret.
- **Barre de menus** : image « template » du système, qui prend la couleur de la barre de menus. Au repos, le glyphe de Done, ou `sun.max` une fois le plan du jour bouclé : le soleil reste monochrome, comme toutes les icônes de la barre.
  - Concentration : mini-anneau de 16 rendu à la volée, et temps restant en chiffres tabulaires.
  - Arrêt et pause : icônes pause et tasse.
  - Fin : anneau plein et « Fini ».
- **Panneau de la barre de menus** : 300 de large, sur `bgCanvas`. En haut, la capture : `Eyebrow` « Nouvelle tâche », champ `doneField`, menu « Dans : Inbox » en `callout` et, à droite, « Détails… » en bouton discret, remplacé après un ajout par « Ajoutée dans … » en `caption` secondaire. Un `Hairline`, puis la session en cours et les boutons.

## Saisie d'une tâche

- **Formulaire de capture** (`CaptureForm`) : la fiche d'une tâche, vide, sur 560 de large. `Eyebrow` « Nouvelle tâche », titre en `displayM` sans contour, notes (`NotesEditor`, 64 de haut), carte des détails (`TaskDetailsCard` : liste, étiquettes, priorité, type, échéance, en lignes `DetailRow` de 44), puis la carte des étapes (lignes de 36, numéro en `numericS`, croix pour retirer). Annuler et Ajouter (⌘ Entrée) en bas à droite. La fiche d'une tâche existante (`TaskEditorSheet`) reprend les mêmes composants, avec la ligne « Bloquée » en plus ; cocher une étape y suit la même seconde d'attente que dans les listes.
- **Fenêtre flottante** (`QuickCapturePanel`) : le même formulaire dans une fenêtre sans barre de titre visible, au niveau flottant, sur `bgCanvas`, posée un peu au-dessus du centre de l'écran où se trouve la souris. Elle ne fait pas passer Done au premier plan.
- **Champ d'ajout des listes** : une ligne `doneField` de 36, avec « Détails… » en bouton discret à droite.
- **Lecture du titre** (`QuickEntry`, `QuickEntryHint`) : sous chaque champ de saisie, quand la fin du titre dit une échéance, une priorité, une étiquette ou une répétition, une ligne « Compris » en `caption` suivie des puces lues (`InfoChip` et `TagChip`) arrive en fondu. Rien quand il n'y a rien à lire.
- **Répétition** : ligne « Répétition » de la carte des détails (`RecurrenceMenu`) : Jamais, Chaque jour, Jours ouvrés, Chaque semaine (jours à cocher), Toutes les deux semaines, Chaque mois. Absente pour une étape.

## Stats

- **En-tête** : « Cette semaine » en `displayL`, la période en `body` secondaire, les flèches en `DoneIconButtonStyle`.
- **Total** : les minutes de focus en `numericXL` (texte actif), puis « de focus · 9 pomodoros · 3 tâches cochées · 1 interruption » en `body` secondaire.
- **Par jour** : une carte de rayon `lg`. Barres de 40 en `stateActive` (piste `pomodoroTrack` pour un jour vide), la durée au-dessus en `caption`, le jour en dessous. Sous le jour, ses pomodoros en pastilles `sun` de 6 (5 au plus, puis « +2 » en `sunText`). Un soleil `sunText` au-dessus de la meilleure journée ; un petit soleil à côté des jours où le plan a été bouclé, et leur nombre en tête de la carte, en `sunText`.
- **Par projet** : jauges `ProgressBar` de 8.
- **Mouvement** : à l'arrivée sur l'écran et à chaque changement de semaine, les barres poussent l'une après l'autre (`arrive`, 40 ms d'écart), puis le soleil de la meilleure journée rebondit (`pop`). Avec « Réduire les animations », tout arrive en fondu.

## Logo

Carré arrondi en dégradé de vert (#3B7A5B en haut, #204F3A en bas), anneau crème (#F7F3E8) à 24 % et arc crème de 300° partant du haut : un minuteur presque refermé. Dans l'ouverture, à 330°, un soleil tournesol (#F6C343) : la tâche est presque faite, la journée se lève. Le soleil reste un disque plein, sans rayons, pour se lire à 16 px. Ne pas recolorer l'icône ni déplacer le soleil.

- Sources vectorielles : `docs/design/icon.svg` (icône de l'app) et `docs/design/glyph.svg` (glyphe à une encre).
- Dans l'app : `DoneAppIcon` (aux proportions du SVG, couleurs fixes), l'asset `AppIcon` (Dock et Finder, de 16 à 1024) et l'asset `DoneGlyph` (18 et 36), image « template » de la navigation et de la barre de menus.
- La couleur d'accent du système (`AccentColor`) reprend `stateActive` : #3B7A5B, #7CC39C en sombre. Elle teinte l'anneau de focus du clavier.

## Écarts assumés avec la référence Jardin

- **Cocher laisse une seconde.** La référence montre l'animation ; dans l'app, la tâche reste ouverte une seconde pour qu'on la voie, et recliquer pendant ce temps annule. Les autres façons de cocher (minuteur, Rappels, Claude) restent immédiates.
- **La ligne descend en s'effaçant.** « Fait aujourd'hui » est souvent replié : au lieu de rejoindre cette section, la ligne cochée glisse de 12 vers le bas en s'effaçant, et les autres se resserrent.
- **Carte de fin de pomodoro.** Elle garde les actions et les libellés de Done (« Pause, puis je reprends », « Bloqué… », « Arrêter là », la note de reprise) au lieu de « Pause » et « Arrêter ». La série s'arrête à 8 pastilles ; au-delà, seule la phrase compte.
- **Noms des genres de puce.** La référence parle de `today`, `done` et `past` ; le code garde ses noms : `active` est « Aujourd'hui », `done` est le « fait un autre jour » en texte seul, et `doneToday` est le nouveau « Fait » sur `sunTint`.
- **Fraunces en TTF statique.** La référence décrit la police variable (`Fraunces-Soft-Variable.woff2`) ; l'app embarque la seule instance utilisée, Soft SemiBold, réduite aux caractères latins (le français est couvert).
- **Tuile numérotée en rayon `sm`**, comme dans `tokens.json`, alors que la fiche `TaskRow` indique `chip`.
- **Plan bouclé sur l'écran Focus.** La référence ne le dessine pas : Focus montre l'encadré de réussite et « Ajouter au plan », au lieu de « Pas encore de plan pour aujourd'hui ».

## Historique

- v6 « Jardin » (novembre 2026) : papier crème, vert profond, tournesol ; Fraunces pour l'affichage ; mouvement des réussites. Référence dans `docs/design/jardin/`.
- v5 : neutres froids, indigo, une seule famille (Archivo, avec SemiCondensed pour l'affichage et Light pour le minuteur). Gardée pour mémoire dans `docs/design/Done-Design-System-v5.html`.
- v4 : l'export Claude Design d'octobre 2026, gardé dans `docs/design/Done-Design-System-v4.html`. Ses composants propres aux fonctions retirées de Done (chantiers, file d'attente, capacité) n'ont jamais été repris.
