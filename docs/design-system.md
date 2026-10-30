# Design system : Done

Source : `docs/design/Done-Design-System-v3.html`. C'est l'export Claude Design de la v3 (octobre 2026) : palette, tokens, contrastes, typographie, mesures, composants et pomodoro, en clair et en sombre. Ouvrir le fichier dans un navigateur pour le voir. Dans le code, tout passe par `Done/Views/Theme.swift`.

L'esprit : Done ressemble à un carnet tenu à l'encre de nuit. Un papier lavande, des violets qui s'intensifient à mesure que le travail avance, et une seule couleur chaude réservée aux vraies alertes. Le temps pris est hachuré, le travail en cours est violet, et tout le reste se tait. Des rayons petits et des bordures fines : c'est un outil de précision. Pas de verre ni de halo.

## Couleurs

Cinq violets et une alerte : Nuit #11002C, Aubergine #3B0A6C, Violet #7B2CBE, Lilas #C67EFF, Lavande #E0ABFE, Alerte #F0446C. Le code ne les cite jamais directement : il utilise des rôles (`DoneColor`), qui changent de valeur entre clair et sombre.

| Rôle | Clair | Sombre | Usage |
|---|---|---|---|
| `bgCanvas` | #FBF7FF | #11002C | Fond de fenêtre |
| `bgSunken` | #F2EAFB | #0B001F | Barre latérale, puces neutres, piste des sélecteurs |
| `surfaceDefault` | #FFFFFF | #1C0838 | Cartes, lignes, champs |
| `surfaceHover` | #F6EEFE | #261047 | Survol |
| `surfaceSelected` | #F1DEFE | #3B0A6C | Navigation active |
| `borderSubtle` | #E8DFF2 | #2B1748 | Séparateurs, contours de carte |
| `borderDefault` | #D4C6E3 | #3E2662 | Tuile numérotée vide |
| `borderControl` | #8F7BA6 | #8A74A8 | Champs, cases, bouton secondaire (3:1) |
| `textPrimary` | #11002C | #F7F0FF | Texte principal |
| `textSecondary` | #5E4A78 | #C3B0DC | Métadonnées, légendes |
| `textDisabled` | #B3A6C4 | #5E4A7A | Désactivé |
| `actionPrimary` (survol, appui) | #3B0A6C (#52178F, #2A0650) | #E0ABFE (#EBC6FF, #D194FB) | Bouton principal |
| `actionOnPrimary` | #FFFFFF | #11002C | Texte sur bouton principal |
| `actionDisabled` | #ECE4F5 | #2A1648 | Fond de bouton désactivé |
| `focusRing` | #7B2CBE | #C67EFF | Focus, cible de dépôt, champ actif |
| `stateActive` | #7B2CBE | #8A3FD1 | Plein actif : priorité 1, tuile du plan, barres |
| `stateActiveText` | #7B2CBE | #C67EFF | Texte actif, priorité 2 |
| `stateActiveTint` | #EFE2FA | #2E1252 | Fond léger : encadré d'information, repère d'étapes |
| `stateBlocked` / `stateOnBlocked` | #ECE6F2 / #11002C | #2A1748 / #F7F0FF | Puce « Bloquée » |
| `stateWaiting` | #8F7BA6 | #8A74A8 | Contour pointillé : emplacement libre, liste vide |
| `stateRisk`, `stateRiskTint`, `stateRiskText` | #F0446C, #FDEAF0, #B81D48 | #F0446C, #3D0A2E, #FF8FAB | Alerte : échéance dépassée, erreur |
| `stateDone` / `stateOnDone` | #F0EBF5 / #5E4A78 | #1A0833 / #C3B0DC | Terminé : recule visuellement |
| `meetingBg`, `meetingHatch` | #F1ECF7, Aubergine à 16 % | #22103F, Lavande à 16 % | Réunion à venir, hachurée |
| `meetingNow` / `meetingOnNow` | #3B0A6C / #FFFFFF | #E0ABFE / #11002C | Réunion en cours |
| `pomodoroFocus` | #7B2CBE | #C67EFF | Anneau de concentration |
| `pomodoroBreak` | #A453EC | #E0ABFE | Anneau de pause |
| `pomodoroBreakBg` | #F6ECFF | #1E0A3D | Fond de l'écran pendant la pause |
| `pomodoroTrack` | #EADFF5 | #2B1748 | Piste des anneaux et des barres |
| `pomodoroPaused` | #B3A6C4 | #5E4A7A | Anneau à l'arrêt |

Règles :

- La couleur d'alerte n'apparaît que pour une échéance dépassée et pour les erreurs.
- Lilas et Lavande ne sont jamais du texte en clair.
- Il y a un seul bouton principal par vue.
- Toutes les combinaisons texte et fond passent AA (4,5:1). Le tableau des contrastes est dans la source.

## Typographie

Deux familles, embarquées dans `Done/Fonts` (instances statiques des polices variables de Google Fonts, licences OFL dans `docs/fonts/`) et chargées au lancement par `FontLoader` :

- **Bricolage Grotesque** pour l'affichage ;
- **IBM Plex Sans** pour le texte et tous les nombres. Ses chiffres sont à chasse fixe par défaut : le minuteur ne bouge pas en largeur.

Dans le code, `.doneText(.style)` applique la police, l'interlignage, l'interlettrage et les capitales. `Font.plex(taille, graisse)` sert hors échelle (boutons, navigation active).

| Style | Police | Taille / interligne | Usage |
|---|---|---|---|
| `displayXL` | Bricolage Bold, -0,025 em | 44/48 | L'action proposée sur l'écran Focus |
| `displayL` | Bricolage Bold, -0,02 em | 32/36 | Titres d'écran |
| `displayM` | Bricolage SemiBold, -0,01 em | 22/28 | Titres de feuille, de carte, tâche en session |
| `title` | Plex SemiBold | 17/24 | Titre de panneau, tâche parente |
| `body` / `bodyStrong` | Plex Regular / Medium | 14/20 | Texte courant / titre de tâche |
| `callout` | Plex Regular | 13/18 | Texte d'appoint |
| `caption` | Plex Regular | 12/16 | Métadonnées |
| `label` | Plex SemiBold, +0,06 em, capitales | 11/14 | Étiquettes (`Eyebrow`) |
| `numericXL` | Plex Medium, -0,02 em | 56/60 | Minuteur, total de la semaine |
| `numericL` | Plex SemiBold, -0,01 em | 28/32 | Totaux, minuteur de la barre de menus |
| `numericM` / `numericS` | Plex Medium | 14/20, 12/16 | Valeurs en ligne / puces |

Formats : « 1 h 30 », « 45 min », « 14:00 », minuteur « 18:42 », date courte « mar. 3 nov. », dates relatives « Auj. », « Demain », « Hier » (`Format.chipDate`).

## Mesures

- **Espacements** (`DoneSpace`) : grille de 4, avec 2 et 6 pour les détails. 8 entre lignes, 12 dans une ligne, 16 dans une carte, 24 pour les marges de panneau, 32 entre sections, 40 pour les marges d'écran.
- **Rayons** (`DoneRadius`) : 3 pour les puces, 6 pour les boutons, champs, réunions et la navigation, 10 pour les lignes et les cartes, 14 pour les panneaux et les feuilles.
- **Bordures** : 1 pt `borderSubtle` (cartes), 1 pt `borderControl` (champs, secondaire), 1,5 pt pour la case à cocher, 1,5 pt pointillé `stateWaiting` (emplacement libre), 2 pt `focusRing` (focus, cible de dépôt).
- **Ombres** : `doneCard` (0 1 2, Nuit à 8 %) pour les cartes ; `doneRaised` (0 12 28 Aubergine à 16 %, plus 0 2 6) pour la carte de fin de pomodoro. En sombre, les contours font le travail.

## Composants

- **Boutons** (`DoneButtonStyle`) : hauteur 32, rayon 6, padding 14.
  - Principal en `actionPrimary`, secondaire avec contour `borderControl`, discret en texte seul.
  - Variante `compact` de 26 pour les lignes de réglages.
  - `DoneIconButtonStyle` : bouton carré de 32 (nouvelle tâche, semaines).
- **Champ** (`doneField`) : hauteur 32, rayon 6, contour `borderControl` ; contour Violet de 2 au focus.
- **Case à cocher** (`TaskCheckbox`) : carré de 18, rayon 5, contour 1,5. La coche apparaît en filigrane au survol ; cochée, plein `actionPrimary`, et le titre est barré.
- **Puces** :
  - `StateChip` : hauteur 22, rayon 3, une forme en plus de la couleur. Point plein « Aujourd'hui » pour une tâche du plan, « Bloquée », alerte, terminé.
  - `InfoChip` : hauteur 24, date (calendrier) ou durée (horloge), en alerte une fois l'échéance dépassée.
  - `PriorityChip` : P1 en Violet plein, P2 en contour Violet, rien pour P3 et P4.
- **Ligne de tâche** : hauteur 52, rayon 10.
  - Au survol, `surfaceHover` et poignée de déplacement.
  - Puces à droite, la date avant la durée.
  - Les étapes sont en retrait de 28 par niveau.
- **Élément de navigation** (`NavItem`) : hauteur 32, rayon 6, icône 16, compteur tabulaire à droite. Actif en `surfaceSelected` et SemiBold.
- **Bloc réunion** (`MeetingBlock`, `Hatching`) : rayon 6. Hachuré à venir (le temps est pris), plein Aubergine en cours, gris une fois passé. La pastille du haut (`MeetingPill`) suit les mêmes règles.
- **Tuile numérotée** (`NumberTile`) : 24, rayon 6. Pleine Violet pour la place dans le plan, en contour pour un emplacement libre ou en retrait.
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
  - En concentration : Violet.
  - À l'arrêt : gris, avec la mention « En pause ».
  - En pause : l'écran passe sur `pomodoroBreakBg` et l'anneau en couleur de pause.
  - Aucune couleur d'alerte, même à la fin.
- **Fin de pomodoro** : carte surélevée de 520 : anneau Violet coché de 56, « Pomodoro terminé » (ou « Étape terminée »), la durée sur la tâche, puis les actions.
- **Barre de menus** : image « template » du système, qui prend la couleur de la barre de menus.
  - Concentration : mini-anneau de 16 rendu à la volée, et temps restant en chiffres tabulaires.
  - Arrêt et pause : icônes pause et tasse.
  - Fin : anneau plein et « Fini ».

## Logo

Carré arrondi en dégradé, de Violet 500 (#8A3FD1) en haut à Aubergine (#3B0A6C) en bas, avec un anneau blanc à 28 % et un arc blanc de 330° partant du haut : un minuteur presque refermé.

- Source vectorielle : `docs/design/icon.svg`.
- Dans l'app : `DoneAppIcon`, l'asset `AppIcon` (Dock et Finder) et l'asset `DoneGlyph`, image « template » de la navigation et de la barre de menus.
- La couleur d'accent du système (`AccentColor`) est Violet, Violet 500 en sombre.

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
- **Focus clavier.** Les boutons utilisent l'anneau de focus du système, en Violet grâce à `AccentColor`, plutôt qu'un anneau dessiné.
