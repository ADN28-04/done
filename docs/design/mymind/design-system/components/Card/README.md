# Card

Carte widget : une surface blanche qui flotte sur la toile, avec un liseré, une ombre très douce et un en-tête « étiquette à gauche, lien à droite ».

Rendu web écrit à la main à partir de `doneCard`, `doneRaised`, `Hairline` et `Eyebrow` dans `Done/Views/Theme.swift`, revu pour la direction Mymind.

## Genres

- Carte widget (`.d-card`) : `surfaceDefault`, contour 1 `borderSubtle`, ombre `shadowCard`, rayon `lg` (24), marge 20 × 22. Tous les blocs de Ma journée.
- En-tête (`.d-widget__head`) : `Eyebrow` à gauche (style `label`, `textSecondary`), lien à droite en `stateActiveText` qui ouvre l'écran complet (« Calendrier », « Toutes les notes », « Stats »).
- À plat (`.d-card--flat`) : sans ombre, dans une feuille ou une carte.
- Surélevée (`.d-card--raised`) : ombre `shadowRaised`. Carte de fin de pomodoro et saisie flottante seulement.
- `Hairline` et `Eyebrow` comme avant.

## Ce que fournit l'appelant

L'étiquette, le lien éventuel et le contenu. Un grand chiffre de widget prend `numericL`.
