# Segmented

Choix exclusif entre quelques options courtes : une piste en pilule, le segment choisi posé dessus, qui glisse d'une option à l'autre.

Rendu web écrit à la main à partir de `DoneSegmented` dans `Done/Views/Theme.swift`, revu pour la direction Mymind.

## Mesures

- Piste `bgSunken`, rayon `pill`, marge intérieure 3.
- Segment de 26, marge `s12`, rayon `pill`, texte Nunito Sans 13 SemiBold.
- Choisi : `textPrimary` sur `surfaceDefault` avec `shadowControl` ; les autres en `textSecondary`.

## Mouvement

Le segment choisi glisse vers la nouvelle option (`dur-base`, `ease-in-out`). En SwiftUI : `matchedGeometryEffect`.

## Ce que fournit l'appelant

La sélection liée et la liste `(valeur, titre)`. Deux à quatre options d'un mot.
