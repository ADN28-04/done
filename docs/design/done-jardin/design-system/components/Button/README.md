# Button

Bouton texte de Done, en trois genres : principal, secondaire et discret, avec une variante compacte de 26.

Rendu web écrit à la main à partir de `DoneButtonStyle` dans `Done/Views/Theme.swift`.

## Quand l'utiliser

- **Principal** (`.d-btn--primary`, `kind: .primary`) : l'action qui fait avancer la vue. Un seul par vue.
- **Secondaire** (`.d-btn`, `kind: .secondary`, le défaut) : les autres actions, sur `surfaceDefault` avec un contour `borderDefault`.
- **Discret** (`.d-btn--plain`, `kind: .plain`) : texte seul en `textSecondary`, qui passe en `textPrimary` au survol. Pour « Détails… », « Annuler » dans un en-tête.
- **Compact** (`.d-btn--compact`, `compact: true`) : 26 de haut, texte 13, pour les lignes de réglages et les puces d'action.

## Mesures

- Hauteur `control-height` (32), compact `control-compact` (26). Rayon `sm` (10).
- Marge horizontale 14 (compact 10, discret 8).
- Texte Archivo 14 (compact 13) : SemiBold pour le principal, Medium pour les autres.
- Principal : `actionPrimary`, `actionPrimaryHover` au survol, `actionPrimaryPressed` à l'appui, texte `actionOnPrimary`.
- Désactivé : texte `textDisabled` ; principal sur `actionDisabled`, secondaire transparent avec contour `borderSubtle`.

## Ce que fournit l'appelant

Le libellé (court, verbe à l'infinitif, sans point d'exclamation), l'action, et `fullWidth` (`.d-btn--full`) pour un bouton qui prend toute la largeur. Le focus clavier vient de l'anneau du système, teinté en vert par `AccentColor`.
