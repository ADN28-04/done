# StateChip

Puce d'état d'une tâche : une forme en plus de la couleur, sur un fond léger, jamais de contour.

Rendu web écrit à la main à partir de `StateChip` dans `Done/Views/Theme.swift`, revu pour la direction Jardin.

## Genres

- `today` : petit soleil, texte `sunText` sur `sunTint`. Une tâche du plan du jour (« Aujourd'hui »). C'est le genre `active` du code, passé au tournesol.
- `done` : coche, texte `sunText` sur `sunTint`. Une tâche qu'on vient de cocher ; elle apparaît avec le rebond `ease-spring`.
- `blocked` : icône « interdit », texte `stateOnBlocked` sur `stateBlocked`. « Bloquée ».
- `risk` : icône d'alerte, texte `stateRiskText` sur `stateRiskTint`. Échéance dépassée seulement.
- `past` : coche et texte `stateOnDone`, sans fond. Ce qui a été fait un autre jour recule.

## Mesures

`chip-height` (22), rayon `chip` (8), marge `s8`, icône de 10, espace de 5, texte Archivo 12 Medium.

## Mouvement

Une puce qui apparaît après une action (« Fait ») rebondit une fois : `d-pop`, `dur-base`, `ease-spring`. Une puce d'alerte apparaît en fondu, sans rebond.

## Ce que fournit l'appelant

Le genre et un titre d'un ou deux mots en casse normale. La couleur ne porte jamais le sens seule : l'icône le double.
