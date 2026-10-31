# Design system : Done

Source : `docs/design/Done-Design-System-v4.html`. C'est l'export Claude Design de la v4 (octobre 2026) : palette, tokens, contrastes, typographie, mesures, composants et pomodoro, en clair et en sombre. Ouvrir le fichier dans un navigateur pour le voir. Dans le code, tout passe par `Done/Views/Theme.swift`.

La v4 garde les mesures et les composants de la v3. Elle change la palette (des neutres chauds à la place des violets) et les polices (Instrument Sans et IBM Plex Mono).

L'esprit : Done ressemble à un carnet de travail sur papier pierre. Des neutres chauds qui reposent l'œil, un indigo profond pour tout ce qui agit, et une brique réservée aux vraies alertes. Le temps pris est hachuré, le travail en cours est indigo, et tout le reste se tait. Des rayons petits et des bordures fines : c'est un outil de précision. Pas de verre ni de halo.

## Couleurs

Des neutres chauds qui évitent le blanc et le noir purs, un indigo pour ce qui agit, une brique pour les alertes : Encre #26231F, Pierre #F5F3EF, Indigo #4553A0, Indigo 400 #5A68C0, Pervenche #AAB4F2, Brique #B23A35. Le code ne les cite jamais directement : il utilise des rôles (`DoneColor`), qui changent de valeur entre clair et sombre.

| Rôle | Clair | Sombre | Usage |
|---|---|---|---|
| `bgCanvas` | #F5F3EF | #1A1917 | Fond de fenêtre |
| `bgSunken` | #EEEBE5 | #161513 | Barre latérale, puces neutres, piste des sélecteurs |
| `surfaceDefault` | #FBFAF7 | #22201D | Cartes, lignes, champs |
| `surfaceHover` | #F1EEE8 | #2A2825 | Survol |
| `surfaceSelected` | #E6E8F4 | #2A2E4A | Navigation active |
| `borderSubtle` | #E1DCD3 | #35322D | Séparateurs, contours de carte |
| `borderDefault` | #CFC8BC | #45413B | Tuile numérotée vide |
| `borderControl` | #8D857A | #8A8379 | Champs, cases, bouton secondaire (3:1) |
| `textPrimary` | #26231F | #E8E4DD | Texte principal |
| `textSecondary` | #6B645A | #A39C91 | Métadonnées, légendes |
| `textDisabled` | #B2ABA0 | #5E5951 | Désactivé |
| `actionPrimary` (survol, appui) | #4553A0 (#3A4690, #313B7C) | #5A68C0 (#5260B8, #4A57A8) | Bouton principal |
| `actionOnPrimary` | #FFFFFF | #FFFFFF | Texte sur bouton principal |
| `actionDisabled` | #E9E5DE | #2B2925 | Fond de bouton désactivé |
| `focusRing` | #4553A0 | #AAB4F2 | Focus, cible de dépôt, champ actif |
| `stateActive` | #4F5CB0 | #5A68C0 | Plein actif : priorité 1, tuile du plan, barres |
| `stateActiveText` | #3A4690 | #AAB4F2 | Texte actif, priorité 2 |
| `stateActiveTint` | #E6E8F4 | #262A42 | Fond léger : encadré d'information, repère d'étapes |
| `stateBlocked` / `stateOnBlocked` | #E9E5DE / #26231F | #2B2925 / #E8E4DD | Puce « Bloquée » |
| `stateWaiting` | #8D857A | #8A8379 | Contour pointillé : emplacement libre, liste vide |
| `stateRisk`, `stateRiskTint`, `stateRiskText` | #C2463F, #F6E3E1, #A3332E | #E06A63, #3A2321, #F0A29D | Alerte : échéance dépassée, erreur |
| `stateDone` / `stateOnDone` | #EEEBE5 / #6B645A | #1F1E1B / #A39C91 | Terminé : recule visuellement |
| `meetingBg`, `meetingHatch` | #EFECE6, Indigo à 14 % | #24221F, Pervenche à 14 % | Réunion à venir, hachurée |
| `meetingNow` / `meetingOnNow` | #4553A0 / #FFFFFF | #5A68C0 / #FFFFFF | Réunion en cours |
| `pomodoroFocus` | #4553A0 | #8F9BE8 | Anneau de concentration |
| `pomodoroBreak` | #6F7BC2 | #AAB4F2 | Anneau de pause |
| `pomodoroBreakBg` | #ECEEF7 | #1F2133 | Fond de l'écran pendant la pause |
| `pomodoroTrack` | #E6E2DA | #35322D | Piste des anneaux et des barres |
| `pomodoroPaused` | #B2ABA0 | #5E5951 | Anneau à l'arrêt |

Règles :

- La couleur d'alerte n'apparaît que pour une échéance dépassée et pour les erreurs.
- Pervenche n'est jamais du texte en clair (1,80:1 sur le fond).
- Il y a un seul bouton principal par vue.
- Toutes les combinaisons texte et fond passent AA (4,5:1). Le tableau des contrastes est dans la source.

## Typographie

Deux familles, embarquées dans `Done/Fonts` (licences OFL dans `docs/fonts/`) et chargées au lancement par `FontLoader` :

- **Instrument Sans** pour les titres et le texte : Regular, Medium et SemiBold, instances statiques de la police variable de Google Fonts ;
- **IBM Plex Mono** pour les heures, les durées, les dates des puces, les compteurs et le minuteur : Medium et SemiBold. Chaque chiffre a la même largeur, le minuteur ne bouge pas.

Dans le code, `.doneText(.style)` applique la police, l'interlignage, l'interlettrage et les capitales. Hors échelle, `Font.sans(taille, graisse)` sert pour les boutons et la navigation active, `Font.mono(taille, graisse)` pour un chiffre isolé (tuile numérotée). Un libellé (« Bloquée », « Encore 2 étapes ») reste en Instrument Sans, même dans une puce.

| Style | Police | Taille / interligne | Usage |
|---|---|---|---|
| `displayXL` | Instrument SemiBold, -0,025 em | 44/48 | L'action proposée sur l'écran Focus |
| `displayL` | Instrument SemiBold, -0,02 em | 32/36 | Titres d'écran |
| `displayM` | Instrument SemiBold, -0,01 em | 22/28 | Titres de feuille, de carte, tâche en session |
| `title` | Instrument SemiBold | 17/24 | Titre de panneau, tâche parente |
| `body` / `bodyStrong` | Instrument Regular / Medium | 14/20 | Texte courant / titre de tâche |
| `callout` | Instrument Regular | 13/18 | Texte d'appoint |
| `caption` | Instrument Regular | 12/16 | Métadonnées |
| `label` | Instrument SemiBold, +0,06 em, capitales | 11/14 | Étiquettes (`Eyebrow`) |
| `numericXL` | Plex Mono Medium, -0,02 em | 56/60 | Minuteur, total de la semaine |
| `numericL` | Plex Mono SemiBold, -0,01 em | 28/32 | Totaux, minuteur de la barre de menus |
| `numericM` / `numericS` | Plex Mono Medium | 14/20, 12/16 | Valeurs en ligne / puces de date et de durée |

Formats : « 1 h 30 », « 45 min », « 14:00 », minuteur « 18:42 », date courte « mar. 3 nov. », dates relatives « Auj. », « Demain », « Hier » (`Format.chipDate`).

## Mesures

- **Espacements** (`DoneSpace`) : grille de 4, avec 2 et 6 pour les détails. 8 entre lignes, 12 dans une ligne, 16 dans une carte, 24 pour les marges de panneau, 32 entre sections, 40 pour les marges d'écran.
- **Rayons** (`DoneRadius`) : 3 pour les puces, 6 pour les boutons, champs, réunions et la navigation, 10 pour les lignes et les cartes, 14 pour les panneaux et les feuilles.
- **Bordures** : 1 pt `borderSubtle` (cartes), 1 pt `borderControl` (champs, secondaire), 1,5 pt pour la case à cocher, 1,5 pt pointillé `stateWaiting` (emplacement libre), 2 pt `focusRing` (focus, cible de dépôt).
- **Ombres** : `doneCard` (0 1 2, Encre à 6 %) pour les cartes ; `doneRaised` (0 12 28 Encre à 10 %, plus 0 2 6 à 6 %) pour la carte de fin de pomodoro. En sombre, des ombres noires plus franches, et les contours font le reste.

## Composants

- **Boutons** (`DoneButtonStyle`) : hauteur 32, rayon 6, padding 14.
  - Principal en `actionPrimary`, secondaire avec contour `borderControl`, discret en texte seul.
  - Variante `compact` de 26 pour les lignes de réglages.
  - `DoneIconButtonStyle` : bouton carré de 32 (nouvelle tâche, semaines).
- **Champ** (`doneField`) : hauteur 32, rayon 6, contour `borderControl` ; contour Indigo de 2 au focus.
- **Case à cocher** (`TaskCheckbox`) : carré de 18, rayon 5, contour 1,5. La coche apparaît en filigrane au survol ; cochée, plein `actionPrimary`, et le titre est barré.
- **Puces** :
  - `StateChip` : hauteur 22, rayon 3, une forme en plus de la couleur. Point plein « Aujourd'hui » pour une tâche du plan, « Bloquée », alerte, terminé.
  - `InfoChip` : hauteur 24, date (calendrier) ou durée (horloge), en alerte une fois l'échéance dépassée.
  - `PriorityChip` : P1 en Indigo plein, P2 en contour Indigo, rien pour P3 et P4.
- **Ligne de tâche** : hauteur 52, rayon 10.
  - Au survol, `surfaceHover` et poignée de déplacement.
  - Puces à droite, la date avant la durée.
  - Les étapes sont en retrait de 28 par niveau.
- **Élément de navigation** (`NavItem`) : hauteur 32, rayon 6, icône 16, compteur en Plex Mono à droite. Actif en `surfaceSelected` et SemiBold.
- **Bloc réunion** (`MeetingBlock`, `Hatching`) : rayon 6. Hachuré à venir (le temps est pris), plein Indigo en cours, gris une fois passé. La pastille du haut (`MeetingPill`) suit les mêmes règles.
- **Tuile numérotée** (`NumberTile`) : 24, rayon 6. Pleine Indigo pour la place dans le plan, en contour pour un emplacement libre ou en retrait.
- **Sélecteur** (`DoneSegmented`) : piste `bgSunken`, segment choisi sur une surface.
- **Encadré** (`NoticeBox`) : information en `stateActiveTint`, erreur en `stateRiskTint` avec contour Alerte.

## Navigation

Barre latérale de 228, sur `bgSunken`, avec un trait `borderSubtle` à droite :

- en haut, Focus (⌘1) et Plan du jour (⌘2, avec le nombre de tâches du plan) ;
- au milieu, l'étiquette « Listes », puis l'Inbox (⌘3) et les projets, chacun avec son nombre de tâches ouvertes, et « Nouveau projet » ;
- en bas, Stats (⌘4) et Réglages (⌘,).

Les feux de la fenêtre sont posés sur le haut de la barre. La barre du haut, de 52, porte au centre la pastille de réunion (Focus et Plan du jour), à droite le bouton « + » de la capture rapide (⌘N).

En session (minuteur, pause, interruption, fin), la barre latérale s'efface et revient par-dessus quand la souris touche le bord gauche. Les raccourcis restent actifs.

## Pomodoro

- **Minuteur** : anneau de 280, trait 12, qui se vide dans le sens horaire depuis midi, chiffres en `numericXL`.
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

Carré arrondi en dégradé, d'Indigo 400 (#5A68C0) en haut à Indigo 700 (#313B7C) en bas, avec un anneau blanc à 28 % et un arc blanc de 330° partant du haut : un minuteur presque refermé. La source v4 ne dessine pas de logo : c'est celui de la v3, passé dans la palette indigo.

- Source vectorielle : `docs/design/icon.svg`.
- Dans l'app : `DoneAppIcon`, l'asset `AppIcon` (Dock et Finder) et l'asset `DoneGlyph`, image « template » de la navigation et de la barre de menus.
- La couleur d'accent du système (`AccentColor`) reprend `stateActive` : #4F5CB0, #5A68C0 en sombre.

## Écarts assumés avec la source

- **Habillage seul.** Les composants des fonctions retirées de Done ne sont pas utilisés :
  - cartes de chantier, file d'attente, barre de capacité ;
  - puces « En file », « En attente », « À risque », « Surcharge » ;
  - réunions sur une frise horaire.
  
  Leurs tokens restent documentés dans la source.
- **Cycle de 4 pomodoros non adopté.** Les durées restent celles de Done (15, 25 ou 50 min selon le type, pause de 5 ou 10 min).
- **Fin de pomodoro adaptée.** La carte garde les actions de Done (cocher, encore 5 min, pause, bloqué, arrêter) au lieu de « Pause de 5 min » et « Continuer 25 min ».
- **Composants ajoutés, absents de la source** : puce de priorité, tuile numérotée du plan, sélecteur, stepper des réglages, repère « Encore N étapes ». Ils reprennent les puces, rayons et couleurs du système.
- **Navigation adaptée à Done.** La source montrait Aujourd'hui, Chantiers, File d'attente, En attente et Terminé ; la barre latérale de Done porte Focus, Plan du jour, Inbox, projets, Stats et Réglages.
- **Focus clavier.** Les boutons utilisent l'anneau de focus du système, en Indigo grâce à `AccentColor`, plutôt qu'un anneau dessiné.
