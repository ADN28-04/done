# Button

Bouton texte de Done, toujours en pilule : principal en encre pleine, secondaire sur surface, discret en texte seul.

Rendu web écrit à la main à partir de `DoneButtonStyle` dans `Done/Views/Theme.swift`, revu pour la direction Mymind.

## Quand l'utiliser

- **Principal** (`.d-btn--primary`) : l'action qui fait avancer la vue, en `actionPrimary` (encre) et `actionOnPrimary`. Un seul par zone : « Lancer le focus » dans la carte Focus, « Capturer » dans l'en-tête.
- **Secondaire** (`.d-btn`) : les autres actions, sur `surfaceDefault` avec un contour `borderDefault`.
- **Discret** (`.d-btn--plain`) : texte seul en `textSecondary`.
- **Compact** (`.d-btn--compact`) : 28 de haut, texte 13, pour les réglages.
- Une icône à gauche (14) quand elle aide : lecture pour lancer, + pour capturer. Le raccourci clavier se met à droite en `.d-kbd`.

## Mesures

Hauteur `control-height` (34), compact `control-compact` (28), rayon `pill`, marge 16 (compact 12), texte Nunito Sans 14 SemiBold. Désactivé : texte `textDisabled`, fond `actionDisabled` pour le principal.

## Mouvement

Le bouton se tasse à l'appui (`scale(.97)`, `dur-instant`) et change de fond en `dur-fast`.

## Ce que fournit l'appelant

Le libellé (verbe à l'infinitif, sans point d'exclamation), l'icône éventuelle, le raccourci éventuel et l'action.
