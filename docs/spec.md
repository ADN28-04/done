# Spécification : Done

Document de cadrage de la V1, **sur Mac uniquement**. Voir `vision.md` pour le problème et `questions.md` pour ce qui reste ouvert.

## 1. Scénarios d'usage

### S1. Le rituel du matin
J'arrive, je lis mes mails, j'ajoute des tâches dans Todoist si besoin. J'ouvre Done sur le Mac. L'app récupère les tâches et me montre une liste de candidates : P1 et P2, sans le label `Waiting`, avec `Chantier-actif` ou une échéance dans les 3 jours. Elle affiche aussi mes réunions du jour. Je glisse mes trois tâches dans l'ordre d'importance et je valide. Durée cible : moins de deux minutes.

### S2. Attaquer la tâche
L'écran Focus affiche la tâche n°1 et, en grand, sa prochaine sous-tâche faisable (non `Waiting`, première dans l'ordre Todoist). Exemple : pour « Mettre en ligne la LP Luminothérapie », l'app propose « Créer l'étiquette Saison hiver sur les 9 fiches » et ignore les deux relectures en attente. La durée est proposée selon le label. Je clique sur Démarrer.

### S3. Une session de deep work
Pendant mon bloc de 3 h, j'enchaîne des sessions de 50 minutes avec 10 minutes de pause. À la fin d'une session, l'app me demande : terminé, ou je continue ? Si je dis terminé, elle coche la sous-tâche dans Todoist et me montre la suivante.

### S4. Une réunion arrive
Une réunion est prévue à 14h00 et il est 13h40. L'app ne me propose pas une session de 50 minutes. Elle prend la prochaine tâche de ma liste qui tient dans 20 minutes, ou une tâche `Quick`. Si aucune ne tient, elle me propose de préparer la réunion ou de faire une pause.

Les créneaux d'agenda dont le titre contient « deepwork », « deepword » ou « focus » (comme « Réunion · Deepword » de 9h à 12h) sont des blocs de travail : ils sont affichés mais ne raccourcissent pas les sessions.

### S5. Une interruption imprévue
Un collègue m'appelle pendant une session. J'appuie sur Interrompre et je choisis la raison : réunion, urgence ou autre. Le minuteur se met en pause, le temps passé est enregistré. Quand je reviens, l'app me propose de reprendre ou de choisir autre chose. Si l'urgence devient prioritaire, je peux l'insérer en tête de ma liste du jour.

### S6. Garder un œil sur le minuteur
Je passe dans une autre app pendant une session. Le temps restant reste visible dans la barre de menus du Mac. Je peux mettre en pause ou rouvrir Done depuis ce menu, et une notification m'avertit de la fin de la session.

### S7. Faire le point
Le vendredi, j'ouvre l'écran Stats. Je vois le temps de focus de la semaine, les sessions par jour, les interruptions par raison, le temps passé par projet, et l'évolution du backlog Shop (tâches ouvertes, âge moyen, nombre de chantiers actifs en parallèle).

## 2. Fonctionnalités

### MVP (V1)

| Fonctionnalité | Détail |
|---|---|
| Connexion Todoist | Token API personnel collé une fois dans les réglages, stocké dans le Trousseau. Pas d'OAuth. |
| Lecture des tâches | Tâches, sous-tâches, projets, sections, labels, priorités, échéances, durées. |
| Liste de candidates | Filtre fixe : P1/P2, sans `Waiting`, avec `Chantier-actif` ou échéance dans les 3 jours. Une tâche datée au-delà de cet horizon n'est pas proposée, même `Chantier-actif` : la date est volontaire (« pas avant »). Une échéance Todoist (deadline) dans l'horizon l'emporte sur la date. |
| Plan du jour | Je choisis et ordonne 3 tâches (nombre réglable de 1 à 5). Le plan est gardé pour la journée. |
| Prochaine action | Proposition de la première sous-tâche faisable de la tâche en cours : ni `Waiting`, ni datée au-delà de l'horizon. Si plus rien n'est faisable, l'écran Focus indique la date de reprise. |
| Durée adaptée | `Quick` : 15 min. Par défaut : 25 min. `Deepwork` : 50 min. Pauses de 5 ou 10 min. Modifiable avant de lancer. |
| Minuteur | Démarrer, pause, reprendre, terminer. Notification de fin de session et de fin de pause, doublée d'un son joué par Done et du Dock qui rebondit jusqu'au retour dans l'app : la fin se remarque même si les notifications sont bloquées ou masquées. Réglages › Notifications montre si macOS les autorise et permet d'en envoyer une de test. |
| Réunions | Lecture des tâches « Réunion · … » datées dans Todoist pour connaître les créneaux du jour. Proposition d'une tâche qui tient avant la prochaine réunion. |
| Interruptions | Bouton Interrompre avec raison (réunion, urgence, autre). Temps partiel enregistré. |
| Clôture | Cocher la sous-tâche ou la tâche dans Todoist depuis l'app. |
| Historique | Chaque session est enregistrée : tâche, projet, durée prévue, durée réelle, issue, interruptions. |
| Stats de base | Temps de focus par jour et par semaine, sessions par jour, interruptions par raison, temps par projet. |
| Stats backlog | Tâches ouvertes du backlog Shop, âge moyen, nombre de `Chantier-actif` en parallèle, tâches parentes fermées par semaine. |
| Barre de menus | Temps restant affiché en permanence, avec Pause, Reprendre et Ouvrir Done. |
| Découpage assisté | L'écran Focus propose « Découper… » sur l'action en cours (sauf `Quick`), mis en avant quand la tâche du plan n'a pas encore de sous-tâche : je saisis la prochaine action concrète, Done la crée comme sous-tâche dans Todoist et la propose aussitôt. Aussi disponible depuis le bilan du soir. Avec une clé API Claude, le bouton devient « Découper avec Claude… » et Claude propose trois premières actions dès l'ouverture : Claude reçoit la tâche (projet, parent, sous-tâches voisines, note de reprise), ma méthode de découpage, quelques sous-tâches existantes comme exemples et la liste des fichiers d'un dossier de contexte choisi dans les Réglages, dont il lit ceux qui l'aident (5 par appel au plus). Je clique une proposition, je la retouche, puis Done la crée comme avant. |
| Garde-fou des chantiers actifs | À la validation du plan, si plus de tâches portent `Chantier-actif` que la cible (2 par défaut), une fenêtre propose de mettre en file d'attente les chantiers absents du plan. Done retire alors le label dans Todoist, sur la tâche et ses sous-tâches. Une fois par jour au plus. |
| Bilan du soir | À partir de 17 h (réglable), l'écran Focus propose le bilan : temps de focus, sessions, tâches cochées, interruptions, ce qui est terminé, et pour chaque tâche du plan non finie : Demain (reprise dans le plan du lendemain matin, marquée « Reportée ») ou Plus tard. Rappel par notification du lundi au vendredi. |
| Ne pas déranger | Activé pendant le focus, coupé en pause, en interruption, en fin de session et à la fermeture de Done. Passe par deux raccourcis de l'app Raccourcis, faute d'API publique. Désactivé par défaut. |
| Note de reprise | En fin de session ou pendant une interruption, un champ « Où tu en es ? » garde une ligne sur la tâche. Elle est réaffichée sur l'écran Focus et pendant la session suivante sur cette tâche, puis effacée quand la tâche est cochée ou disparaît de Todoist. |
| Réunion proche | Notification quelques minutes avant chaque réunion lue dans Todoist (5 min par défaut, réglable, blocs de travail exclus). Reprogrammée à chaque synchronisation. |

### Plus tard

- **Réglage des règles** : modifier le filtre des candidates et les durées par label depuis l'app.
- **Version iPhone** avec synchronisation iCloud, Live Activity et widget. Demande un compte Apple Developer payant.
- **Rappel quand rien n'est lancé** : après 20 minutes sans session en heures de travail, l'app demande pourquoi.
- **Lecture directe du calendrier** (EventKit) si l'import des réunions dans Todoist ne suffit plus.
- **Apple Watch.**
- **Recommandation assistée par IA** pour suggérer l'ordre du matin, si les règles s'avèrent insuffisantes.

### Hors périmètre

- Publication sur l'App Store, multi-utilisateur, partage.
- Backend ou base de données serveur (Supabase compris). Todoist et le stockage local suffisent.
- Création ou édition complète de tâches. Todoist reste l'outil pour ça.
- Notation impact / effort de chaque tâche.
- Blocage d'apps ou de sites web.
- iPhone et iPad en V1. Android, Windows ou web.
- Autres gestionnaires de tâches que Todoist.

## 3. Écrans et parcours

### Écrans

1. **Connexion** : saisie du token API Todoist. Affiché seul au premier lancement.
2. **Plan du jour** : en haut, les réunions et blocs du jour. À gauche, les candidates triées par priorité puis échéance, avec projet, échéance, sous-tâches et labels. À droite, la liste « Aujourd'hui » que j'ordonne par glisser-déposer (3 recommandées, 5 au maximum). Bouton « Chercher une autre tâche » pour ajouter une tâche hors candidates. Bouton Valider.
3. **Focus** (écran principal) : la tâche du plan, sa prochaine action en grand, la durée proposée (modifiable), le temps avant la prochaine réunion. Boutons Démarrer, Passer, Changer de tâche. En dessous, la suite du plan.
4. **Session en cours** : anneau de progression, minuteur, boutons Pause (barre d'espace), Interrompre (menu des raisons), Terminer.
5. **Fin de session** : champ « Où tu en es ? », puis « Terminé, cocher dans Todoist », « Je continue », « Pause », « Arrêter là ».
6. **Interruption** : raison et durée de l'interruption, champ « Où tu en es ? », puis Reprendre, Choisir autre chose, ou Insérer une tâche urgente en tête du plan.
7. **Pause** : compte à rebours, bouton Passer la pause.
8. **Stats** : onglet Focus (semaine par semaine) et onglet Backlog (évolution jour après jour).
9. **Réglages** : token, durées par label, horizon des candidates, préfixe des réunions, mots-clés des blocs de travail, cible de chantiers actifs, projets suivis dans les stats.

### Parcours principal

```
Ouverture
  └─ Plan du jour validé aujourd'hui ?
       ├─ Non → Plan du jour → Valider → Focus
       └─ Oui → Focus
Focus → Démarrer → Session en cours
  ├─ Fin du minuteur ou Terminer → Fin de session
  │     ├─ Terminé → coche Todoist → Pause → Focus (action suivante)
  │     ├─ Je continue → Session en cours
  │     └─ Pause / Arrêter là → Pause ou Focus
  └─ Interrompre → Interruption → Reprendre ou Focus
```

### Navigation

Une fenêtre sans barre latérale. La navigation passe par une barre d'onglets flottante, centrée en bas, façon iOS : une pilule en Liquid Glass (verre dépoli avant macOS 26) avec Focus, Plan du jour, Stats et Réglages, accessibles aussi par ⌘1 à ⌘4. Pendant une session (minuteur, pause, interruption, fin de session, pause café), la barre s'efface et revient quand la souris approche du bas de la fenêtre. Le minuteur reste visible dans la barre de menus, même fenêtre fermée. ⌘R recharge les tâches Todoist.

## 4. Données

| Donnée | Source de vérité | Stockage côté app |
|---|---|---|
| Tâches, sous-tâches, projets, labels, priorités, échéances, durées | Todoist | En mémoire, rechargées au lancement, à ⌘R et au retour au premier plan (au plus une fois par minute) |
| Réunions du jour | Todoist (tâches « Réunion · … » datées avec une heure) | En mémoire |
| Tâches terminées | Todoist (l'app coche via l'API) | En mémoire, pour l'onglet Backlog (8 dernières semaines) |
| Token API Todoist | Moi | Trousseau du Mac |
| Notes de reprise (texte, date, par tâche) | App | UserDefaults (`resume.notes`) |
| Clé API Claude | Moi | Trousseau du Mac |
| Dossier de contexte, modèle et méthode de découpage | App | UserDefaults (`claude.*`). Le dossier reste sur le Mac ; seuls les fichiers que Claude demande sont envoyés |
| Plan du jour (date, IDs ordonnés, IDs terminés) | App | SwiftData, local |
| Sessions (tâche, tâche du plan, projet, labels, début, fin, durée prévue, durée réelle, issue) | App | SwiftData, local |
| Interruptions (raison, début, fin, session) | App | SwiftData, local |
| Photo du backlog (date, chantiers ouverts, tâches ouvertes, âge moyen et maximum, chantiers actifs) | App, calculée depuis Todoist | SwiftData, une par jour |
| Réglages | App | UserDefaults |

Remarques :

- Les sessions gardent une copie du titre et du projet de la tâche, pour que les stats restent lisibles une fois la tâche fermée ou supprimée dans Todoist.
- L'âge des tâches vient du champ `added_at` de Todoist. La photo quotidienne permet de tracer la courbe sans dépendre de l'historique de Todoist.
- Les données SwiftData restent sur le Mac. Rien n'est envoyé ailleurs que vers l'API Todoist, sauf, au découpage avec Claude, la tâche, la méthode, quelques exemples, la liste des fichiers du dossier et les fichiers lus, vers l'API d'Anthropic.

## 5. Choix techniques

- **Xcode, SwiftUI, une cible macOS** (macOS 14 minimum, pour SwiftData et `@Observable`).
- **SwiftData local** pour le plan, les sessions et les photos du backlog. Pas de Supabase ni de CloudKit : un seul utilisateur, un seul appareil, aucune logique serveur.
- **API Todoist v1** (`https://api.todoist.com/api/v1/`) appelée avec `URLSession` et `async/await`. Le token personnel évite d'implémenter OAuth. Les formats ont été vérifiés dans le SDK Python officiel de Doist.
- **App Raccourcis** (`/usr/bin/shortcuts run`) pour « Ne pas déranger », macOS n'ayant pas d'API publique pour les modes de concentration.
- **API Claude** (`POST /v1/messages`, version `2026-10-21`) appelée en HTTP direct, faute de SDK Swift officiel : Claude Opus 5.5 par défaut avec repli automatique (`fallbacks: "default"`), réponse au format JSON imposé (`output_config.format`) et un outil `read_context_files` pour lire le dossier de contexte.
- **UserNotifications** pour les fins de session et de pause, les rappels du bilan et des réunions, **MenuBarExtra** pour le minuteur dans la barre de menus, **Swift Charts** pour les stats.
- App non sandboxée et signée localement : elle n'est pas distribuée.
