# TaskRow

Ligne de tâche de 48 : case à cocher, titre et métadonnées, puces à droite. Cocher est le geste le plus fréquent de Done ; c'est lui qui doit faire plaisir.

Rendu web écrit à la main à partir de `TaskRowContent` et `TaskChips` dans `Done/Views/Components.swift`, avec la tuile numérotée (`NumberTile`) du plan du jour, revu pour la direction Mymind.

## Règles

- Hauteur minimale `row-height` (48), rayon `md` (18). Survol : `surfaceHover` et poignée de déplacement.
- Titre en `bodyStrong` sur deux lignes au plus ; métadonnées en `caption` `textSecondary` : liste, puis « N étapes ».
- Puces à droite, espacées de `s12`, dans cet ordre : priorité, « Aujourd'hui » ou « Bloquée », étiquettes, échéance, durée (tâches rapides et Deepwork seulement).
- Étape : retrait de `step-indent` (28) par niveau, sans étiquette.
- Faite : case cochée, titre barré en `textSecondary`, puce « Fait » sur `accentTint`.
- Tuile numérotée (plan du jour) : 24, rayon 8, pleine `stateActive` pour une place dans le plan, en contour `borderDefault` pour un emplacement libre.

## Mouvement : cocher

1. La case rebondit et la coche se trace (voir `TaskCheckbox`).
2. Huit pétales braise, rose et jaune partent de la case et s'effacent (`d-burst`, `dur-celebrate`).
3. Le trait du titre se dessine de gauche à droite (`d-strike`, `dur-base`, 80 ms après).
4. Les puces laissent place à « Fait », qui rebondit (`ease-spring`).
5. Dans l'app, après une seconde, la ligne glisse vers « Fait aujourd'hui » (`dur-slow`, `ease-in-out`) au lieu de disparaître d'un coup.

Rouvrir une tâche ne rejoue rien : la ligne revient à son état, en fondu.

## Ce que fournit l'appelant

La tâche (titre, liste, étapes, priorité, étiquettes, échéance, type), et l'étiquette de la vue en cours (`hiding`) pour ne pas la répéter.
