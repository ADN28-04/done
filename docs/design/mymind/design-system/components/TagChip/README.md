# TagChip

Étiquette d'une tâche : icône `tag` et nom en texte secondaire, sans fond, comme les dates et les durées.

Rendu web écrit à la main à partir de `TagChip` dans `Done/Views/Theme.swift`.

## Règles

- Texte Nunito Sans 12 Medium en `textSecondary`, icône de 10, espace `s4`, sur une ligne.
- Seules les tâches de premier niveau portent des étiquettes, jamais une étape.
- Dans la vue d'une étiquette, celle-ci n'est pas répétée sur les lignes.

## Ce que fournit l'appelant

Le nom de l'étiquette, normalisé par `TaskStore.normalizedTags`.
