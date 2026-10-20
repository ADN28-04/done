# Design system : Done

Source : `docs/design/Done-Ecrans.html` (export Claude Design, 10 écrans, 23 états, clair et sombre). Ouvrir le fichier dans un navigateur pour voir les maquettes. Dans le code, tout passe par `Done/Views/Theme.swift`.

## Couleurs

| Rôle | Clair | Sombre | Dans le code |
|---|---|---|---|
| Fond de fenêtre | #ECECEC | #1E1E1E | `Theme.background` |
| Surface (cartes, listes) | #FFFFFF | #2C2C2E | `Theme.surface` |
| Texte principal | #1D1D1F | #EDEDEF | `Theme.label` |
| Texte secondaire | #6E6E73 | #98989D | `Theme.label2` |
| Texte tertiaire | #AEAEB2 | #636366 | `Theme.label3` |
| Boutons secondaires, survol | #E3E3E6 | #3A3A3C | `Theme.fill` |
| Piste des anneaux et jauges | #DADADE | #333335 | `Theme.track` |
| Séparateurs | #E2E2E5 | #38383A | `Theme.separator` |
| Accent | #0A7D72 | #2BA597 | `Theme.accent`, asset `AccentColor` |
| Fond teinté accent | #DAEEEB | #163A35 | `Theme.accentTint` |
| Texte accent | #086A61 | #6FD3C6 | `Theme.accentText` |
| Contrainte de temps, dépassement | #9A5200 sur #FDF0DF | #FFB340 sur #3A2A12 | `Theme.orangeText`, `Theme.orangeTint` |
| Erreur | #B3261E sur #FBE7E5 | #FF8A80 sur #3B1F1D | `Theme.redText`, `Theme.redTint` |
| P1 / P2 / P3 / P4 | #D1453B / #EB8909 / #246FE0 / #8E8E93 | #FF6F61 / #FF9F0A / #5B9BFF / #9A9A9F | `Theme.priority(_:)` |

Règles : le rouge est réservé à P1 et aux erreurs, l'orange aux contraintes de temps et aux cibles dépassées.

## Typographie

- SF Pro partout, 13 pt par défaut.
- Action de la carte Focus et de la session : 30 pt semibold, interlettrage -0,01 em.
- Titres de carte : 22 pt semibold. Titre de page (Plan du jour) : 26 pt bold.
- Légendes en capitales (« TÂCHE 2 SUR 3 · … ») : 11 pt semibold, interlettrage 0,06 em, `Eyebrow`.
- Minuteur : SF Pro Rounded semibold à chasse fixe, 72 pt dans la fenêtre, 34 pt dans la barre de menus (`Font.timer(_:)`).
- Chiffres qui changent : toujours `monospacedDigit()`.

## Composants

- **Carte Focus** : 560 pt de large, padding 32, coins 20, ombre douce (`cardStyle()`).
- **Panneau** (listes, tuiles, graphiques) : coins 12, padding 16, sans ombre (`panelStyle()`).
- **Boutons** : pilules de 32 pt de haut, padding horizontal 16 (`PillButtonStyle`). Principal en accent avec texte blanc semibold, secondaire en `fill`, discret sans fond. Raccourci affiché en discret à droite du titre (`ShortcutLabel`).
- **Badge de priorité** : 16 pt de haut, coins 4, contour de la couleur de priorité, fond à 15 %.
- **Bandeau de réunion** : bloc de travail en accent teinté, réunion en cours en gris, prochaine réunion sans fond avec un point évidé.
- **Anneau** : la part restante, partant du haut, dans le sens horaire. 280 pt, trait 12 pt. Gris quand le minuteur est en pause.
- **Agenda du jour** : pastilles de créneau, blocs de travail en accent teinté, créneaux passés à 45 % d'opacité, repère vertical pour l'heure actuelle.

## Logo

Carré arrondi en dégradé (#16988C vers #0A7D72), anneau blanc à 28 % et arc blanc de 330° partant du haut : un minuteur presque refermé. Source vectorielle : `docs/design/icon.svg`. Dans l'app : `DoneAppIcon` (écran de connexion), l'asset `AppIcon` (Dock et Finder) et l'asset `DoneGlyph`, une image « template » utilisée dans la barre de menus et, teintée en accent, dans la barre latérale. Source du glyphe : `docs/design/glyph.svg`.

## Écarts assumés avec la maquette

- Les réglages gardent toutes les options réelles de l'app (durées par label, mots-clés des blocs, Ne pas déranger). La maquette montrait une version simplifiée.
- Les interrupteurs « Notifications : fin de session / réunion proche » de la maquette ne sont pas codés : la notification de réunion proche est une nouvelle fonctionnalité, rangée dans « Plus tard ».
- Le menu « Interrompre » est un popover stylé plutôt qu'un menu système, pour garder le style pilule.
