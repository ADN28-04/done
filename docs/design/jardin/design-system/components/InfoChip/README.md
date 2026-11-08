# InfoChip

Date ou durée d'une tâche : icône et texte secondaires, chiffres tabulaires, sans fond.

Rendu web écrit à la main à partir de `InfoChip` dans `Done/Views/Theme.swift`.

## Règles

- Icône calendrier pour une date, horloge pour une durée ; dans une ligne, la date passe avant la durée.
- Texte `numericS` en `textSecondary`. Une échéance dépassée passe en `stateRiskText`, sans fond.
- Formats de `Format` : « Auj. », « Demain », « Hier », « mar. 3 nov. », « 45 min », « 1 h 30 ».

## Mesures

`chip-height` (22), icône de 10, espace `s4`.

## Ce que fournit l'appelant

Le symbole (`calendar` ou `clock`), le texte déjà formaté et `isAlert` pour une échéance dépassée.
