# Design system : Done

Référence actuelle : `docs/design/Done-Design-System-v5.html` (couleurs, typographie et écrans, en clair et en sombre ; ouvrir le fichier dans un navigateur depuis le dépôt, il charge les polices de `Done/Fonts`). La v5 affine la v4, l'export Claude Design d'octobre 2026 gardé dans `docs/design/Done-Design-System-v4.html` : mêmes composants et mêmes mesures, mais une palette plus neutre, une seule famille de caractères et moins d'ornements. Dans le code, tout passe par `Done/Views/Theme.swift`.

L'esprit : un outil de travail net. Du papier neutre, un graphite pour le texte, un indigo pour ce qui agit, une brique pour les seules alertes. Une seule chose forte par écran : la prochaine action en titre semi-étroit, ou le minuteur en chiffres fins. Le reste se tait :

- pas d'ombre sur les cartes, seulement un liseré ;
- pas de fond derrière les dates et les durées ;
- pas de capitales espacées : les étiquettes sont en casse normale ;
- pas de police à chasse fixe : les nombres utilisent les chiffres tabulaires d'Archivo.

## Couleurs

Papier #F6F6F7, Graphite #1C1E26, Indigo #4553A0, Pervenche #AAB4F2, Brique #A3332E. Le code ne les cite jamais directement : il utilise des rôles (`DoneColor`), qui changent de valeur entre clair et sombre.

| Rôle | Clair | Sombre | Usage |
|---|---|---|---|
| `bgCanvas` | #F6F6F7 | #17181C | Fond de fenêtre |
| `bgSunken` | #EEEFF2 | #131417 | Barre latérale, piste des sélecteurs |
| `surfaceDefault` | #FFFFFF | #1F2025 | Cartes, champs, boutons secondaires |
| `surfaceHover` | #F0F1F4 | #26272D | Survol |
| `surfaceSelected` | #E7E9F4 | #272B45 | Navigation active |
| `borderSubtle` | #E4E5EA | #2E3036 | Séparateurs, contours de carte |
| `borderDefault` | #D2D4DB | #3D3F46 | Boutons secondaires, tuile numérotée vide |
| `borderControl` | #8A8E99 | #858A96 | Champs et cases (3:1) |
| `textPrimary` | #1C1E26 | #E6E7EB | Texte principal |
| `textSecondary` | #5E626D | #9EA2AD | Métadonnées, légendes, étiquettes, dates et durées |
| `textDisabled` | #B0B3BC | #565A63 | Désactivé |
| `actionPrimary` (survol, appui) | #4553A0 (#3A4690, #313B7C) | #5A68C0 (#5260B8, #4A57A8) | Bouton principal |
| `actionOnPrimary` | #FFFFFF | #FFFFFF | Texte sur bouton principal |
| `actionDisabled` | #E8E9EE | #26272D | Fond de bouton désactivé |
| `focusRing` | #4553A0 | #AAB4F2 | Focus, cible de dépôt, champ actif |
| `stateActive` | #4F5CB0 | #5A68C0 | Plein actif : tuile du plan, barres, point « Aujourd'hui » |
| `stateActiveText` | #3A4690 | #AAB4F2 | Texte actif, priorités |
| `stateActiveTint` | #E7E9F4 | #23263B | Teinte active : P1, « Aujourd'hui », encadré d'information, repère d'étapes |
| `stateBlocked` / `stateOnBlocked` | #ECEDF0 / #1C1E26 | #26272D / #E6E7EB | Puce « Bloquée » |
| `stateWaiting` | #8A8E99 | #858A96 | Contour pointillé : emplacement libre, liste vide |
| `stateRisk`, `stateRiskTint`, `stateRiskText` | #C2463F, #F8E6E5, #A3332E | #E06A63, #3A2224, #F0A29D | Alerte : échéance dépassée, erreur |
| `stateDone` / `stateOnDone` | #EEEFF2 / #5E626D | #1C1D21 / #9EA2AD | Terminé : recule visuellement |
| `meetingBg`, `meetingHatch` | #EFF0F3, Indigo à 14 % | #222328, Pervenche à 14 % | Réunion à venir, hachurée |
| `meetingNow` / `meetingOnNow` | #4553A0 / #FFFFFF | #5A68C0 / #FFFFFF | Réunion en cours |
| `pomodoroFocus` | #4553A0 | #8F9BE8 | Anneau de concentration |
| `pomodoroBreak` | #6F7BC2 | #AAB4F2 | Anneau de pause |
| `pomodoroBreakBg` | #EDEFF8 | #1D2033 | Fond de l'écran pendant la pause |
| `pomodoroTrack` | #E4E5EA | #2E3036 | Piste des anneaux et des barres |
| `pomodoroPaused` | #B0B3BC | #565A63 | Anneau à l'arrêt |

Règles :

- La couleur d'alerte n'apparaît que pour une échéance dépassée et pour les erreurs.
- Pervenche n'est jamais du texte en clair.
- Il y a un seul bouton principal par vue.
- Toutes les combinaisons texte et fond passent AA (4,5:1) : texte secondaire sur fond 5,65:1 en clair et 6,95:1 en sombre, blanc sur bouton principal 7,00:1 et 5,03:1. Les contours de champ et les anneaux passent 3:1.

## Typographie

Une seule famille, **Archivo** (Omnibus-Type, licence OFL dans `docs/fonts/`), en cinq instances statiques tirées de la police variable de Google Fonts, embarquées dans `Done/Fonts` et chargées au lancement par `FontLoader` :

- **Archivo SemiCondensed SemiBold** pour les titres d'affichage. La largeur semi-étroite donne sa voix à la prochaine action et tient les titres longs sur moins de lignes ;
- **Archivo Regular, Medium et SemiBold** pour le texte, les boutons et la navigation ;
- **Archivo Light** pour le minuteur, en grand.

Les nombres prennent les chiffres tabulaires d'Archivo (`monospacedDigit`), appliqués d'office par les styles `numeric…` : les colonnes et le minuteur ne bougent pas en largeur. Un libellé reste dans un style de texte, même dans une puce.

Dans le code, `.doneText(.style)` applique la police, l'interlignage et l'interlettrage. `Font.sans(taille, graisse)` sert hors échelle (boutons, navigation active), avec `.monospacedDigit()` pour un nombre isolé (tuile numérotée).

| Style | Police | Taille / interligne | Usage |
|---|---|---|---|
| `displayXL` | SemiCondensed SemiBold, -0,015 em | 44/48 | L'action proposée sur l'écran Focus |
| `displayL` | SemiCondensed SemiBold, -0,01 em | 32/36 | Titres d'écran |
| `displayM` | SemiCondensed SemiBold, -0,005 em | 22/28 | Titres de feuille, de carte, tâche en session |
| `title` | SemiBold | 17/24 | Titre de panneau, tâche parente |
| `body` / `bodyStrong` | Regular / Medium | 14/20 | Texte courant / titre de tâche |
| `callout` | Regular | 13/18 | Texte d'appoint |
| `caption` | Regular | 12/16 | Métadonnées |
| `label` | SemiBold, casse normale | 12/16 | Étiquettes de section (`Eyebrow`) |
| `numericXL` | Light, -0,02 em, chiffres tabulaires | 60/64 | Minuteur, total de la semaine |
| `numericL` | Medium, -0,01 em, chiffres tabulaires | 28/32 | Totaux, minuteur de la barre de menus |
| `numericM` / `numericS` | Medium, chiffres tabulaires | 14/20, 12/16 | Valeurs en ligne / dates et durées |

Formats : « 1 h 30 », « 45 min », « 14:00 », minuteur « 18:42 », date courte « mar. 3 nov. », dates relatives « Auj. », « Demain », « Hier » (`Format.chipDate`).

## Mesures

- **Espacements** (`DoneSpace`) : grille de 4, avec 2 et 6 pour les détails. 8 entre lignes, 12 dans une ligne et entre les puces, 16 dans une carte, 24 pour les marges de panneau, 32 entre sections, 40 pour les marges d'écran.
- **Rayons** (`DoneRadius`) : 3, et 4 pour les puces et la case à cocher, 6 pour les boutons, champs, réunions et la navigation, 10 pour les lignes et les cartes, 14 pour les panneaux et les feuilles.
- **Bordures** : 1 pt `borderSubtle` (cartes), 1 pt `borderDefault` (boutons secondaires), 1 pt `borderControl` (champs), 1,5 pt pour la case à cocher, 1,5 pt pointillé `stateWaiting` (emplacement libre), 2 pt `focusRing` (focus, cible de dépôt).
- **Ombres** : aucune sur les cartes (`doneCard`). `doneRaised` (0 12 28 Graphite à 10 %, plus 0 2 6 à 6 %) reste pour la carte de fin de pomodoro, le seul élément surélevé. En sombre, des ombres noires plus franches, et les contours font le reste.

## Composants

- **Boutons** (`DoneButtonStyle`) : hauteur 32, rayon 6, padding 14.
  - Principal en `actionPrimary`, secondaire sur surface avec contour `borderDefault`, discret en texte seul.
  - Variante `compact` de 26 pour les lignes de réglages.
  - `DoneIconButtonStyle` : bouton carré de 32 (nouvelle tâche, semaines), contour `borderDefault`.
- **Champ** (`doneField`) : hauteur 32, rayon 6, contour `borderControl` ; contour Indigo de 2 au focus.
- **Case à cocher** (`TaskCheckbox`) : carré de 16, rayon 4, contour 1,5. La coche apparaît en filigrane au survol ; cochée, plein `actionPrimary`, et le titre est barré.
- **Puces** : hauteur 20, rayon 4, jamais de contour.
  - `StateChip` : une forme en plus de la couleur, sur un fond léger. Point Indigo « Aujourd'hui » sur teinte active pour une tâche du plan, « Bloquée » sur `stateBlocked`, alerte sur `stateRiskTint`, terminé en texte seul.
  - `InfoChip` : date (calendrier) ou durée (horloge), icône et texte secondaires sans fond ; en texte d'alerte une fois l'échéance dépassée.
  - `PriorityChip` : P1 sur teinte active, P2 en texte actif seul, rien pour P3 et P4.
- **Ligne de tâche** : hauteur 48, rayon 10.
  - Au survol, `surfaceHover` et poignée de déplacement.
  - Puces à droite, espacées de 12, la date avant la durée.
  - Les étapes sont en retrait de 28 par niveau.
- **Élément de navigation** (`NavItem`) : hauteur 32, rayon 6, icône 16, compteur en chiffres tabulaires à droite. Actif en `surfaceSelected` et SemiBold.
- **Bloc réunion** (`MeetingBlock`, `Hatching`) : rayon 6. Hachuré à venir (le temps est pris), plein Indigo en cours, gris une fois passé. La pastille du haut (`MeetingPill`) suit les mêmes règles.
- **Tuile numérotée** (`NumberTile`) : 24, rayon 6. Pleine Indigo pour la place dans le plan, en contour pour un emplacement libre ou en retrait.
- **Sélecteur** (`DoneSegmented`) : piste `bgSunken`, segment choisi sur une surface.
- **Encadré** (`NoticeBox`) : sans contour ; information en `stateActiveTint`, erreur en `stateRiskTint`.

## Navigation

Barre latérale de 228, sur `bgSunken`, avec un trait `borderSubtle` à droite :

- en haut, Focus (⌘1) et Plan du jour (⌘2, avec le nombre de tâches du plan) ;
- au milieu, l'étiquette « Listes », puis l'Inbox (⌘3) et les projets, chacun avec son nombre de tâches ouvertes, et « Nouveau projet » ;
- en bas, Stats (⌘4) et Réglages (⌘,).

Les feux de la fenêtre sont posés sur le haut de la barre. La barre du haut, de 52, porte au centre la pastille de réunion (Focus et Plan du jour), à droite le bouton « + » de la capture rapide (⌘N).

En session (minuteur, pause, interruption, fin), la barre latérale s'efface et revient par-dessus quand la souris touche le bord gauche. Les raccourcis restent actifs.

## Pomodoro

- **Minuteur** : anneau de 280, trait 8, qui se vide dans le sens horaire depuis midi, chiffres fins en `numericXL`.
  - En concentration : Indigo (Pervenche en sombre).
  - À l'arrêt : gris, avec la mention « En pause ».
  - En pause : l'écran passe sur `pomodoroBreakBg` et l'anneau en couleur de pause.
  - Aucune couleur d'alerte, même à la fin.
- **Fin de pomodoro** : carte surélevée de 520 : anneau Indigo coché de 56, « Pomodoro terminé » (ou « Étape terminée »), la durée sur la tâche, puis les actions.
- **Barre de menus** : image « template » du système, qui prend la couleur de la barre de menus.
  - Concentration : mini-anneau de 16 rendu à la volée, et temps restant en chiffres tabulaires.
  - Arrêt et pause : icônes pause et tasse.
  - Fin : anneau plein et « Fini ».
- **Panneau de la barre de menus** : 300 de large, sur `bgCanvas`. En haut, la capture : `Eyebrow` « Nouvelle tâche », champ `doneField`, menu « Dans : Inbox » en `callout` et, après un ajout, « Ajoutée dans … » en `caption` secondaire. Un `Hairline`, puis la session en cours et les boutons.

## Logo

Carré arrondi en dégradé, d'Indigo 400 (#5A68C0) en haut à Indigo 700 (#313B7C) en bas, avec un anneau blanc à 28 % et un arc blanc de 330° partant du haut : un minuteur presque refermé. Les exports v4 et v5 ne dessinent pas de logo : c'est celui de la v3, passé dans la palette indigo.

- Source vectorielle : `docs/design/icon.svg`.
- Dans l'app : `DoneAppIcon`, l'asset `AppIcon` (Dock et Finder) et l'asset `DoneGlyph`, image « template » de la navigation et de la barre de menus.
- La couleur d'accent du système (`AccentColor`) reprend `stateActive` : #4F5CB0, #5A68C0 en sombre.

## Écarts assumés avec l'export Claude Design (v4)

- **Habillage seul.** Les composants des fonctions retirées de Done ne sont pas utilisés :
  - cartes de chantier, file d'attente, barre de capacité ;
  - puces « En file », « En attente », « À risque », « Surcharge » ;
  - réunions sur une frise horaire.
  
  Leurs tokens restent documentés dans la source.
- **Cycle de 4 pomodoros non adopté.** Les durées restent celles de Done (15, 25 ou 50 min selon le type, pause de 5 ou 10 min).
- **Fin de pomodoro adaptée.** La carte garde les actions de Done (cocher, encore 5 min, pause, bloqué, arrêter) au lieu de « Pause de 5 min » et « Continuer 25 min ».
- **Composants ajoutés, absents de la source** : puce de priorité, tuile numérotée du plan, sélecteur, stepper des réglages, repère « Encore N étapes ». Ils reprennent les puces, rayons et couleurs du système.
- **Navigation adaptée à Done.** La source montrait Aujourd'hui, Chantiers, File d'attente, En attente et Terminé ; la barre latérale de Done porte Focus, Plan du jour, Inbox, projets, Stats et Réglages.
- **Palette, typographie et ornements revus en v5.** Neutres froids au lieu des neutres chauds, Archivo au lieu d'Instrument Sans et d'IBM Plex Mono, étiquettes en casse normale, puces sans fond ni contour, cartes sans ombre, lignes de 48, case à cocher de 16, anneau du minuteur au trait de 8.
- **Focus clavier.** Les boutons utilisent l'anneau de focus du système, en Indigo grâce à `AccentColor`, plutôt qu'un anneau dessiné.
