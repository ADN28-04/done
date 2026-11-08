# IconButton

Bouton rond de 34 qui ne porte qu'une icône : nouvelle tâche, semaine précédente ou suivante.

Rendu web écrit à la main à partir de `DoneIconButtonStyle` dans `Done/Views/Theme.swift`, revu pour la direction Mymind.

## Mesures

- 34 × 34 (`control-height`), rayon `pill`, contour 1 `borderDefault` sur `surfaceDefault`.
- Icône de 14 en `textPrimary`. Survol : `surfaceHover`. Appui : `scale(.94)`.
- Désactivé : icône `textDisabled`, contour `borderSubtle`.

## Ce que fournit l'appelant

Le symbole, l'action et une aide qui dit ce que fait le bouton.
