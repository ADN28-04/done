# ControlCenter

Ma journée, l'écran d'accueil de Done : il réunit les anciens écrans Focus, Aujourd'hui et Plan du jour, avec un aperçu des notes et des stats.

Page de référence de la direction Mymind, assemblée avec les composants de ce design system. Elle remplace `FocusView`, `TodayView` et `PlanView` comme écran d'arrivée ; la session de focus reste plein écran.

## Disposition (fenêtre de 1376 × 852)

- À gauche, le `Rail` (84).
- En haut, le `Greeting` à gauche ; `SearchField` et le bouton « Capturer » à droite.
- Une grille de six cartes widget (`Card`), trois colonnes (1,25 / 1 / 1), deux rangées, écart 16 :
  1. **Prochaine action** : l'étape proposée en `displayL`, sa tâche, ses puces, un anneau de 86 avec la durée, « Lancer le focus » (le seul bouton principal de l'écran), « Découper… », et le temps libre avant la prochaine réunion.
  2. **Ma journée** : `DayTimeline`. Lien « Calendrier ».
  3. **Plan du jour** : barre d'avancement, tâches numérotées (`TaskRow` compactes). On y glisse une tâche depuis les échéances ; « Modifier » ouvre le choix des candidates en feuille.
  4. **Échéances et retards** : ce qui tombe aujourd'hui ou est en retard, hors plan. Lien « Tout voir ».
  5. **Notes** : `NoteCard` en mosaïque, le journal du jour en premier. Lien « Toutes les notes ».
  6. **Focus aujourd'hui** : temps de focus en `numericL`, pastilles de série en `accent`, tâches cochées, Inbox à trier, barres de la semaine. Lien « Stats ».
- En bas, la `CaptureBar`.
- Fond : `bgCanvas` avec les halos `haloWarm` (en haut à droite) et `haloPink` (en bas à gauche), classe `.d-window`.

## Comportement

- La fenêtre se réduit jusqu'à 1100 de large : la grille passe alors à deux colonnes et la carte Notes descend sous les autres.
- Le soir, après 18:00, la carte Prochaine action laisse la place au bilan du soir.
- Un jour d'absence, la carte Prochaine action dit « Jour de congé » et propose « Travailler quand même ».
- Cocher une tâche dans n'importe quelle carte suit le mouvement de `TaskRow`.

## Ce que fournit l'appelant

Les données de `AppModel` (plan, tâches, réunions, sessions, notes) et le prénom.
