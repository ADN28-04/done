# NavItem

Élément de la barre latérale : icône de 16, titre, compteur en chiffres tabulaires à droite, chevron pour un projet qui a des sous-projets.

Rendu web écrit à la main à partir de `NavItem` dans `Done/Views/Theme.swift`.

## États

- Repos : transparent, titre `body` en `textPrimary`.
- Survol : `surfaceHover`.
- Actif : `surfaceSelected` (une feuille de vert) et titre en SemiBold.
- « Aujourd'hui » garde son soleil en `sunText`, même au repos.
- Cible de dépôt : contour `border-focus` (2) en `focusRing` (dernier élément de l'aperçu).
- Désactivé : `textDisabled`.

## Mesures

`control-height` (32), rayon `sm` (10), marge et espace `s8`, compteur `numericS` en `textSecondary`, chevron de 9. Les sous-projets sont en retrait de `s16`. La barre fait `sidebar-width` (228) sur `bgSunken`, avec un trait `borderSubtle` à droite et des titres de section en `Eyebrow`.

## Ce que fournit l'appelant

Le titre, l'icône (image « template »), le compteur éventuel, l'état choisi, `isDropTarget`, et `isExpanded` avec `onToggle` pour un projet qui a des sous-projets. Le chevron replie sans ouvrir la liste.
