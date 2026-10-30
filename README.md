# Done

App macOS personnelle qui réunit une liste de tâches et un minuteur Pomodoro. Le matin, je choisis mes trois tâches les plus importantes. Ensuite, Done ne m'affiche qu'une chose : la prochaine action concrète, avec un minuteur adapté.

Tout reste sur le Mac : pas de compte, pas de synchro, pas de service tiers.

Le cadrage est dans `docs/` : `vision.md` (le problème), `spec.md` (fonctionnalités, écrans, données) et `questions.md` (ce qui reste ouvert). Le design est décrit dans `design-system.md`, avec les maquettes dans `docs/design/`.

## Lancer l'app

Il faut un Mac sous macOS 14 ou plus récent, et Xcode 16 ou plus récent.

1. Ouvrir `Done.xcodeproj` dans Xcode.
2. Dans la cible **Done**, onglet **Signing & Capabilities**, choisir son équipe (un Apple ID gratuit, « Personal Team », suffit). Sans équipe, Xcode signe en local, ce qui marche aussi, mais macOS peut bloquer les notifications.
3. Lancer avec ⌘R.
4. Accepter les notifications quand macOS les demande.
5. Ajouter ses tâches dans l'Inbox (barre latérale), avec ⌘N depuis n'importe quel écran, ou en cliquant sur l'icône de Done dans la barre de menus, depuis n'importe quelle app.

### Installer ou mettre à jour l'app dans Applications

Depuis le Terminal, dans le dossier du projet :

```
./scripts/install.sh
```

Le script compile la version finale, ferme Done si elle tourne, remplace `/Applications/Done.app` et relance l'app. Les tâches et l'historique sont conservés. À relancer après chaque modification du code (ou après un `git pull`).

Le script trouve Xcode tout seul, même si ce sont les outils de ligne de commande qui sont sélectionnés. La première fois, macOS peut demander au Terminal l'autorisation de contrôler Done : c'est ce qui permet de la fermer proprement.

### Activer « Ne pas déranger » pendant les sessions (facultatif)

macOS ne laisse pas une app piloter les modes de concentration. Done passe par l'app Raccourcis :

1. Dans Raccourcis, créer un raccourci nommé exactement `Done Focus On`, avec l'action « Définir la concentration » (Set Focus) : « Ne pas déranger », Activé, jusqu'à désactivation.
2. Créer un second raccourci nommé `Done Focus Off`, avec la même action réglée sur Désactivé.
3. Lancer chaque raccourci une fois à la main, pour accepter les autorisations éventuelles.
4. Dans Done, Réglages › Ne pas déranger : activer l'option, puis cliquer sur Vérifier et Tester.

Done active le mode quand le minuteur de focus tourne, et le coupe en pause, en interruption, en fin de session et quand l'app se ferme. Si Done est arrêté brutalement (par exemple avec le bouton Stop d'Xcode), le mode reste actif : il faut le couper dans le Centre de contrôle.

### Si les notifications n'arrivent pas

Dans Done, Réglages › Notifications indique ce que macOS autorise, avec un bouton Tester.

- **« Refusées » ou « sans bannière »** : bouton Réglages, puis autoriser Done et choisir le style Bannières.
- **« macOS bloque les notifications de Done »** : l'app est probablement signée seulement en local. Dans Xcode, cible Done › Signing & Capabilities, choisir une équipe (un Apple ID gratuit suffit), puis relancer `./scripts/install.sh`.
- **Pendant « Ne pas déranger »** : macOS masque les notifications, sauf si Done fait partie des apps autorisées de ce mode (Réglages Système › Concentration).
- **Notification sans logo** : macOS a gardé l'icône d'une copie de Done antérieure au logo (première version, build d'Xcode, copie téléchargée). Depuis le dossier du projet, lancer `./scripts/reset-notification-icon.sh` : il fait oublier les autres copies à macOS, réenregistre celle d'Applications et relance le centre de notifications. Si le logo manque encore, fermer la session macOS et la rouvrir.

Dans tous les cas, Done joue un son à la fin des sessions et des pauses, et son icône rebondit dans le Dock jusqu'à ce que tu reviennes dans l'app.

### Où sont les tâches

Dans un seul fichier, `~/Library/Application Support/com.adnan.done/tasks.json`, réécrit à chaque changement. Done en garde une copie par jour, sur 30 jours, dans le dossier `Sauvegardes` à côté. Réglages › Données › « Afficher dans le Finder » ouvre le dossier.

Pour revenir à une sauvegarde : quitter Done, remplacer `tasks.json` par la copie voulue (renommée `tasks.json`), relancer Done. Si le fichier devient illisible, Done le met de côté (`tasks-illisible-…json`), repart d'une liste vide et le signale.

L'historique des sessions et le plan du jour restent dans la base SwiftData de l'app, comme avant.

## Organisation du code

```
Done/
  App/        point d'entrée, fenêtre et barre de menus
  Core/       logique pure, sans SwiftUI : tâches et projets (TaskStore), règles, choix de la tâche, stats
  Data/       modèles SwiftData (plan du jour, sessions, interruptions)
  Services/   fichier des tâches, notifications, « Ne pas déranger », appels AppKit
  State/      AppModel (tâches, réunions, plan) et FocusEngine (minuteur)
  Views/      écrans SwiftUI, et Theme.swift pour les tokens et composants du design system v3
  Fonts/      Bricolage Grotesque et IBM Plex Sans (licences OFL dans docs/fonts/)
  Assets.xcassets/  icône de l'app et couleur d'accent
```

Le projet utilise un dossier synchronisé : tout fichier ajouté dans `Done/` est compilé, sans modifier le projet Xcode.

## Règles de l'app

- **Tâches** : un titre, des notes, une liste (Inbox ou projet), une priorité de P1 à P4, un type (normale, rapide, Deepwork), une échéance facultative, des étapes (sous-tâches). Une tâche peut être marquée bloquée.
- **Candidates du matin** : les tâches P1 et P2, et toutes celles dont l'échéance tombe dans les 3 jours ou est dépassée. Ni bloquées, ni datées plus loin.
- **Dates lointaines** : une tâche datée au-delà de ces 3 jours n'est pas proposée (ni candidate, ni prochaine action, ni tâche rapide avant une réunion). Elle reste trouvable avec « Chercher une autre tâche », en fin de liste.
- **Prochaine action** : la première étape ni bloquée ni datée plus tard, dans l'ordre de la liste.
- **Durée** : 15 min pour une tâche rapide, 50 min pour une tâche Deepwork, 25 min sinon. Pause de 10 min après une session Deepwork, 5 min sinon.
- **Enchaînement** : « C'est fait » coche l'action tout de suite. S'il reste au moins une minute et qu'une étape suit dans la même tâche, Done propose de l'enchaîner dans le même pomodoro ; sinon, pause. Chaque étape garde sa propre session dans les stats.
- **Rallonge** : « Ajouter 5 min » pendant la session ou « Encore 5 min » à la fin, 10 min au plus par pomodoro. Au-delà, une pause avant de continuer la même étape.
- **Étape bloquée** : « Bloqué… » marque l'étape bloquée, garde la raison en note de reprise, puis passe à l'étape suivante de la même tâche. On la débloque dans sa liste (clic droit ou fiche de la tâche).
- **Pause obligatoire** : changer de tâche principale passe par une pause qui ne se passe pas. Après une tâche cochée, elle démarre seule ; après « Arrêter là » ou une pause passée, l'écran Focus propose « Démarrer la pause » avant une autre tâche. Une interruption n'en impose pas, pour laisser passer une urgence.
- **Réunions** : saisies à la main dans le Plan du jour (titre, jour, début, fin). Done ne propose pas de session qui déborde sur la prochaine réunion, et prévient 5 minutes avant (réglable).
- **Ne pas déranger** (si activé) : seulement pendant que le minuteur de focus tourne.
- **Note de reprise** : en fin de session ou pendant une interruption, une ligne « Où tu en es ? », réaffichée la prochaine fois que la tâche revient. Effacée quand la tâche est cochée ou supprimée.
- **Découpage** : « Découper… » sur l'écran Focus ou dans une liste (clic droit) ajoute les étapes qui mènent la tâche au bout, dans l'ordre. Après chaque étape cochée, Done propose la suivante ; une fois toutes faites, la tâche elle-même, pour la clore.
- **Bilan du soir** : à partir de 17 h, Done propose de clore la journée ; les tâches non finies marquées « Demain » sont reprises dans le plan du lendemain.
- **Avant une réunion** : si la tâche prévue ne tient pas, Done propose la suivante du plan qui tient, puis une tâche rapide, puis la préparation de la réunion ou une pause.

Les durées, le nombre de tâches par jour, l'horizon des candidates, le bilan, les notifications et « Ne pas déranger » se règlent dans l'écran Réglages.
