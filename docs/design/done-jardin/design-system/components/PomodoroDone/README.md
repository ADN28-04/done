# PomodoroDone

Carte de fin de pomodoro : le seul élément surélevé de Done, et le moment le plus joyeux de l'app.

Rendu web écrit à la main à partir de la carte de fin de `SessionViews.swift` (`doneRaised`, anneau coché de 56), revu pour la direction Jardin. Composant ajouté au design system : le code l'assemble dans la vue, sans composant dédié.

## Contenu

- Anneau de 56 en `pomodoroFocus` qui se referme, puis une coche qui se trace au centre.
- Titre en `displayM` (Fraunces) : « Pomodoro terminé », ou « Étape terminée ».
- La durée et la tâche en `callout` `textSecondary`.
- La série du jour : une pastille `sun` par pomodoro fait, une pastille vide pour le prochain, et une phrase en `sunText` (« 3e pomodoro aujourd'hui »). Le texte dit la même chose que les pastilles.
- Les actions de Done : « Cocher la tâche » en principal, « Encore 5 min » et « Pause » en secondaire, « Arrêter » en discret.

## Mouvement, dans l'ordre

1. La carte monte de 12 et apparaît (`d-rise`, `dur-slow`, `ease-out`).
2. 260 ms après, l'anneau se referme (520 ms, `ease-out`).
3. La coche se trace et huit pétales `sun` partent de l'anneau (`d-burst`, `dur-celebrate`).
4. La nouvelle pastille de la série rebondit (`d-pop`, `ease-spring`).

Le tout tient en un peu plus d'une seconde et ne se rejoue pas. Avec « Réduire les animations », la carte apparaît en fondu, déjà cochée. Dans l'app, ajouter un son discret seulement si l'utilisateur l'a choisi dans les réglages.

## Ce que fournit l'appelant

La durée, le titre de la tâche, le nombre de pomodoros du jour et les actions.
