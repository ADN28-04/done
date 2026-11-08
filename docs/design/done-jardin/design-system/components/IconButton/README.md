# IconButton

Bouton carré de 32 qui ne porte qu'une icône : nouvelle tâche, semaine précédente ou suivante.

Rendu web écrit à la main à partir de `DoneIconButtonStyle` dans `Done/Views/Theme.swift`.

## Mesures

- 32 × 32 (`control-height`), rayon `sm` (10), contour 1 `borderDefault` sur `surfaceDefault`.
- Icône 13 SemiBold en `textPrimary`. Survol et appui : `surfaceHover`.
- Désactivé : icône `textDisabled`, contour `borderSubtle`.

## Ce que fournit l'appelant

Le symbole, l'action et une aide (`help`, `aria-label` sur le web) qui dit ce que fait le bouton. Dans l'app, l'icône est un SF Symbol ; l'aperçu le remplace par un tracé simple.
