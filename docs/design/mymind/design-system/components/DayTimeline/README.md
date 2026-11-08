# DayTimeline

Ligne de temps de la journée, dans une carte de Ma journée : réunions, focus déjà fait, créneaux libres et heure courante.

Rendu web écrit à la main à partir de `DayTimeline` (`Done/Views/DayTimeline.swift`), revu pour la direction Mymind.

## Blocs

- Focus fait : `accentTint`, texte `accentText`, une ligne.
- Réunion en cours : `meetingNow` (encre), texte `meetingOnNow`.
- Réunion à venir : `meetingBg` hachuré `meetingHatch`.
- Réunion passée : `stateDone`, texte `textDisabled`.
- Créneau libre de 30 min ou plus : pointillé `stateWaiting`, avec ce qu'il permet (« 2 pomodoros possibles »). Un clic y lance la prochaine action.
- Heure courante : trait de 2 et point en `accent`, l'heure à gauche en `accentText`.

## Mesures

40 par heure dans Ma journée (de l'heure courante moins une, jusqu'à 19:00, en défilant), heures en `numericS`, blocs au rayon `sm` (12). Un bloc de moins de 30 min tient sur une ligne (`.d-meeting--one`).

## Ce que fournit l'appelant

Les réunions, les sessions de focus du jour, l'heure courante et les actions (clic sur un créneau, sur une réunion).
