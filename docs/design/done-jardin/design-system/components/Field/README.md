# Field

Champ de saisie d'une ligne : 32 de haut, contour `borderControl`, contour vert de 2 au focus.

Rendu web écrit à la main à partir du modificateur `doneField(focused:height:)` dans `Done/Views/Theme.swift`.

## Mesures

- Hauteur `control-height` (32), ou 36 pour le champ d'ajout des listes. Rayon `sm` (10).
- Fond `surfaceDefault`, contour 1 `borderControl` (3:1), marge `s8`.
- Texte `body` en `textPrimary` ; texte d'aide en `textSecondary`.
- Focus : contour `border-focus` (2) en `focusRing`.

## Ce que fournit l'appelant

Le texte lié, l'état de focus et un texte d'aide qui dit quoi saisir (« Nouvelle tâche », « Rechercher »). Pas de libellé flottant : l'étiquette éventuelle est un `Eyebrow` au-dessus.
