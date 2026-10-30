# Spécification : Done

Document de cadrage, **sur Mac uniquement**. Voir `vision.md` pour le problème et `questions.md` pour ce qui reste ouvert.

Done gère simplement une liste de tâches et un minuteur Pomodoro. Il ne dépend plus de Todoist : les tâches vivent dans l'app, sur le Mac.

## 1. Scénarios d'usage

### S1. Noter une tâche
Une demande arrive pendant que je travaille. ⌘N, depuis n'importe quel écran, même en pleine session : un champ, j'écris, Entrée. La tâche part dans l'Inbox. Plus tard, dans l'onglet Tâches, je la range dans un projet, je lui donne une priorité, une échéance si elle compte, et des étapes si elle est grosse.

### S2. Le rituel du matin
J'arrive, je lis mes mails, j'ajoute ce qui manque. Dans le Plan du jour, Done me montre une liste de candidates : les tâches P1 et P2, et celles qui arrivent à échéance dans les 3 jours ou sont en retard. Je saisis mes réunions du jour, je glisse mes trois tâches dans l'ordre d'importance et je valide. Durée cible : moins de deux minutes.

### S3. Attaquer la tâche
L'écran Focus affiche la tâche n°1 et, en grand, sa prochaine étape faisable (ni bloquée, ni datée plus tard, première dans l'ordre). Exemple : pour « Mettre en ligne la LP Luminothérapie », Done propose « Créer l'étiquette Saison hiver sur les 9 fiches » et ignore la relecture bloquée. La durée dépend du type de la tâche. Je clique sur Démarrer.

### S4. Une session de deep work
Pendant mon bloc de 3 h, j'enchaîne des sessions de 50 minutes avec 10 minutes de pause. Quand je finis une étape avant la sonnerie, « C'est fait » la coche et propose la suivante dans le temps qui reste.

### S5. Une réunion arrive
Une réunion est prévue à 14h00 et il est 13h40. Done ne me propose pas une session de 50 minutes. Il prend la prochaine tâche du plan qui tient dans 20 minutes, ou une tâche rapide. Si aucune ne tient, il propose de préparer la réunion ou de faire une pause.

### S6. Une interruption imprévue
Un collègue m'appelle pendant une session. J'appuie sur Interrompre et je choisis la raison : réunion, urgence ou autre. Le minuteur se met en pause, le temps passé est enregistré. Quand je reviens, Done me propose de reprendre ou de choisir autre chose. Si l'urgence devient prioritaire, je peux l'insérer en tête du plan.

### S7. Garder un œil sur le minuteur
Je passe dans une autre app pendant une session. Le temps restant reste visible dans la barre de menus. Je peux mettre en pause ou rouvrir Done depuis ce menu, et une notification m'avertit de la fin de la session.

### S8. Faire le point
Le soir, Done propose le bilan : temps de focus, sessions, tâches cochées, et ce qui reste du plan, à reporter à demain ou plus tard. Le vendredi, l'onglet Stats montre la semaine.

## 2. Fonctionnalités

### Actuelles

| Fonctionnalité | Détail |
|---|---|
| Tâches | Titre, notes, liste (Inbox ou projet), priorité P1 à P4, type (normale, rapide, Deepwork), échéance facultative (un jour), étapes (sous-tâches, sur plusieurs niveaux), marquage « bloquée ». Ajouter, modifier, cocher, rouvrir, supprimer, réordonner par glisser-déposer. |
| Projets | Listes simples, en plus de l'Inbox. Créer, renommer, réordonner, supprimer (les tâches passent alors dans l'Inbox). Glisser une tâche sur une liste l'y range. |
| Capture rapide | ⌘N depuis n'importe quel écran, même en session : une ligne, Entrée, la tâche part dans l'Inbox (ou la liste choisie). |
| Liste de candidates | Les tâches P1 et P2, et toutes celles dont l'échéance tombe dans les 3 jours ou est dépassée. Ni bloquées, ni datées plus loin : une date lointaine est volontaire (« pas avant »). |
| Plan du jour | Je choisis et ordonne 3 tâches (nombre réglable de 1 à 5). Le plan est gardé pour la journée. Une tâche peut aussi y être ajoutée depuis l'onglet Tâches. |
| Réunions | Saisies à la main dans le Plan du jour : titre, jour, début, fin. Affichées dans la pastille du haut, prises en compte pour proposer une tâche qui tient avant la prochaine. Oubliées le lendemain. |
| Prochaine action | La première étape faisable de la tâche en cours : ni bloquée, ni datée au-delà de l'horizon. Si plus rien n'est faisable, l'écran Focus indique la date de reprise. |
| Durée adaptée | Rapide : 15 min. Par défaut : 25 min. Deepwork : 50 min. Pauses de 5 ou 10 min. Modifiable avant de lancer. |
| Minuteur | Démarrer, pause, reprendre, « C'est fait ». Rallonge de 5 min en cours ou en fin de session, 10 min au plus par pomodoro. Une étape cochée avant la fin enchaîne sur la suivante de la même tâche, dans le temps qui reste. Pause obligatoire avant de changer de tâche principale. Notification de fin de session et de fin de pause, doublée d'un son joué par Done et du Dock qui rebondit jusqu'au retour dans l'app. Réglages › Notifications montre si macOS les autorise et permet d'en envoyer une de test. |
| Interruptions | Bouton Interrompre avec raison (réunion, urgence, autre). Temps partiel enregistré. |
| Étape bloquée | « Bloqué… » en session ou en fin de session : je dis en une ligne ce qui bloque. L'étape reste dans la liste, marquée bloquée, avec la raison en note de reprise. Done passe à l'étape suivante de la même tâche dans le temps qui reste (une minute au moins, sinon pause). S'il n'y en a pas, pause obligatoire puis tâche suivante du plan. Je la débloque dans l'onglet Tâches. |
| Découpage | « Découper… » sur l'écran Focus (sauf tâche rapide), dans l'onglet Tâches et dans le bilan du soir : je saisis les étapes qui mènent la tâche au bout, dans l'ordre (10 au plus). Done les propose ensuite une par une, puis la tâche elle-même pour la clore. |
| Historique | Chaque session est enregistrée : tâche, projet, durée prévue, durée réelle, issue, interruptions. |
| Stats | Temps de focus par jour et par semaine, sessions, tâches cochées, interruptions, temps par projet. |
| Barre de menus | Temps restant affiché en permanence, avec Pause, Reprendre et Ouvrir Done. |
| Bilan du soir | À partir de 17 h (réglable), l'écran Focus propose le bilan : temps de focus, sessions, tâches cochées, interruptions, ce qui est terminé, et pour chaque tâche du plan non finie : Demain (reprise dans le plan du lendemain matin, marquée « Reportée ») ou Plus tard. Rappel par notification du lundi au vendredi. |
| Ne pas déranger | Activé pendant le focus, coupé en pause, en interruption, en fin de session et à la fermeture de Done. Passe par deux raccourcis de l'app Raccourcis, faute d'API publique. Désactivé par défaut. |
| Note de reprise | En fin de session ou pendant une interruption, un champ « Où tu en es ? » garde une ligne sur la tâche. Elle est réaffichée sur l'écran Focus et pendant la session suivante sur cette tâche, puis effacée quand la tâche est cochée ou supprimée. |
| Réunion proche | Notification quelques minutes avant chaque réunion (5 min par défaut, réglable), pour les sept prochains jours. |
| Sauvegarde | Le fichier des tâches est réécrit à chaque changement. Une copie par jour, gardée 30 jours. Un fichier illisible est mis de côté, jamais écrasé. |

### Plus tard

- **Tâches récurrentes** (« tous les lundis »), si le besoin se confirme.
- **Saisie des dates en français** dans la capture rapide (« demain », « jeudi »).
- **Rappel quand rien n'est lancé** : après 20 minutes sans session en heures de travail, Done demande pourquoi.
- **Export** de la liste dans un format lisible ailleurs, si je change d'outil un jour.

### Hors périmètre

- Todoist, ou toute synchronisation avec un autre gestionnaire de tâches. Pas d'import : la liste repart de zéro.
- Serveur, compte, synchronisation entre appareils, accès par Claude ou par une autre app.
- IA intégrée (le découpage par l'API Claude a été retiré).
- Chantiers, attentes, personnes, dépendances, calcul de charge : la liste reste simple.
- Lecture du calendrier : les réunions se saisissent à la main.
- Publication sur l'App Store, multi-utilisateur, partage.
- iPhone, iPad, Android, Windows ou web.
- Blocage d'apps ou de sites web.

## 3. Écrans et parcours

### Écrans

1. **Focus** (écran principal) : la tâche du plan, sa prochaine action en grand, la durée proposée (modifiable), le temps avant la prochaine réunion. Boutons Démarrer, Passer, Changer de tâche, Découper. Sans tâche du tout, une invitation à en ajouter.
2. **Tâches** : à gauche, l'Inbox et les projets avec leur nombre de tâches ouvertes. À droite, la liste choisie : champ d'ajout en haut, tâches et étapes indentées, case à cocher de la couleur de la priorité, une ligne de détails (échéance, étapes, type, « Bloquée »), pastille « Aujourd'hui » si la tâche est dans le plan. Un clic ouvre la fiche ; clic droit pour l'échéance, la priorité, le type, le déplacement, le plan du jour, le découpage, le blocage ou la suppression. En bas, les tâches terminées récemment, à rouvrir si besoin.
3. **Fiche d'une tâche** : titre, notes, liste, priorité, type, échéance, bloquée, étapes (ajoutées et cochées tout de suite), Supprimer, Enregistrer (⌘↩).
4. **Capture rapide** (⌘N) : une ligne et le choix de la liste.
5. **Plan du jour** : à gauche, les candidates triées par priorité puis échéance. À droite, la liste « Aujourd'hui » que j'ordonne par glisser-déposer (3 recommandées, 5 au maximum), puis les réunions à venir avec « Ajouter ». Bouton « Chercher une autre tâche ». Bouton Valider.
6. **Session en cours** : anneau de progression, minuteur, repère « Encore N étapes après celle-ci » pour une tâche découpée, boutons Pause (barre d'espace), Interrompre (menu des raisons), C'est fait (⌘↩), « Ajouter 5 min » tant que la rallonge le permet, et « Bloqué… ».
7. **Fin de session** :
   - Minuteur fini : champ « Où tu en es ? », puis « Cocher la tâche », « Encore 5 min », « Pause, puis je reprends », « Bloqué… », « Arrêter là ».
   - Étape cochée en avance : « Étape terminée », la suivante sous « Ensuite », puis « Enchaîner · MM:SS restantes », « Pause d'abord », « Arrêter là ». Quand toutes les étapes sont faites : « Cocher « tâche » ».
   - Feuille « Bloqué » : ce qui bloque en une ligne, ce qui vient ensuite, puis « Laisser ouverte et passer à la suite ».
8. **Interruption** : raison et durée de l'interruption, champ « Où tu en es ? », puis Reprendre, Choisir autre chose, ou Insérer une tâche urgente en tête du plan.
9. **Pause** : compte à rebours, la prochaine action sous « Ensuite », bouton Passer la pause. Avant une nouvelle tâche principale, la pause est obligatoire : pas de bouton pour la passer.
10. **Stats** : la semaine, avec le temps de focus par jour et par projet.
11. **Réglages** : durées, tâches par jour, horizon des candidates, bilan du soir, Ne pas déranger, notifications, emplacement du fichier des tâches.

### Parcours principal

```
Ouverture
  └─ Des tâches ?
       ├─ Non → Tâches (ajouter)
       └─ Oui → Plan du jour validé aujourd'hui ?
            ├─ Non → Plan du jour → Valider → Focus
            └─ Oui → Focus
Focus → Démarrer → Session en cours
  ├─ C'est fait avant la fin → tâche cochée
  │     ├─ Étape suivante de la même tâche → Enchaîner (temps restant) ou Pause
  │     ├─ Dernière étape → Cocher la tâche principale → Pause obligatoire → Focus
  │     └─ Tâche principale finie ou bloquée → Pause obligatoire → Focus
  ├─ Fin du minuteur → Fin de session
  │     ├─ Cocher → même suite que ci-dessus, sans enchaînement (Pause)
  │     ├─ Encore 5 min → Session en cours (10 min au plus)
  │     └─ Pause, puis je reprends / Arrêter là → Pause ou Focus
  ├─ Bloqué… → étape marquée bloquée
  │     ├─ Autre étape ouverte dans la même tâche → Session en cours sur cette étape (ou Pause s'il reste moins d'une minute)
  │     └─ Aucune → Pause obligatoire → Focus
  └─ Interrompre → Interruption → Reprendre ou Focus
```

### Navigation

Une fenêtre sans barre latérale. La navigation passe par une barre d'onglets flottante, centrée en bas : une pilule en Liquid Glass (verre dépoli avant macOS 26) avec Focus, Tâches, Plan du jour, Stats et Réglages, accessibles aussi par ⌘1 à ⌘5. Pendant une session (minuteur, pause, interruption, fin de session, pause café), la barre s'efface et revient quand la souris approche du bas de la fenêtre. Le minuteur reste visible dans la barre de menus, même fenêtre fermée. ⌘N ouvre la capture rapide partout.

## 4. Données

| Donnée | Stockage |
|---|---|
| Tâches (ouvertes et terminées), projets, réunions | Fichier JSON local : `~/Library/Application Support/com.adnan.done/tasks.json`, réécrit en entier, de façon atomique, à chaque changement. Une copie par jour dans `Sauvegardes`, 30 jours gardés. |
| Plan du jour (date, identifiants ordonnés, identifiants terminés) | SwiftData, local |
| Sessions (tâche, tâche du plan, projet, type, début, fin, durée prévue, durée réelle, issue) | SwiftData, local |
| Interruptions (raison, début, fin, session) | SwiftData, local |
| Notes de reprise (texte, date, par tâche) | UserDefaults (`resume.notes`) |
| Bilan du soir, report au lendemain | UserDefaults (`review.lastDay`, `review.carryOver`) |
| Réglages | UserDefaults |

Remarques :

- Le fichier des tâches porte un numéro de version (`version`). Un champ absent prend sa valeur par défaut à la lecture : un fichier plus ancien reste lisible.
- Une échéance est enregistrée comme un jour (« 2026-10-31 »), sans heure ni fuseau.
- Les sessions gardent une copie du titre et du projet de la tâche, pour que les stats restent lisibles une fois la tâche cochée ou supprimée.
- Rien ne quitte le Mac.

## 5. Choix techniques

- **Xcode, SwiftUI, une cible macOS** (macOS 14 minimum, pour SwiftData et `@Observable`).
- **Tâches en JSON**, plutôt qu'en SwiftData : un fichier lisible, facile à sauvegarder et à restaurer, et une logique (`TaskStore`) testable sans l'app.
- **SwiftData local** pour le plan, les sessions et les interruptions. Le modèle `BacklogSnapshot`, hérité de la version Todoist, reste déclaré pour ouvrir les bases existantes sans migration.
- **App Raccourcis** (`/usr/bin/shortcuts run`) pour « Ne pas déranger », macOS n'ayant pas d'API publique pour les modes de concentration.
- **UserNotifications** pour les fins de session et de pause, les rappels du bilan et des réunions, **MenuBarExtra** pour le minuteur dans la barre de menus.
- App non sandboxée et signée localement : elle n'est pas distribuée.
- Aucune dépendance externe, aucun appel réseau.
