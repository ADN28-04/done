# NavItem

Élément de la colonne des listes, dans l'écran Listes : icône de 16, titre, compteur, chevron pour un projet qui a des sous-projets.

Rendu web écrit à la main à partir de `NavItem` dans `Done/Views/Theme.swift`, revu pour la direction Mymind. Les écrans principaux passent par le `Rail` ; `NavItem` ne sert plus qu'aux projets, sous-projets, étiquettes et à l'Inbox.

## États

- Repos : transparent, titre `body` en `textPrimary`. Survol : `surfaceHover`.
- Actif : `surfaceSelected` et titre en Bold.
- Cible de dépôt : contour `border-focus` (2) en `focusRing`.

## Mesures

`control-height` (34), rayon `pill`, marge 12, compteur `numericS` en `textSecondary`. La colonne fait `list-sidebar-width` (240) sur `bgSunken`.

## Ce que fournit l'appelant

Le titre, l'icône, le compteur, l'état choisi, `isDropTarget`, `isExpanded` et `onToggle`.
