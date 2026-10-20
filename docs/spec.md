# Spécification : Done

Document de cadrage de la V1. Voir `vision.md` pour le problème et `questions.md` pour ce qui reste ouvert.

## 1. Scénarios d'usage

### S1. Le rituel du matin
J'arrive, je lis mes mails, j'ajoute des tâches dans Todoist si besoin. J'ouvre Done sur le Mac. L'app récupère les tâches et me montre une liste de candidates : P1 et P2, sans le label `Waiting`, avec `Chantier-actif` ou une échéance dans les 3 jours. Elle affiche aussi mes réunions du jour. Je glisse mes trois tâches dans l'ordre d'importance et je valide. Durée cible : moins de deux minutes.

### S2. Attaquer la tâche
L'écran Focus affiche la tâche n°1 et, en grand, sa prochaine sous-tâche faisable (non `Waiting`, première dans l'ordre Todoist). Exemple : pour « Mettre en ligne la LP Luminothérapie », l'app propose « Créer l'étiquette Saison hiver sur les 9 fiches » et ignore les deux relectures en attente. La durée est proposée selon le label. Je clique sur Démarrer.

### S3. Une session de deep work
Pendant mon bloc de 3 h, j'enchaîne des sessions de 50 minutes avec 10 minutes de pause. À la fin d'une session, l'app me demande : terminé, ou je continue ? Si je dis terminé, elle coche la sous-tâche dans Todoist et me montre la suivante.

### S4. Une réunion arrive
Une réunion est prévue à 14h00 et il est 13h40. L'app ne me propose pas une session de 50 minutes. Elle prend la prochaine tâche de ma liste qui tient dans 20 minutes, ou une tâche `Quick`. Si aucune ne tient, elle me propose de préparer la réunion ou de faire une pause.

### S5. Une interruption imprévue
Un collègue m'appelle pendant une session. J'appuie sur Interrompre et je choisis la raison : réunion, urgence ou autre. Le minuteur se met en pause, le temps passé est enregistré. Quand je reviens, l'app me propose de reprendre ou de choisir autre chose. Si l'urgence devient prioritaire, je peux l'insérer en tête de ma liste du jour.

### S6. Suivre depuis l'iPhone
Je quitte mon bureau pendant une session. Sur l'iPhone, je vois la tâche en cours et le temps restant, et je reçois la notification de fin. Je peux mettre en pause ou terminer depuis le téléphone.

### S7. Faire le point
Le vendredi, j'ouvre l'écran Stats. Je vois le temps de focus de la semaine, les sessions par jour, les interruptions par raison, le temps passé par projet, et l'évolution du backlog Shop (tâches ouvertes, âge moyen, nombre de chantiers actifs en parallèle).

## 2. Fonctionnalités

### MVP (V1)

| Fonctionnalité | Détail |
|---|---|
| Connexion Todoist | Token API personnel collé une fois dans les réglages, stocké dans le Trousseau. Pas d'OAuth. |
| Lecture des tâches | Tâches, sous-tâches, projets, sections, labels, priorités, échéances, durées. |
| Liste de candidates | Filtre fixe : P1/P2, sans `Waiting`, avec `Chantier-actif` ou échéance dans les 3 jours. |
| Plan du jour | Je choisis et ordonne 3 tâches (5 maximum). Le plan est gardé pour la journée. |
| Prochaine action | Proposition de la première sous-tâche faisable de la tâche en cours. |
| Durée adaptée | `Quick` : 15 min. Par défaut : 25 min. `Deepwork` : 50 min. Pauses de 5 ou 10 min. Modifiable avant de lancer. |
| Minuteur | Démarrer, pause, reprendre, terminer. Notification de fin sur Mac et iPhone. |
| Réunions | Lecture des tâches « Réunion · … » datées dans Todoist pour connaître les créneaux du jour. Proposition d'une tâche qui tient avant la prochaine réunion. |
| Interruptions | Bouton Interrompre avec raison (réunion, urgence, autre). Temps partiel enregistré. |
| Clôture | Cocher la sous-tâche ou la tâche dans Todoist depuis l'app. |
| Historique | Chaque session est enregistrée : tâche, projet, durée prévue, durée réelle, issue, interruptions. |
| Stats de base | Temps de focus par jour et par semaine, sessions par jour, interruptions par raison, temps par projet. |
| Stats backlog | Tâches ouvertes du backlog Shop, âge moyen, nombre de `Chantier-actif` en parallèle, tâches parentes fermées par semaine. |
| Synchro Mac / iPhone | Plan du jour, session en cours et historique synchronisés via iCloud. |

### Plus tard

- **Réglage des règles** : modifier le filtre des candidates et les durées par label depuis l'app.
- **Découpage assisté** : si une tâche n'a pas de sous-tâche, l'app me demande « quelle est la prochaine action concrète ? » et la crée dans Todoist.
- **Live Activity et widget iPhone**, Dynamic Island, raccourci dans la barre de menus du Mac.
- **Mode Concentration** : activer automatiquement un Focus Apple pendant une session.
- **Rappel quand rien n'est lancé** : après 20 minutes sans session en heures de travail, l'app demande pourquoi.
- **Alerte multi-chantier** : prévenir quand plus de deux tâches portent `Chantier-actif`.
- **Lecture directe du calendrier** (EventKit) si l'import des réunions dans Todoist ne suffit plus.
- **Apple Watch.**
- **Recommandation assistée par IA** pour suggérer l'ordre du matin, si les règles s'avèrent insuffisantes.

### Hors périmètre

- Publication sur l'App Store, multi-utilisateur, partage.
- Backend ou base de données serveur (Supabase compris). Todoist et iCloud suffisent.
- Création ou édition complète de tâches. Todoist reste l'outil pour ça.
- Notation impact / effort de chaque tâche.
- Blocage d'apps ou de sites web.
- Support Android, Windows ou web.
- Autres gestionnaires de tâches que Todoist.

## 3. Écrans et parcours

### Écrans

1. **Réglages** : saisie du token Todoist, durées par label, nom du projet qui représente le backlog Shop. Affiché seul au premier lancement.
2. **Plan du jour** : en haut, les réunions du jour. En dessous, la liste des candidates groupée par projet, avec priorité, échéance et labels. Je glisse les tâches dans une zone « Aujourd'hui » et les ordonne. Bouton Valider.
3. **Focus** (écran principal) : la tâche en cours, sa prochaine action en grand, la durée proposée, le temps avant la prochaine réunion. Boutons Démarrer, Passer, Changer de tâche.
4. **Session en cours** : minuteur, nom de l'action, boutons Pause, Interrompre, Terminer.
5. **Fin de session** : « Terminé » (coche dans Todoist), « Je continue » (nouvelle session sur la même action), « Pause ». Puis enchaînement automatique vers la pause ou la tâche suivante.
6. **Interruption** : choix de la raison, puis Reprendre ou Choisir autre chose. Option « Ajouter en tête du plan ».
7. **Stats** : vue semaine par défaut, onglets Focus et Backlog.

### Parcours principal

```
Ouverture
  └─ Plan du jour validé aujourd'hui ?
       ├─ Non → Plan du jour → Valider → Focus
       └─ Oui → Focus
Focus → Démarrer → Session en cours
  ├─ Fin du minuteur → Fin de session
  │     ├─ Terminé → coche Todoist → Pause → Focus (action suivante)
  │     └─ Je continue → Session en cours
  └─ Interrompre → Interruption → Reprendre ou Focus
```

### Navigation

- **Mac** : une fenêtre avec une barre latérale (Aujourd'hui, Stats, Réglages). Le minuteur reste visible dans la barre de menus.
- **iPhone** : trois onglets (Aujourd'hui, Stats, Réglages). Notification à la fin de chaque session.

## 4. Données

| Donnée | Source de vérité | Stockage côté app | Synchro |
|---|---|---|---|
| Tâches, sous-tâches, projets, sections, labels, priorités, échéances | Todoist | Cache en mémoire, rafraîchi à l'ouverture et à chaque retour au premier plan | Via Todoist |
| Réunions du jour | Todoist (tâches « Réunion · … » importées de l'agenda) | Cache en mémoire | Via Todoist |
| Tâches terminées | Todoist (l'app coche via l'API) | Aucun | Via Todoist |
| Token API Todoist | Moi | Trousseau (Keychain), synchronisé via le trousseau iCloud | iCloud Keychain |
| Plan du jour (liste ordonnée d'IDs de tâches, date) | App | SwiftData | CloudKit |
| Sessions (ID tâche, titre, projet, labels, début, fin, durée prévue, durée réelle, issue) | App | SwiftData | CloudKit |
| Interruptions (session, heure, raison, durée) | App | SwiftData | CloudKit |
| Instantanés du backlog (date, tâches ouvertes, âge moyen, nombre de chantiers actifs) | App, calculé depuis Todoist | SwiftData, un par jour | CloudKit |
| Réglages (durées par label, projet backlog, filtre) | App | SwiftData ou UserDefaults | CloudKit |

Remarques :

- Les sessions gardent une copie du titre et du projet de la tâche, pour que les stats restent lisibles une fois la tâche fermée ou supprimée dans Todoist.
- L'âge et le nombre de tâches ouvertes viennent de Todoist (`addedAt`). Un instantané quotidien permet de tracer la courbe dans le temps sans dépendre de l'historique de Todoist.

## 5. Choix techniques recommandés

- **Xcode, SwiftUI, une seule cible multiplateforme** (macOS et iOS).
- **SwiftData avec synchronisation CloudKit** pour les sessions et le plan du jour. Pas de Supabase : il n'y a qu'un utilisateur, aucune logique serveur, et iCloud synchronise déjà Mac et iPhone sans compte, sans serveur et sans coût de maintenance.
- **API Todoist** appelée directement depuis l'app avec `URLSession` et `async/await`. Le token personnel évite d'implémenter OAuth.
- **UserNotifications** pour les fins de session.
