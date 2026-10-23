# Done

App Pomodoro personnelle pour macOS, branchée sur Todoist. Le matin, je choisis mes trois tâches les plus importantes. Ensuite, Done ne m'affiche qu'une chose : la prochaine action concrète, avec un minuteur adapté.

Le cadrage est dans `docs/` : `vision.md` (le problème), `spec.md` (fonctionnalités, écrans, données) et `questions.md` (ce qui reste ouvert). Le design est décrit dans `design-system.md`, avec les maquettes dans `docs/design/`.

## Lancer l'app

Il faut un Mac sous macOS 14 ou plus récent, et Xcode 16 ou plus récent.

1. Ouvrir `Done.xcodeproj` dans Xcode.
2. Dans la cible **Done**, onglet **Signing & Capabilities**, choisir son équipe (un Apple ID gratuit, « Personal Team », suffit). Sans équipe, Xcode signe en local, ce qui marche aussi, mais le Mac redemande l'accès au trousseau après chaque compilation.
3. Lancer avec ⌘R.
4. Au premier lancement, coller le token API Todoist : Todoist › Réglages › Intégrations › Développeur.
5. Accepter les notifications quand macOS les demande.

### Installer ou mettre à jour l'app dans Applications

Depuis le Terminal, dans le dossier du projet :

```
./scripts/install.sh
```

Le script compile la version finale, ferme Done si elle tourne, remplace `/Applications/Done.app` et relance l'app. Les données et le token sont conservés. À relancer après chaque modification du code (ou après un `git pull`).

Le script trouve Xcode tout seul, même si ce sont les outils de ligne de commande qui sont sélectionnés. La première fois, macOS peut demander au Terminal l'autorisation de contrôler Done : c'est ce qui permet de la fermer proprement.

### Activer « Ne pas déranger » pendant les sessions (facultatif)

macOS ne laisse pas une app piloter les modes de concentration. Done passe par l'app Raccourcis :

1. Dans Raccourcis, créer un raccourci nommé exactement `Done Focus On`, avec l'action « Définir la concentration » (Set Focus) : « Ne pas déranger », Activé, jusqu'à désactivation.
2. Créer un second raccourci nommé `Done Focus Off`, avec la même action réglée sur Désactivé.
3. Lancer chaque raccourci une fois à la main, pour accepter les autorisations éventuelles.
4. Dans Done, Réglages › Ne pas déranger : activer l'option, puis cliquer sur Vérifier et Tester.

Done active le mode quand le minuteur de focus tourne, et le coupe en pause, en interruption, en fin de session et quand l'app se ferme. Si Done est arrêté brutalement (par exemple avec le bouton Stop d'Xcode), le mode reste actif : il faut le couper dans le Centre de contrôle.

### Découper avec Claude (facultatif)

1. Créer une clé sur [console.anthropic.com](https://console.anthropic.com/settings/keys). Elle est facturée à l'usage, à part de l'abonnement Claude.
2. Dans Done, Réglages › Claude : coller la clé, puis Enregistrer. Done la vérifie et la range dans le trousseau.
3. Choisir le dossier de contexte : celui où sont le plan marcomm, les priorités, le lexique. Done lit le Markdown, le texte, le CSV, le JSON, le PDF, le Word et le RTF ; il ignore les fichiers cachés et les autres formats (Excel, PowerPoint, images).
4. Ajuster « Ta méthode pour découper » si besoin.

Sur l'écran Focus, sous l'action proposée, « Découper avec Claude… » ouvre la feuille de découpage et lance Claude, qui reçoit la tâche, la méthode, quelques sous-tâches existantes comme exemples et la liste des fichiers du dossier. Claude lit ceux qui l'aident (5 par appel, 30 000 caractères par fichier au plus) et propose le découpage complet : une phrase d'approche et toutes les étapes dans l'ordre (10 au plus). Chaque étape se modifie, se retire, ou s'ajoute à la main ; « Ajouter N étapes dans Todoist » (⌘ Entrée) les crée toutes comme sous-tâches, et l'écran Focus les propose ensuite une par une. Seuls les fichiers qu'il demande quittent le Mac. Claude Opus 5.5 est le modèle par défaut ; Sonnet 5.5 et Haiku 5.5 coûtent moins cher.

Pour un document propre à la tâche (brief, maquette, capture d'écran, export PDF d'un tableau), utilise « Joindre un fichier… » dans la feuille de découpage, ou glisse le fichier dessus. Claude le reçoit en entier, et il reste attaché à la tâche pour les découpages suivants (5 fichiers au plus par tâche, PDF de 15 Mo au plus). Les images sont réduites à 2000 px avant l'envoi. Après avoir joint un fichier, « Relancer avec les pièces jointes » redemande des propositions.

La première fois, macOS peut demander l'autorisation d'accéder au dossier (Documents, Bureau, iCloud Drive).

### Si les notifications n'arrivent pas

Dans Done, Réglages › Notifications indique ce que macOS autorise, avec un bouton Tester.

- **« Refusées » ou « sans bannière »** : bouton Réglages, puis autoriser Done et choisir le style Bannières.
- **« macOS bloque les notifications de Done »** : l'app est probablement signée seulement en local. Dans Xcode, cible Done › Signing & Capabilities, choisir une équipe (un Apple ID gratuit suffit), puis relancer `./scripts/install.sh`.
- **Pendant « Ne pas déranger »** : macOS masque les notifications, sauf si Done fait partie des apps autorisées de ce mode (Réglages Système › Concentration).

Dans tous les cas, Done joue un son à la fin des sessions et des pauses, et son icône rebondit dans le Dock jusqu'à ce que tu reviennes dans l'app.

## Organisation du code

```
Done/
  App/        point d'entrée, fenêtre et barre de menus
  Core/       logique pure, sans SwiftUI : modèles Todoist, règles, choix de la tâche, stats
  Data/       modèles SwiftData (plan du jour, sessions, interruptions, photos du backlog)
  Services/   client API Todoist, trousseau, notifications, appels AppKit
  State/      AppModel (tâches et plan) et FocusEngine (minuteur)
  Views/      écrans SwiftUI, et Theme.swift pour les couleurs, polices et composants du design system
  Fonts/      Plus Jakarta Sans, DM Sans et DM Mono (licences OFL dans docs/fonts/)
  Assets.xcassets/  icône de l'app et couleur d'accent
```

Le projet utilise un dossier synchronisé : tout fichier ajouté dans `Done/` est compilé, sans modifier le projet Xcode.

## Règles de l'app

- **Candidates du matin** : P1 ou P2, sans `@Waiting`, avec `@Chantier-actif` ou une échéance dans les 3 jours.
- **Dates lointaines** : une tâche datée au-delà de ces 3 jours n'est pas proposée (ni candidate, ni prochaine action, ni tâche rapide avant une réunion), même avec `@Chantier-actif`. Elle reste trouvable avec « Chercher une autre tâche », en fin de liste. Une échéance Todoist (deadline) proche l'emporte sur la date.
- **Prochaine action** : la première sous-tâche sans `@Waiting` et pas datée plus tard, dans l'ordre de Todoist.
- **Durée** : 15 min pour `@Quick`, 50 min pour `@Deepwork`, 25 min sinon. Pause de 10 min après une session Deepwork, 5 min sinon.
- **Enchaînement** : « C'est fait » coche l'action tout de suite. S'il reste au moins une minute et qu'une étape suit dans la même tâche, Done propose de l'enchaîner dans le même pomodoro ; sinon, pause. Chaque étape garde sa propre session dans les stats.
- **Rallonge** : « Ajouter 5 min » pendant la session ou « Encore 5 min » à la fin, 10 min au plus par pomodoro. Au-delà, une pause avant de continuer la même étape.
- **Étape bloquée** : « Bloqué… » laisse l'étape ouverte dans Todoist avec `@Waiting` et un commentaire « Bloqué : … », puis passe à l'étape suivante de la même tâche. Retire `@Waiting` dans Todoist quand c'est débloqué : l'étape revient, avec le commentaire en note de reprise.
- **Pause obligatoire** : changer de tâche principale passe par une pause qui ne se passe pas. Après une tâche cochée, elle démarre seule ; après « Arrêter là » ou une pause passée, l'écran Focus propose « Démarrer la pause » avant une autre tâche. Une interruption n'en impose pas, pour laisser passer une urgence.
- **Réunions** : tâches datées avec une heure et dont le titre commence par « Réunion ». Si le titre contient « deepwork », « deepword » ou « focus », c'est un bloc de travail.
- **Ne pas déranger** (si activé) : seulement pendant que le minuteur de focus tourne.
- **Note de reprise** : en fin de session ou pendant une interruption, une ligne « Où tu en es ? », réaffichée la prochaine fois que la tâche revient. Effacée quand la tâche est cochée.
- **Réunion proche** : notification 5 minutes avant chaque réunion (réglable). Pendant « Ne pas déranger », macOS la masque, sauf si Done fait partie des apps autorisées de ce mode.
- **Découpage assisté** : sur l'écran Focus, « Découper… » sous l'action en cours (hors `@Quick`) crée dans Todoist les étapes qui mènent la tâche au bout, dans l'ordre. Après chaque étape cochée, Done propose la suivante de la même tâche ; une fois toutes faites, la tâche elle-même, pour la clore. Avec une clé API Claude, le bouton s'appelle « Découper avec Claude… » et Claude propose le découpage complet dès l'ouverture.
- **Garde-fou** : à la validation du plan, au-delà de 2 tâches `@Chantier-actif`, Done propose d'en mettre en file d'attente (retrait du label dans Todoist). Une fois par jour.
- **Bilan du soir** : à partir de 17 h, Done propose de clore la journée ; les tâches non finies marquées « Demain » sont reprises dans le plan du lendemain.
- **Avant une réunion** : si la tâche prévue ne tient pas, Done propose la suivante du plan qui tient, puis une tâche `@Quick`, puis la préparation de la réunion ou une pause.

Tout est réglable dans l'écran Réglages, sauf les noms de labels (dans `Done/Core/Rules.swift`).
