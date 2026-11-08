# NoteCard

Tuile d'une note dans la mosaïque (Ma journée, écran Notes) : étiquette de type en contour, titre en serif, extrait.

Composant ajouté par la direction Mymind, inspiré de la grille de mymind.

## Types, teintes et étiquettes

| Type | Teinte de carte | Étiquette |
| --- | --- | --- |
| Journal | `cardBlush` | `tagYellow` |
| Réunion | `cardSlate` | `stateActiveText` |
| Décision | `surfaceDefault` | `tagPink` |
| Personne | `cardSage` | `successText` |
| Référence | `cardParchment` | `textSecondary` |
| Note | `surfaceDefault` | `accentText` |

## Règles

- Titre en `noteTitle` (Newsreader 17/22), extrait en `callout` `textSecondary`, trois lignes au plus.
- Le journal et les notes rapides montrent leur texte en `noteMono` (Courier Prime), comme un brouillon.
- Les cases d'une note restent cliquables dans la tuile.
- La tuile « Nouvelle note… » en pointillé `stateWaiting` ferme la mosaïque.
- Mosaïque en colonnes (`.d-masonry`), écart 10 ; deux colonnes dans Ma journée, quatre dans l'écran Notes.

## Mesures

Rayon `md` (18), marge 14 × 16, étiquette `chip-height` (22).

## Ce que fournit l'appelant

Le type, le titre, l'extrait, les cases éventuelles et l'action d'ouverture.
