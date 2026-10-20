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
| Liste de candidates | Filtre fixe : P1/P2, sans `Waiting`, avec `Chantier-actif` ou échéance dans les 3 jours. |
| Plan du jour | Je choisis et ordonne 3 tâches (5 maximum). Le plan est gardé pour la journée. |
| Prochaine action | Proposition de la première sous-tâche faisable de la tâche en cours. |
| Durée adaptée | `Quick` : 15 min. Par défaut : 25 min. `Deepwork` : 50 min. Pauses de 5 ou 10 min. Modifiable avant de lancer. |
| Minuteur | Démarrer, pause, reprendre, terminer. Notification de fin de session et de fin de pause. |
| Réunions | Lecture des tâches « Réunion · … » datées dans Todoist pour connaître les créneaux du jour. Proposition d'une tâche qui tient avant la prochaine réunion. |
| Interruptions | Bouton Interrompre avec raison (réunion, urgence, autre). Temps partiel enregistré. |
| Clôture | Cocher la sous-tâche ou la tâche dans Todoist depuis l'app. |
| Historique | Chaque session est enregistrée : tâche, projet, durée prévue, durée réelle, issue, interruptions. |
| Stats de base | Temps de focus par jour et par semaine, sessions par jour, interruptions par raison, temps par projet. |
| Stats backlog | Tâches ouvertes du backlog Shop, âge moyen, nombre de `Chantier-actif` en parallèle, tâches parentes fermées par semaine. |
| Barre de menus | Temps restant affiché en permanence, avec Pause, Reprendre et Ouvrir Done. |

### Plus tard

- **Réglage des règles** : modifier le filtre des candidates et les durées par label depuis l'app.
- **Découpage assisté** : si une tâche n'a pas de sous-tâche, l'app me demande « quelle est la prochaine action concrète ? » et la crée dans Todoist.
- **Version iPhone** avec synchronisation iCloud, Live Activity et widget. Demande un compte Apple Developer payant.
- **Mode Concentration** : activer automatiquement un Focus Apple pendant une session.
- **Rappel quand rien n'est lancé** : après 20 minutes sans session en heures de travail, l'app demande pourquoi.
- **Alerte multi-chantier** : prévenir quand plus de deux tâches portent `Chantier-actif`.
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
5. **Fin de session** : « Terminé, cocher dans Todoist », « Je continue », « Pause », « Arrêter là ».
6. **Interruption** : raison et durée de l'interruption, puis Reprendre, Choisir autre chose, ou Insérer une tâche urgente en tête du plan.
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

Une fenêtre avec une barre latérale : Focus, Plan du jour, Stats, Réglages. Le minuteur reste visible dans la barre de menus, même fenêtre fermée. ⌘R recharge les tâches Todoist.

## 4. Données

| Donnée | Source de vérité | Stockage côté app |
|---|---|---|
| Tâches, sous-tâches, projets, labels, priorités, échéances, durées | Todoist | En mémoire, rechargées au lancement, à ⌘R et au retour au premier plan (au plus une fois par minute) |
| Réunions du jour | Todoist (tâches « Réunion · … » datées avec une heure) | En mémoire |
| Tâches terminées | Todoist (l'app coche via l'API) | En mémoire, pour l'onglet Backlog (8 dernières semaines) |
| Token API Todoist | Moi | Trousseau du Mac |
| Plan du jour (date, IDs ordonnés, IDs terminés) | App | SwiftData, local |
| Sessions (tâche, tâche du plan, projet, labels, début, fin, durée prévue, durée réelle, issue) | App | SwiftData, local |
| Interruptions (raison, début, fin, session) | App | SwiftData, local |
| Photo du backlog (date, chantiers ouverts, tâches ouvertes, âge moyen et maximum, chantiers actifs) | App, calculée depuis Todoist | SwiftData, une par jour |
| Réglages | App | UserDefaults |

Remarques :

- Les sessions gardent une copie du titre et du projet de la tâche, pour que les stats restent lisibles une fois la tâche fermée ou supprimée dans Todoist.
- L'âge des tâches vient du champ `added_at` de Todoist. La photo quotidienne permet de tracer la courbe sans dépendre de l'historique de Todoist.
- Les données SwiftData restent sur le Mac. Rien n'est envoyé ailleurs que vers l'API Todoist.

## 5. Choix techniques

- **Xcode, SwiftUI, une cible macOS** (macOS 14 minimum, pour SwiftData et `@Observable`).
- **SwiftData local** pour le plan, les sessions et les photos du backlog. Pas de Supabase ni de CloudKit : un seul utilisateur, un seul appareil, aucune logique serveur.
- **API Todoist v1** (`https://api.todoist.com/api/v1/`) appelée avec `URLSession` et `async/await`. Le token personnel évite d'implémenter OAuth. Les formats ont été vérifiés dans le SDK Python officiel de Doist.
- **UserNotifications** pour les fins de session et de pause, **MenuBarExtra** pour le minuteur dans la barre de menus, **Swift Charts** pour les stats.
- App non sandboxée et signée localement : elle n'est pas distribuée.
