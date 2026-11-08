# Segmented

Choix exclusif entre quelques options courtes : piste enfoncée, segment choisi posé sur une surface, qui glisse d'une option à l'autre.

Rendu web écrit à la main à partir de `DoneSegmented` dans `Done/Views/Theme.swift`, revu pour la direction Jardin.

## Mesures

- Piste `bgSunken`, rayon `sm` (10), marge intérieure 2, segments espacés de `s2`.
- Segment de 24 (`tile-size`), marge `s12`, rayon `xs` (5).
- Texte Archivo 13 : choisi en SemiBold `textPrimary` sur `surfaceDefault` avec l'ombre `shadowCard`, les autres en Medium `textSecondary`.

## Mouvement

Le segment choisi glisse vers la nouvelle option (`dur-base`, `ease-in-out`). En SwiftUI : `matchedGeometryEffect` sur le fond du segment.

## Ce que fournit l'appelant

La sélection liée et la liste `(valeur, titre)`. Deux à quatre options, titres d'un mot. Au-delà, un menu.
