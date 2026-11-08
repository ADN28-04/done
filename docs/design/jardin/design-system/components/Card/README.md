# Card

Surface de regroupement : une carte posée sur le papier, avec un liseré et sans ombre.

Rendu web écrit à la main à partir de `doneCard`, `doneRaised`, `Hairline` et `Eyebrow` dans `Done/Views/Theme.swift`, revu pour la direction Jardin.

## Genres

- `doneCard` (`.d-card`) : `surfaceDefault`, contour 1 `borderSubtle`, rayon `md` (14) par défaut, `lg` (20) pour un panneau ou la carte de la ligne de temps.
- `doneRaised` (`.d-card--raised`) : rayon `lg` et ombre `shadowRaised`. Réservée à la carte de fin de pomodoro (voir `PomodoroDone`) et à la saisie flottante.
- `Hairline` (`.d-hairline`) : trait de 1 en `borderSubtle` entre deux zones.
- `Eyebrow` (`.d-eyebrow`) : étiquette de section en style `label`, `textSecondary`, casse normale.

## Ce que fournit l'appelant

Le contenu et sa marge intérieure (`s16` dans une carte, `s24` dans un panneau). Un titre de carte peut prendre `displayM` (Fraunces) quand la carte est le sujet de l'écran. Ne pas ajouter d'ombre à une carte ordinaire.
