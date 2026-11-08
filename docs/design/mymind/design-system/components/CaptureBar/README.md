# CaptureBar

Barre de saisie en bas de Ma journée : noter une tâche, une note ou une réunion sans quitter l'écran.

Composant ajouté par la direction Mymind, inspiré de la barre de saisie des assistants. Elle reprend la logique de la saisie rapide (⌃⌥N) : Entrée ajoute dans l'Inbox, ⌘ Entrée ouvre la saisie complète.

## Règles

- Le genre choisi (Tâche par défaut, Note, Réunion) est la pilule `surfaceSelected` ; les autres sont sur `bgSunken`.
- Le texte d'aide montre un vrai exemple de saisie. Done reconnaît « demain », un jour, « P1 » à « P4 » et un #projet dans le titre.
- Le bouton d'envoi est le principal de la barre (`actionPrimary`, rond de 38).
- Après l'ajout, une puce « Ajoutée dans Inbox » apparaît au-dessus en fondu pendant 2 s.

## Mesures

Hauteur `capture-height` (54), rayon `pill`, `surfaceDefault`, contour `borderSubtle`, ombre `shadowCard`. Pilules de genre de 38.

## Ce que fournit l'appelant

Le texte lié, le genre et l'action d'ajout.
