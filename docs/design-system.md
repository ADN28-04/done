# Design system : Done

Source : `docs/design/Done-Ecrans-v9.html` (export Claude Design, version 9 « Verre » : fondations et 10 écrans, clair et sombre). Ouvrir le fichier dans un navigateur pour voir les maquettes. Dans le code, tout passe par `Done/Views/Theme.swift`.

L'esprit : fidèle à macOS 26. Les contrôles et la barre de navigation sont en verre et flottent en bas de la fenêtre, au-dessus d'un fond légèrement teinté sarcelle. Pendant une session, il ne reste que la tâche et le minuteur.

## Couleurs

| Rôle | Clair | Sombre | Dans le code |
|---|---|---|---|
| Texte principal | #1D1D1F | #EEF1F1 | `Theme.label` |
| Texte secondaire | #5C6367 | #9AA2A5 | `Theme.label2` |
| Texte tertiaire | #A3AAAD | #5C6467 | `Theme.label3` |
| Surface (cartes, listes) | blanc à 78 % | blanc à 6 % | `Theme.surface` |
| Verre des grands panneaux | blanc à 52 % | #262C2E à 48 % | `Theme.glass` |
| Verre des boutons | blanc à 62 % | blanc à 10 % | `Theme.glassButton` |
| Survol, pastilles inactives | #002828 à 6 % | blanc à 7 % | `Theme.fill` |
| Piste des anneaux et jauges | #004646 à 12 % | blanc à 12 % | `Theme.track` |
| Séparateurs | noir à 8 % | blanc à 9 % | `Theme.separator` |
| Accent (fond des boutons principaux) | #0A7D72 | #148075 | `Theme.accent`, asset `AccentColor` |
| Anneaux, barres, pastilles de progression | #0A7D72 | #2BA597 | `Theme.ring` |
| Fond teinté accent | #0A7D72 à 12 % | #2BA597 à 18 % | `Theme.accentTint` |
| Onglet sélectionné | #0A7D72 à 14 % | #2BA597 à 22 % | `Theme.selection` |
| Texte accent | #086A61 | #73D6C9 | `Theme.accentText` |
| Contrainte de temps, dépassement | #9A5200 sur #EB8909 à 12 % | #FFB340 sur #FF9F0A à 16 % | `Theme.orangeText`, `Theme.orangeTint` |
| Erreur | #B3261E sur #D1453B à 12 % | #FF8A80 sur #FF6F61 à 16 % | `Theme.redText`, `Theme.redTint` |
| P1 / P2 / P3 / P4 | #D1453B / #EB8909 / #246FE0 / #8E8E93 | #FF6F61 / #FF9F0A / #5B9BFF / #9A9A9F | `Theme.priority(_:)` |

Règles : le rouge est réservé à P1 et aux erreurs, l'orange aux contraintes de temps et aux cibles dépassées. Le texte sur un bouton principal est blanc.

## Fonds

Chaque moment a son fond (`Backdrop(style:)`) : une teinte de base et un halo radial.

| Style | Moment | Base clair / sombre | Halo |
|---|---|---|---|
| `wash` | Navigation, feuilles, barre de menus | #F2F5F5 / #111515 | sarcelle en haut à gauche, léger en bas à droite |
| `session` | Minuteur en cours ou en pause | #EBF1F0 / #0E1313 | sarcelle au centre |
| `finished` | Fin de session | #EDF3F2 / #0F1414 | sarcelle, plus haut |
| `rest` | Pause café | #F6F4EF / #15140F | sable |
| `interruption` | Interruption | #F1F2F3 / #131415 | gris |

## Typographie

Trois familles, embarquées dans `Done/Fonts` (instances statiques tirées des polices variables de Google Fonts, licences OFL dans `docs/fonts/`) et chargées au lancement par `FontLoader`.

- **Plus Jakarta Sans** (`Font.display(_:bold:)`) pour les titres : action de l'écran Focus en 42 pt semibold, titre de session 26 pt, titres de page 30 pt bold, « Session terminée » 36 pt bold, interlettrage -0,015 em.
- **DM Mono** (`Font.mono(_:medium:)`) pour les chiffres et les étiquettes : minuteur 80 pt en session, 88 pt en interruption, 72 pt en pause, 40 pt dans la barre de menus, interlettrage -0,04 em (`TimerText`). Chiffre clé des stats 64 pt. Légendes en capitales 11 pt, interlettrage 0,04 em (`Eyebrow`). Badges de priorité 10 pt.
- **DM Sans** (`Font.text(_:_:)`) pour le texte courant : 13 pt par défaut (fixé sur la fenêtre), 14 à 15 pt dans les listes et les sous-titres.

Les symboles SF gardent `.font(.system(size:))`.

## Composants

- **Surface** (`surface(radius:)`) : carte opaque pour les listes, graphiques et réglages. Coins de 16 à 18 pt, liseré de 0,5 pt, ombre douce.
- **Verre** : `glassBackground(_:)` pour les boutons secondaires, la pastille de réunion et les sélecteurs ; `liquidGlass(_:)` pour la barre d'onglets, en Liquid Glass (`glassEffect`) sur macOS 26 compilé avec Xcode 26, en verre dessiné sinon (flou, voile clair, liseré lumineux, ombre).
- **Boutons** (`PillButtonStyle`) : pilules de 40 pt pour les actions des écrans, 32 pt dans les barres et panneaux, 28 pt dans les lignes de réglages. Principal en accent, texte blanc semibold ; secondaire en verre ; discret en texte seul.
- **Bouton rond en verre** (`RoundGlassButtonStyle`) : 32 pt, pour rafraîchir et changer de semaine.
- **Sélecteur en verre** (`GlassSegmented`) : capsule de verre, segment choisi en accent. Onglets Focus et Backlog des stats, choix Actif ou En attente du garde-fou, Demain ou Plus tard du bilan.
- **Stepper en verre** (`GlassStepper`), **pastilles** (`Chip`) et **trait** (`Hairline`) pour les réglages.
- **Badge de priorité** : 16 pt de haut, coins 4, contour de la couleur de priorité, fond à 15 %.
- **Pastille de réunion** : en haut au centre, en verre. Point plein pour une réunion en cours, point accent pour un bloc de travail, point évidé pour la prochaine réunion.
- **Anneau** (`ProgressRing`) : la part restante, partant du haut, dans le sens horaire. 320 pt et trait de 14 pt en session, 280 pt et trait de 12 pt en pause. Gris quand le minuteur est en pause.
- **Encadré** (`NoticeBox`) : orange pour une contrainte de temps, rouge pour une erreur.
- **Note de reprise** : champ « Où tu en es ? » (`ResumeNoteField`), surface de 40 pt aux coins de 12, liseré `ring` quand il a le focus ; rappel sur l'écran Focus (`ResumeNoteCard`), légende « Où tu en étais » et texte de 15 pt sur une surface.

## Navigation

- **Barre du haut** de 60 pt, dans la zone de titre : les feux de la fenêtre à gauche, au centre la pastille de réunion (Focus et Plan du jour) ou le sélecteur Focus/Backlog (Stats), à droite le bouton rafraîchir (⌘R).
- **Barre d'onglets** flottante centrée en bas (`FloatingTabBar` dans `RootView.swift`), à 16 pt du bas : pilule en verre de 5 pt de marge intérieure, onglets de 40 pt de haut avec icône et libellé de 13 pt. L'onglet actif est en texte accent semibold sur une capsule `selection` qui glisse d'un onglet à l'autre. Raccourcis ⌘1 à ⌘4.
- **En session** (minuteur, pause, interruption, fin de session, pause café) : la barre d'onglets et le bouton rafraîchir disparaissent. La barre d'onglets revient quand la souris approche du bas de la fenêtre. Seule la réunion en cours reste affichée pendant une interruption.

## Logo

Carré arrondi en dégradé (#16988C vers #0A7D72), anneau blanc à 28 % et arc blanc de 330° partant du haut : un minuteur presque refermé. Source vectorielle : `docs/design/icon.svg`. Dans l'app : `DoneAppIcon` (écran de connexion), l'asset `AppIcon` (Dock et Finder) et l'asset `DoneGlyph`, une image « template » utilisée dans la barre de menus et dans l'onglet Focus. Source du glyphe : `docs/design/glyph.svg`.

## Écarts assumés avec la maquette

- L'écran Focus garde ce que la maquette ne montre pas : le titre de la tâche parente, le choix de la durée, « Passer », « Découper en une première action » et l'invitation au bilan du soir.
- L'interruption garde « Insérer une tâche urgente », la barre de menus garde « Quitter Done ».
- Les réglages gardent toutes les options réelles de l'app (durées par label, nombre de tâches par jour, mots-clés des blocs, bilan du soir, Ne pas déranger). La maquette montrait une version simplifiée.
- Les stats affichent le nombre d'interruptions dans la légende du chiffre clé, sans carte dédiée. L'onglet Backlog, absent de la maquette, reprend les mêmes cartes.
- Les feuilles (découpage, garde-fou, bilan du soir), absentes de la maquette, reprennent le fond `wash`, les surfaces et les boutons des écrans.
- La note de reprise (écrans Fin de session, Interruption, Focus et Session), la section « Statut Teams » et les réglages « Réunion proche » ne figurent pas dans la maquette : ils reprennent les champs, surfaces et lignes de réglages existants.
- Le menu « Interrompre » est un popover stylé plutôt qu'un menu système, pour garder le style pilule.
