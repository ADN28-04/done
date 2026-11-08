# NoticeBox

Encadré de message, sans contour : information en vert, réussite en tournesol, erreur en brique.

Rendu web écrit à la main à partir de `NoticeBox` dans `Done/Views/Theme.swift`, revu pour la direction Jardin.

## Tons

- `info` : icône « i », texte `stateActiveText` sur `stateActiveTint`.
- `success` : petit soleil, texte `sunText` sur `sunTint`. Ton ajouté : plan du jour terminé, semaine bouclée. Une phrase sobre, pas de point d'exclamation.
- `error` : icône d'alerte, texte `stateRiskText` sur `stateRiskTint`. Réservé aux erreurs.

## Mesures

Rayon `sm` (10), marges `s12` × `s8`, espace `s8`, icône de 11 alignée sur la première ligne, texte `callout` sur plusieurs lignes. L'encadré arrive en fondu (`dur-base`).

## Ce que fournit l'appelant

Le texte, une ou deux phrases courtes et directes, sans point d'exclamation, et le ton.
