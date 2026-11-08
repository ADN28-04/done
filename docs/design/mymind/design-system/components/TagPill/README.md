# TagPill

Étiquette en pilule à contour coloré, comme les mots de l'accueil de mymind : le type d'une note, ou une étiquette de tâche dans une carte.

Composant ajouté par la direction Mymind.

## Couleurs

Texte et contour de la même couleur, fond transparent : Note `accentText`, Réunion `stateActiveText`, Décision `tagPink`, Journal `tagYellow`, Personne `successText`, une étiquette de tâche `textSecondary`. Toutes passent 4,5:1 sur `surfaceDefault` et sur la teinte de leur carte.

## Mesures

`chip-height` (22), rayon `pill`, contour 1, marge 10, Nunito Sans 12 SemiBold.

## Ce que fournit l'appelant

Le libellé et le type. Dans les lignes de tâche, garder `TagChip` (texte et icône seuls) : la pilule colorée est pour les cartes.
