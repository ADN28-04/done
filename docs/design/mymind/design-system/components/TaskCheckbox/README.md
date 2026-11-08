# TaskCheckbox

Case à cocher d'une tâche : carré de 18 qui se remplit d'encre et rebondit quand la tâche est faite.

Rendu web écrit à la main à partir de `TaskCheckbox` dans `Done/Views/Theme.swift`, revu pour la direction Mymind.

## États

- Ouverte : `surfaceDefault`, contour `border-checkbox` (1,5) en `borderControl`.
- Survol : la coche apparaît en filigrane, en `borderControl`.
- Appui : la case se tasse (`scale(.88)`, `dur-instant`).
- Cochée : plein `actionPrimary`, coche `actionOnPrimary`, et le titre de la ligne se barre.
- Désactivée : fond `actionDisabled`, contour `borderSubtle`.

## Mouvement

Au moment où l'on coche : la case rebondit (`d-pop`, 0,6 → 1,14 → 1, `dur-base`, `ease-spring`) et la coche se trace en `dur-fast`, 60 ms plus tard. En SwiftUI : `.spring(response: 0.3, dampingFraction: 0.55)` sur l'échelle et `.trim` animé sur la coche. On ne rejoue rien quand on rouvre.

## Mesures

`checkbox-size` (18), rayon `xs` (6), coche de 10 en gras.

## Ce que fournit l'appelant

L'état (`isDone`) et l'action. L'aide dit « Cocher » ou « Rouvrir ». Sert aussi aux cases des notes Markdown.
