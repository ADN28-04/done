# NoticeBox

Encadré de message, sans contour : information en cobalt, réussite en braise, erreur en rouge sombre.

Rendu web écrit à la main à partir de `NoticeBox` dans `Done/Views/Theme.swift`, revu pour la direction Mymind.

## Tons

- `info` : icône « i », texte `stateActiveText` sur `stateActiveTint`.
- `success` : petit soleil, texte `accentText` sur `accentTint`. Plan du jour terminé, semaine bouclée.
- `error` : triangle, texte `stateRiskText` sur `stateRiskTint`. Réservé aux erreurs.

## Mesures

Rayon `md` (18), marges 14 × 10, icône de 11, texte `callout`. Arrive en fondu (`dur-base`).

## Ce que fournit l'appelant

Une ou deux phrases courtes, sans point d'exclamation, et le ton.
