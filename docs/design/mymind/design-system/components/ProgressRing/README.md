# ProgressRing

Anneau du minuteur, fin comme le logo : la part restante du pomodoro, qui se vide dans le sens horaire depuis midi.

Rendu web écrit à la main à partir de `ProgressRing` dans `Done/Views/Theme.swift`, revu pour la direction Mymind.

## États

- Concentration : `pomodoroFocus` (braise).
- Pause : `pomodoroBreak` (cobalt), et l'écran passe sur `pomodoroBreakBg`.
- À l'arrêt : `pomodoroPaused`, avec « En pause ».
- Piste : `pomodoroTrack`. Jamais de couleur d'alerte.

## Mesures

En session, `ring-size` (280) et trait `border-ring` (6), extrémités arrondies ; chiffres en `numericXL` (Nunito Sans Light, chiffres à chasse fixe) au centre. Dans la carte Focus de Ma journée, un anneau de 86, trait 6.

## Mouvement

Le trait glisse d'une seconde à l'autre (`linear`, 1 s). Passage en pause : couleur de l'anneau et fond changent ensemble en `dur-slow`.

## Ce que fournit l'appelant

La fraction restante, la couleur de l'état et l'épaisseur ; le texte du centre.
