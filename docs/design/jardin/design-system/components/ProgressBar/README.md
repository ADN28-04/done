# ProgressBar

Barre de progression horizontale : piste `pomodoroTrack`, plein `stateActive`.

Rendu web écrit à la main à partir de `ProgressBar` dans `Done/Views/Theme.swift`.

## Mesures

Hauteur 6 par défaut, en capsule (extrémités entièrement arrondies). Le plein part de la gauche.

## Ce que fournit l'appelant

La fraction (0 à 1), et au besoin une autre couleur et une autre hauteur. Pour les stats et l'avancement d'une tâche à étapes ; le minuteur utilise `ProgressRing`.
