# PriorityChip

Priorité d'une tâche : « P1 » sur teinte active, « P2 » en texte actif seul, rien pour P3 et P4.

Rendu web écrit à la main à partir de `PriorityChip` dans `Done/Views/Theme.swift`. Composant propre à Done, absent de l'export Claude Design.

## Mesures

- `chip-height` (22), texte Nunito Sans 12 en chiffres tabulaires, `stateActiveText`.
- P1 : SemiBold, marge `s8`, rayon `pill`, fond `stateActiveTint`.
- P2 : Medium, sans fond ni marge.

## Ce que fournit l'appelant

La priorité, de 1 à 4. Placée en premier dans les puces d'une ligne. L'aide dit « Priorité 1 » ou « Priorité 2 ».
