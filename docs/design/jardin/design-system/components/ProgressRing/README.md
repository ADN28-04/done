# ProgressRing

Anneau du minuteur : la part restante du pomodoro, qui se vide dans le sens horaire depuis midi.

Rendu web écrit à la main à partir de `ProgressRing` dans `Done/Views/Theme.swift`, revu pour la direction Jardin.

## États

- Concentration : `pomodoroFocus` (vert profond, vert tendre en sombre).
- Pause : `pomodoroBreak` (ocre de tournesol), et l'écran passe sur `pomodoroBreakBg`, une lumière plus chaude.
- À l'arrêt : `pomodoroPaused`, avec la mention « En pause ».
- Piste : `pomodoroTrack`. Jamais de couleur d'alerte, même à la fin.

## Mesures

En session, `ring-size` (280) et trait `border-ring` (8), extrémités arrondies ; chiffres en `numericXL` (Archivo Regular, chiffres tabulaires) au centre.

## Mouvement

- Le trait glisse d'une seconde à l'autre (`linear`, 1 s), il ne saute pas.
- Passage en pause : la couleur de l'anneau et le fond de l'écran changent ensemble en `dur-slow`.
- Fin : voir `PomodoroDone`.

## Ce que fournit l'appelant

La fraction restante (0 à 1), la couleur de l'état et l'épaisseur. Le texte du centre est posé par l'appelant (`TimerText`).
