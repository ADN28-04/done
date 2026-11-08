# StateChip

Puce d'état d'une tâche : une pilule sur teinte, une icône en plus de la couleur, jamais de contour.

Rendu web écrit à la main à partir de `StateChip` dans `Done/Views/Theme.swift`, revu pour la direction Mymind.

## Genres

- `today` : petit soleil, `accentText` sur `accentTint`. « Aujourd'hui ».
- `done` : coche, `successText` sur `successTint`. Une tâche qu'on vient de cocher ; elle arrive avec le rebond `ease-spring`.
- `blocked` : interdit, `stateOnBlocked` sur `stateBlocked`.
- `risk` : triangle, `stateRiskText` sur `stateRiskTint`. Échéance dépassée seulement.
- `past` : coche et texte `stateOnDone`, sans fond.

## Mesures

`chip-height` (22), rayon `pill`, marge 9, icône de 10, texte Nunito Sans 12 SemiBold.

## Ce que fournit l'appelant

Le genre et un titre d'un ou deux mots. L'icône double toujours la couleur.
