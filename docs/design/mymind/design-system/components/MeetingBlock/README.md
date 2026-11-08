# MeetingBlock

Bloc réunion du calendrier et de la ligne de temps : hachuré à venir, plein d'encre en cours, gris une fois passé.

Rendu web écrit à la main à partir de `MeetingBlock` et `Hatching` dans `Done/Views/Theme.swift`.

## États

- À venir : `meetingBg` couvert de hachures `meetingHatch` (traits de 1,5 à 45°, tous les 6). Le temps est pris. Texte `textPrimary`.
- En cours : plein `meetingNow`, texte `meetingOnNow`, la ligne du bas dit « En cours · fin 11:30 ».
- Passée : `stateDone`, texte `textDisabled`.

## Mesures

Rayon `sm` (12), marges `s8` × `s6`, titre Nunito Sans 13 Medium sur une ligne, créneau en `numericS` à 85 % d'opacité (100 % en cours). Dans la grille, le bloc remplit son créneau (`fillsHeight`). La pastille de la barre du haut (`MeetingPill`) suit les mêmes règles.

## Ce que fournit l'appelant

La réunion, l'heure courante et le créneau formaté (« 14:00–15:00 »). Jamais de couleur d'alerte pour une réunion.
