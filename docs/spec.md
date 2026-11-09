# Spécification : Done

Document de cadrage, **sur Mac uniquement**. Voir `vision.md` pour le problème et `questions.md` pour ce qui reste ouvert.

Done gère simplement une liste de tâches et un minuteur Pomodoro. Il ne dépend plus de Todoist : les tâches vivent dans l'app, sur le Mac.

## 1. Scénarios d'usage

### S1. Noter une tâche
Une demande arrive pendant que je travaille, dans une autre app. ⌃⌥N ouvre une fenêtre de saisie par-dessus : j'écris le titre, Entrée, et la tâche part dans l'Inbox. Si je sais déjà où la ranger, je choisis aussi le projet, la priorité, le type, l'échéance, et j'ajoute les étapes avant de valider : la tâche est complète dès sa création. Depuis Done, ⌘N ouvre la même saisie.

### S2. Le rituel du matin
J'arrive, je lis mes mails, j'ajoute ce qui manque. Ma journée m'accueille d'une phrase qui résume la journée ; « Préparer le plan » ouvre le Plan du jour, où Done me montre une liste de candidates : les tâches P1 et P2, et celles qui arrivent à échéance dans les 3 jours ou sont en retard. Je saisis mes réunions du jour, je glisse mes trois tâches dans l'ordre d'importance et je valide. Durée cible : moins de deux minutes.

### S3. Attaquer la tâche
La carte Prochaine action de Ma journée affiche la tâche n°1 et, en grand, sa prochaine étape faisable (ni bloquée, ni datée plus tard, première dans l'ordre). Exemple : pour « Mettre en ligne la LP Luminothérapie », Done propose « Créer l'étiquette Saison hiver sur les 9 fiches » et ignore la relecture bloquée. La durée dépend du type de la tâche. Je clique sur « Lancer le focus » : la session passe en plein écran.

### S4. Une session de deep work
Pendant mon bloc de 3 h, j'enchaîne des sessions de 50 minutes avec 10 minutes de pause. Quand je finis une étape avant la sonnerie, « C'est fait » la coche et propose la suivante dans le temps qui reste.

### S5. Une réunion arrive
Une réunion est prévue à 14h00 et il est 13h40. Done ne me propose pas une session de 50 minutes. Il prend la prochaine tâche du plan qui tient dans 20 minutes, ou une tâche rapide. Si aucune ne tient, il propose de préparer la réunion ou de faire une pause.

### S6. Une interruption imprévue
Un collègue m'appelle pendant une session. J'appuie sur Interrompre et je choisis la raison : réunion, urgence ou autre. Le minuteur se met en pause, le temps passé est enregistré. Quand je reviens, Done me propose de reprendre ou de choisir autre chose. Si l'urgence devient prioritaire, je peux l'insérer en tête du plan.

### S7. Garder un œil sur le minuteur
Je passe dans une autre app pendant une session. Le temps restant reste visible dans la barre de menus. Je peux mettre en pause ou rouvrir Done depuis ce menu, et une notification m'avertit de la fin de la session.

### S8. Faire le point
Le soir, Done propose le bilan : temps de focus, sessions, tâches cochées, et ce qui reste du plan, à reporter à demain ou plus tard. Le vendredi, l'écran Stats montre la semaine.

### S9. Travailler avec Claude
Dans Claude, sur le Mac, je demande où en est un projet, de préparer le plan de demain, de transformer un compte rendu en tâches ou de compléter la page d'un projet. Claude lit Done et y écrit par le connecteur ; Done, s'il est ouvert, montre aussitôt le résultat. Claude ne supprime rien.

## 2. Fonctionnalités

### Actuelles

| Fonctionnalité | Détail |
|---|---|
| Tâches | Titre, notes, liste (Inbox ou projet), étiquettes, priorité P1 à P4, type (normale, rapide, Deepwork), échéance facultative (un jour), étapes (sous-tâches, sur plusieurs niveaux), marquage « bloquée ». Ajouter, modifier, cocher, rouvrir, supprimer, réordonner par glisser-déposer. Dans une liste, une tâche cochée reste une seconde à sa place, barrée avec « Fait », puis part ; un second clic pendant cette seconde annule. |
| Projets et sous-projets | Listes simples, en plus de l'Inbox, pour les chantiers qui ont une fin. Un projet peut contenir des sous-projets, sur un seul niveau : sa vue montre ses propres tâches, puis celles de chaque sous-projet, groupées sous leur nom (un clic sur le nom ouvre le sous-projet). Créer, renommer, réordonner parmi ceux de même niveau, ranger dans un autre projet ou en sortir, supprimer (les tâches passent alors dans l'Inbox, les sous-projets deviennent des projets). Glisser une tâche sur une liste l'y range. |
| Étiquettes | Pour ce qui n'est pas un chantier : le run (« Run Shop » et ses thèmes), « Plus tard », une personne. Une tâche de premier niveau en porte autant qu'il faut, une étape suit celles de sa tâche. Chaque étiquette a sa vue dans l'écran Listes, avec les tâches de tous les projets ; une tâche ajoutée depuis cette vue la porte. L'Inbox ne garde que ce qui n'a ni projet ni étiquette : ce qui reste à trier. Renommer une étiquette (vers un nom existant, elles se fondent) ou la retirer de toutes ses tâches, au clic droit. Glisser une tâche sur une étiquette la lui ajoute ; sur l'Inbox, lui retire projet et étiquettes. Une étiquette sans tâche ouverte disparaît. |
| Capture rapide | ⌘N dans Done, même en session, ou un raccourci global (⌃⌥N par défaut, réglable) depuis n'importe quelle app, tant que Done tourne. La saisie porte tous les détails : titre, notes, liste, priorité, type, échéance et étapes. Entrée dans le titre ajoute tout de suite, dans l'Inbox par défaut ; ⌘ Entrée ajoute depuis n'importe quel champ. Le champ d'ajout des listes et le panneau de la barre de menus restent en une ligne, avec « Détails… » pour passer à la saisie complète. En bas de Ma journée, la barre de saisie note une tâche, une note ou une réunion sans quitter l'écran : Entrée ajoute, ⌘ Entrée ouvre la saisie complète, et « Ajoutée dans Inbox » confirme. Partout, la fin du titre se lit en français : « Relire la spec demain p1 #Shop » donne l'échéance, la priorité et l'étiquette ; aussi « jeudi », « lundi prochain », « dans 3 jours », « fin du mois », « le 12 », « 12/11 », « 1er déc. », et une répétition (« chaque lundi », « tous les jours »). Seule la fin du titre est lue, et ce qui est compris s'affiche en puces avant l'ajout. |
| Tâches récurrentes | Chaque jour, jours ouvrés, certains jours de la semaine, toutes les deux semaines ou chaque mois, réglé dans la fiche ou à la saisie. Une tâche récurrente a une échéance. Cochée, elle laisse place à la suivante (mêmes détails, étapes rouvertes) ; l'échéance suivante se compte depuis la sienne et tombe après aujourd'hui : un reporting du lundi coché mercredi revient lundi prochain. Rouvrir la tâche retire la suivante si elle n'a pas bougé. Puce « Chaque lundi » sur la ligne. |
| Boîte Rappels | Depuis l'iPhone, on note dans la liste Rappels « Done » (Siri, widget, partage), synchronisée par iCloud. Done la lit au lancement, à chaque changement apporté par iCloud et toutes les cinq minutes. Un rappel au titre d'une tâche ouverte, étapes comprises (casse, accents et espaces ignorés), la met à jour : échéance et priorité s'il en a (haute en P1, moyenne en P2, basse en P3), notes et lien ajoutés à la suite. Coché, il coche la tâche. Sinon il devient une tâche de l'Inbox. Le rappel traité est supprimé de Rappels. Si plusieurs tâches portent le titre, le rappel reste, avec une note qui demande de le préciser. Activée et nom de liste dans Réglages › Rappels de l'iPhone. |
| Liste de candidates | Les tâches P1 et P2, et toutes celles dont l'échéance tombe dans les 3 jours ou est dépassée. Ni bloquées, ni datées plus loin : une date lointaine est volontaire (« pas avant »). |
| Plan du jour | Je choisis et ordonne 3 tâches (nombre réglable de 1 à 5). Le plan est gardé pour la journée. Une tâche peut aussi y être ajoutée depuis sa liste (clic droit). Le Plan du jour s'ouvre en feuille depuis Ma journée (« Préparer le plan », « Modifier ») ; on peut aussi glisser une échéance sur la carte du plan. Quand tout le plan est coché, Ma journée l'annonce : « Plan du jour terminé. Tout ce qui était prévu est fait. », avec « Ajouter au plan » pour continuer. |
| Réunions | Saisies à la main dans la ligne de temps de Ma journée, le calendrier ou la barre de saisie : titre, jour, début, fin. Affichées sur la ligne de temps de Ma journée et dans le calendrier, prises en compte pour proposer une tâche qui tient avant la prochaine. On les glisse pour changer l'heure (au calendrier, aussi le jour) et on étire leur bord bas pour la durée, au quart d'heure, jamais vers le passé. Une réunion peut revenir régulièrement (chaque jour, jours ouvrés, certains jours de la semaine, toutes les deux semaines, chaque mois), sans fin ou jusqu'à une date (« Jusqu'au ») : Done crée ses occurrences pour la semaine en cours, la suivante et celle qu'affiche le calendrier. Une occurrence déplacée, renommée ou supprimée ne change qu'elle ; modifier sa fiche demande « Cette réunion seulement » ou « Toutes les suivantes », et « Jamais » arrête la série. Gardées jusqu'à la fin de la semaine, puis oubliées (la série, elle, reste). |
| Blocs de travail | Du temps réservé au calendrier pour une tâche. On le crée en déposant une tâche sur la grille (depuis les échéances du calendrier, ou depuis le plan et les échéances de Ma journée), ou d'un clic sur un créneau, « Bloquer pour une tâche… ». Il dure un pomodoro selon le type de la tâche (rapide, normale, Deepwork), puis se glisse et s'étire comme une réunion ; au calendrier, glissé au-dessus de la grille, il disparaît et sa tâche prend ce jour pour échéance. Tant qu'un bloc est à venir, sa tâche quitte les échéances du calendrier et de Ma journée : elle n'apparaît pas deux fois ; le bloc passé sans que la tâche soit faite, elle y revient. Une notification arrive 5 min avant : « Lancer le pomodoro » démarre la session sur la tâche (ou la pause due avant de changer de tâche), « Décaler de 30 min » repousse le bloc sans ouvrir Done (son rappel suit), « Déplacer… » ouvre le bloc au calendrier. Pendant le bloc, Ma journée propose sa tâche, pour au plus ce qui reste du bloc. Un bloc compte comme du temps pris dans les créneaux libres, mais n'empêche pas de lancer une session comme une réunion. Gardés jusqu'à la fin de la semaine. |
| Calendrier | La semaine de travail, du lundi au vendredi (⌘2). En haut de chaque jour, les tâches à échéance ; aujourd'hui reprend aussi les retards. Glisser une tâche sur un autre jour, aujourd'hui ou plus tard, change son échéance ; un clic ouvre sa fiche. Dessous, une grille de 8 h à 19 h : les réunions hachurées (un clic les modifie ou les supprime ; on les glisse et on les étire), les blocs de travail, le focus déjà fait, l'heure courante. Un clic sur un créneau libre propose une réunion d'une heure ou un bloc pour une tâche ; une tâche déposée sur la grille y prend un bloc. Le week-end, il montre la semaine qui vient. |
| Ma journée | L'écran d'arrivée (⌘1). En haut, une salutation qui suit le moment de la journée (formule qui change d'un jour à l'autre, prénom des Réglages ou du compte macOS) et une phrase de faits (« trois tâches et deux réunions aujourd'hui »). Six cartes : la prochaine action, avec « Lancer le focus » ; la ligne de temps du jour, de l'heure courante moins une jusqu'à 19 h, avec les créneaux libres et les pomodoros qui y tiennent (un clic sur un créneau libre lance la prochaine action, ailleurs il ajoute une réunion) ; le plan du jour ; les échéances et retards hors plan ; les notes, le journal du jour en premier ; le focus du jour, les tâches cochées, l'Inbox à trier et la semaine. En bas, la barre de saisie. Au clavier, ↑ ↓, Espace et ↩ parcourent le plan et les échéances. |
| Recherche | ⌘K, depuis n'importe quel écran : tâches ouvertes, notes et réunions, sans tenir compte des majuscules ni des accents, cinq résultats au plus par groupe. ↑ ↓ choisissent, Entrée ouvre la fiche, Échap ferme. |
| Notes | Pour documenter projets et tâches, en plus simple que Capacities. Une note est une page Markdown avec un type : Note, Réunion, Décision, Personne, Référence ; Done crée aussi la page de projet et le journal. Elle se rattache à un projet, des étiquettes, des tâches et, pour une réunion ou le journal, une date. [[Titre]] lie une autre note (un lien vers une note qui n'existe pas la crée) ; chaque note montre ses liens et les notes qui la citent. Aperçu mis en forme, cases à cocher cliquables, édition au double-clic ou avec ⌘E, enregistrement automatique. Écran Notes (⌘3) : recherche, filtre par type, et les notes en mosaïque de cartes, teintées selon leur type ; les cases s'y cochent directement. La vue d'un projet montre sa page de documentation et ses notes ; une réunion (fiche ouverte depuis le calendrier ou Ma journée) propose sa note préremplie ; Ma journée ouvre la note du jour ; la fiche d'une tâche liste ses notes. |
| Connecteur Claude | Claude sur ce Mac (l'app de bureau, projets compris, et Claude Code) lit et écrit dans Done par un connecteur MCP local : l'exécutable de Done lancé avec `--mcp`, sans fenêtre, même app fermée. Lecture : point de la journée, tâches (filtres par projet, étiquette, Inbox, texte, échéance, état), fiche d'une tâche avec sa note de reprise, projets et étiquettes, calendrier jour par jour, notes et leurs liens. Écriture : créer et modifier des tâches et leurs étapes, cocher, rouvrir ; créer, renommer et ranger des projets ; renommer une étiquette ; créer et compléter des notes ; ajouter et déplacer des réunions ; poser une absence ; fixer le plan du jour. Aucune suppression. Done ouvert reprend les changements en moins d'une seconde ; le plan du jour demandé par Claude est appliqué dès que Done le voit. Inscription en un clic dans Réglages › Claude (app de bureau), ou par une commande copiée (Claude Code). |
| Jours d'absence | Congé, férié ou autre libellé, posés depuis le menu d'un jour du calendrier. Ce jour-là, Ma journée le signale et ne propose rien, sauf « Travailler quand même ». |
| Prochaine action | La première étape faisable de la tâche en cours : ni bloquée, ni datée au-delà de l'horizon. Si plus rien n'est faisable, Ma journée le dit et propose de revoir le plan. |
| Durée adaptée | Rapide : 15 min. Par défaut : 25 min. Deepwork : 50 min. Pauses de 5 ou 10 min. Modifiable avant de lancer. |
| Minuteur | Démarrer, pause, reprendre, « C'est fait ». Rallonge de 5 min en cours ou en fin de session, 10 min au plus par pomodoro. Une étape cochée avant la fin enchaîne sur la suivante de la même tâche, dans le temps qui reste. Pause obligatoire avant de changer de tâche principale. Notification de fin de session et de fin de pause, doublée d'un son joué par Done et du Dock qui rebondit jusqu'au retour dans l'app. Réglages › Notifications montre si macOS les autorise et permet d'en envoyer une de test. |
| Interruptions | Bouton Interrompre avec raison (réunion, urgence, autre). Temps partiel enregistré. |
| Étape bloquée | « Bloqué… » en session ou en fin de session : je dis en une ligne ce qui bloque. L'étape reste dans la liste, marquée bloquée, avec la raison en note de reprise. Done passe à l'étape suivante de la même tâche dans le temps qui reste (une minute au moins, sinon pause). S'il n'y en a pas, pause obligatoire puis tâche suivante du plan. Je la débloque dans sa liste. |
| Découpage | « Découper… » sur la carte Prochaine action (sauf tâche rapide), dans les listes (clic droit) et dans le bilan du soir : je saisis les étapes qui mènent la tâche au bout, dans l'ordre (10 au plus). Done les propose ensuite une par une, puis la tâche elle-même pour la clore. |
| Réussites | Cocher une tâche, finir un pomodoro et boucler le plan du jour s'accompagnent d'une courte animation : case qui rebondit, éclat de pétales braise, rose et jaune, titre barré, série de pomodoros. Rien d'autre ne bouge sans action, sauf le minuteur et deux touches d'ambiance très lentes (halos de la toile qui dérivent, soleil de la date qui fait un tour à l'ouverture de Ma journée). Changer d'écran se fait en fondu léger. Avec « Réduire les animations » de macOS, il ne reste que des fondus. |
| Historique | Chaque session est enregistrée : tâche, projet, durée prévue, durée réelle, issue, interruptions. |
| Stats | (⌘5) La semaine en six cartes, comme Ma journée. Focus de la semaine (total, écart avec la semaine d'avant, jusqu'au même moment pour la semaine en cours ; sessions, tâches cochées, plans bouclés). Pomodoros et série (jours d'affilée avec au moins un pomodoro ; un week-end ou un jour de congé ne la casse pas, le jour en cours non plus ; meilleur jour, moyenne par jour travaillé). Par jour (barres, pomodoros en pastilles, soleil sur la meilleure journée et sur les plans bouclés). Tes meilleures heures (focus par heure sur quatre semaines, les deux heures d'affilée les plus concentrées). Par projet (six au plus, puis « Autres projets »). Interruptions (par raison, et la part des sessions sans interruption). Les barres poussent à l'arrivée et quand on change de semaine. |
| Barre de menus | Temps restant affiché en permanence. Au clic, un panneau avec la capture rapide en haut, puis une carte qui dit quoi faire maintenant : au repos, la prochaine action (ou la tâche du bloc de travail en cours) et « Lancer le focus », qui démarre la session sans ouvrir Done ; en session, le minuteur, Pause ou Reprendre et C'est fait ; en pause, le temps qui reste et « Passer la pause » ; en fin de pomodoro, « Cocher la tâche », « Encore 5 min » et « Pause » (le reste se fait dans Done). Sans plan, « Choisir le plan » ouvre Done sur le Plan du jour. Dessous, la journée en une ligne : pomodoros, focus et avancée du plan. Au repos, une fois le plan du jour bouclé, un soleil monochrome remplace le glyphe de Done. |
| Bilan du soir | À partir de 17 h (réglable), la carte Prochaine action de Ma journée laisse place au bilan (« Plus tard » pour y revenir) : temps de focus, sessions, tâches cochées, interruptions, ce qui est terminé, et pour chaque tâche du plan non finie : Demain (reprise dans le plan du lendemain matin, marquée « Reportée ») ou Plus tard. Rappel par notification du lundi au vendredi. |
| Ne pas déranger | Activé pendant le focus, coupé en pause, en interruption, en fin de session et à la fermeture de Done. Passe par deux raccourcis de l'app Raccourcis, faute d'API publique. Désactivé par défaut. |
| Note de reprise | En fin de session ou pendant une interruption, un champ « Où tu en es ? » garde une ligne sur la tâche. Elle est réaffichée sur Ma journée et pendant la session suivante sur cette tâche, puis effacée quand la tâche est cochée ou supprimée. |
| Réunion proche | Notification quelques minutes avant chaque réunion (5 min par défaut, réglable), pour les sept prochains jours. |
| Rien n'est lancé | Au bout de 20 min sans session ni pause, en semaine de 9 h à 18 h, une notification nomme la prochaine action. « Lancer le pomodoro » la démarre (ou la pause due avant de changer de tâche), « Pas maintenant » la laisse se taire. Rien pendant une réunion, un bloc de travail ou un jour de congé, ni quand une réunion est trop proche pour un pomodoro ; au plus une fois par heure, et le compte repart de zéro après une mise en veille. Interrupteur dans Réglages › Notifications, activé par défaut. |
| Sauvegarde | Le fichier des tâches est réécrit à chaque changement. Une copie par jour, gardée 30 jours. Un fichier illisible est mis de côté, jamais écrasé. |
| Export | Réglages › Données › « Exporter les tâches », en Markdown ou en CSV, les tâches ouvertes seulement ou aussi les faites. Le Markdown se lit tel quel : l'Inbox, les projets (et leurs sous-projets), puis les tâches sans projet sous leur première étiquette ; cases à cocher, étapes en retrait, notes dessous, et ce qui s'écarte du défaut (priorité, type, échéance, répétition, étiquettes, blocage). Le CSV (virgules, UTF-8) a une ligne par tâche ou étape, pour un tableur, Notion ou un autre gestionnaire. |

### Plus tard

- Rien pour l'instant.

### Hors périmètre

- Todoist, ou toute synchronisation avec un autre gestionnaire de tâches. Les tâches ouvertes ont été reprises une seule fois, hors de l'app, au passage à Done : chantiers en projets, run et « Plus tard » en étiquettes, agenda en réunions. Done n'a pas de fonction d'import.
- Serveur, compte, synchronisation entre appareils, accès par une autre app que Claude sur ce Mac. La liste Rappels de capture est une boîte d'arrivée dans un seul sens, pas une synchronisation : Done ne publie rien vers Rappels.
- Claude ailleurs que sur ce Mac (claude.ai dans le navigateur, l'iPhone) : il faudrait un serveur en ligne.
- Suppression par Claude : il propose, je supprime dans Done.
- IA intégrée (le découpage par l'API Claude a été retiré). Claude reste une app à part, qui passe par le connecteur.
- Chantiers actifs limités, attentes, dépendances, calcul de charge : la liste reste simple. Les étiquettes restent de simples noms, sans couleur ni règle attachée.
- Lecture du calendrier : les réunions se saisissent à la main.
- Publication sur l'App Store, multi-utilisateur, partage.
- Une app iPhone, iPad, Android, Windows ou web. Depuis l'iPhone, on note dans Rappels.
- Blocage d'apps ou de sites web.

## 3. Écrans et parcours

### Écrans

1. **Ma journée** (écran d'arrivée, ⌘1) : la salutation et la phrase du jour, la recherche et « Capturer » ; six cartes (prochaine action, ligne de temps, plan du jour, échéances et retards, notes, focus aujourd'hui) ; la barre de saisie en bas. La carte Prochaine action montre la tâche du plan, sa prochaine action en grand, la durée proposée (un clic sur l'anneau la change) et le temps avant la prochaine réunion, avec « Lancer le focus », « Découper… » et un menu « … » (Changer de tâche, Passer). Sans plan, plan bloqué, plan terminé, jour d'absence, réunion trop proche, pause due ou heure du bilan, elle le dit et propose la suite. Sans tâche du tout, une invitation à en ajouter.
2. **Listes** (⌘4) : à gauche, la colonne des listes (Inbox, projets et sous-projets, étiquettes). À droite, la liste choisie : champ d'ajout en haut, tâches et étapes indentées, case à cocher carrée, une ligne de détails (étapes, notes) et des puces à droite : priorité (P1, P2), « Bloquée », étiquettes (sauf celle de la vue), échéance (en couleur d'alerte une fois dépassée), durée pour une tâche rapide ou Deepwork, « Aujourd'hui » si la tâche est dans le plan, « Chaque lundi » si elle se répète. Au clavier : ↑ ↓ choisissent une ligne, Espace la coche, ↩ ouvre sa fiche, ⌘↑ ⌘↓ la déplacent ; ces raccourcis sont rappelés à droite du titre. Un clic ouvre la fiche ; clic droit pour l'échéance, la priorité, le type, le déplacement, les étiquettes, le plan du jour, le découpage, le blocage ou la suppression. En bas, les tâches terminées récemment, à rouvrir si besoin.
3. **Fiche d'une tâche** : titre, notes, liste, étiquettes, priorité, type, échéance, répétition, bloquée, étapes (ajoutées tout de suite, cochées après une seconde qu'un second clic annule), Supprimer, Enregistrer (⌘↩).
4. **Capture rapide** (⌘N, « Capturer » dans le rail ou Ma journée, ou le raccourci global hors de Done) : la fiche d'une tâche, vide. Le titre, des notes, la carte des détails (liste, priorité, type, échéance) et les étapes, numérotées, qu'on peut retirer avant de valider. Hors de Done, elle s'ouvre dans une fenêtre flottante, au centre de l'écran où se trouve la souris, sans faire passer Done au premier plan : en la fermant, on retrouve l'app d'avant. Un clic ailleurs la masque en gardant la saisie, Annuler ou Échap l'efface. Le panneau de la barre de menus garde une ligne en haut : le champ y a le focus à l'ouverture, Entrée ajoute la tâche et le champ reste prêt pour la suivante, avec « Ajoutée dans … » en confirmation ; « Détails… » ouvre la saisie complète avec ce qui est déjà tapé.
5. **Plan du jour** (feuille ouverte depuis Ma journée) : à gauche, les candidates triées par priorité puis échéance. À droite, la liste « Aujourd'hui » que j'ordonne par glisser-déposer (3 recommandées, 5 au maximum), puis les réunions à venir avec « Ajouter ». Bouton « Chercher une autre tâche ». Bouton Valider, qui ramène à Ma journée.
6. **Session en cours** (Ma journée en plein écran) : le temps restant en grands chiffres sur une règle graduée de 0 à la durée de la session, dont la barre avance vers 0 (lueur dans la dernière minute, chiffres qui clignotent en pause), repère « Encore N étapes après celle-ci » pour une tâche découpée, boutons Pause (barre d'espace), Interrompre (menu des raisons), C'est fait (⌘↩), « Ajouter 5 min » tant que la rallonge le permet, et « Bloqué… ».
7. **Fin de session** :
   - Minuteur fini : « Pomodoro terminé », la durée sur la tâche et la série du jour (une pastille par pomodoro mené au bout, « 3e pomodoro aujourd'hui ») ; champ « Où tu en es ? », puis « Cocher la tâche », « Encore 5 min », « Pause, puis je reprends », « Bloqué… », « Arrêter là ».
   - Étape cochée en avance : « Étape terminée », la suivante sous « Ensuite », puis « Enchaîner · MM:SS restantes », « Pause d'abord », « Arrêter là ». Quand toutes les étapes sont faites : « Cocher « tâche » ».
   - Feuille « Bloqué » : ce qui bloque en une ligne, ce qui vient ensuite, puis « Laisser ouverte et passer à la suite ».
8. **Interruption** : raison et durée de l'interruption, la réunion en cours s'il y en a une, champ « Où tu en es ? », puis Reprendre, Choisir autre chose, ou Insérer une tâche urgente en tête du plan.
9. **Pause** : compte à rebours, la prochaine action sous « Ensuite », bouton Passer la pause. Avant une nouvelle tâche principale, la pause est obligatoire : pas de bouton pour la passer.
10. **Notes** (⌘3) : en haut, la recherche, le filtre par type et « Nouvelle » ; dessous, la mosaïque des notes. Une note ouverte prend toute la largeur : type, titre, rattachements, contenu, liens et « Citée dans », avec « Toutes les notes » pour revenir.
11. **Calendrier** (⌘2) : le titre de la semaine, le nombre de réunions et d'échéances et le focus fait, les flèches et « Cette semaine ». Une colonne par jour : en-tête (jour, absence ou focus du jour, menu « … » pour ajouter une réunion ou marquer une absence), échéances, puis la grille horaire.
12. **Stats** (⌘5) : la semaine en cartes : focus, série, jours, meilleures heures, projets, interruptions.
13. **Réglages** (⌘,) : prénom de la salutation, durées, tâches par jour, horizon des candidates, bilan du soir, Ne pas déranger, notifications, saisie rapide, Rappels de l'iPhone, Claude (inscription du connecteur), emplacement du fichier des tâches.

### Parcours principal

```
Ouverture → Ma journée
  └─ Carte Prochaine action
       ├─ Aucune tâche → barre de saisie, ⌘N, ou l'Inbox
       ├─ Pas de plan aujourd'hui → Préparer le plan (feuille) → Valider → Ma journée
       └─ Plan prêt → Lancer le focus → Session en cours (plein écran)
Session en cours
  ├─ C'est fait avant la fin → tâche cochée
  │     ├─ Étape suivante de la même tâche → Enchaîner (temps restant) ou Pause
  │     ├─ Dernière étape → Cocher la tâche principale → Pause obligatoire → Ma journée
  │     └─ Tâche principale finie ou bloquée → Pause obligatoire → Ma journée
  ├─ Fin du minuteur → Fin de session
  │     ├─ Cocher → même suite que ci-dessus, sans enchaînement (Pause)
  │     ├─ Encore 5 min → Session en cours (10 min au plus)
  │     └─ Pause, puis je reprends / Arrêter là → Pause ou Ma journée
  ├─ Bloqué… → étape marquée bloquée
  │     ├─ Autre étape ouverte dans la même tâche → Session en cours sur cette étape (ou Pause s'il reste moins d'une minute)
  │     └─ Aucune → Pause obligatoire → Ma journée
  └─ Interrompre → Interruption → Reprendre ou Ma journée
```

### Navigation

Une fenêtre avec un rail d'icônes à gauche, sous les feux de la fenêtre : « Capturer » (⌘N), Ma journée (⌘1), Calendrier (⌘2), Notes (⌘3), Listes (⌘4, la dernière liste ouverte ; la pastille donne le nombre de tâches de l'Inbox) et Stats (⌘5) ; en bas, Réglages (⌘,) et le logo. ⌘K mène à la recherche de Ma journée. Pendant une session (minuteur, pause, interruption, fin de session), Ma journée passe en plein écran et le rail s'efface ; il revient par-dessus quand la souris touche le bord gauche de la fenêtre. Si l'on change d'écran, la session continue : son minuteur remplace le logo en bas du rail, et un clic dessus (ou ⌘1) y ramène. Le minuteur reste aussi visible dans la barre de menus, même fenêtre fermée.

## 4. Données

| Donnée | Stockage |
|---|---|
| Tâches (ouvertes et terminées), projets, réunions et séries de réunions récurrentes, blocs de travail | Fichier JSON local : `~/Library/Application Support/com.adnan.done/tasks.json`, réécrit en entier, de façon atomique, à chaque changement. Une copie par jour dans `Sauvegardes`, 30 jours gardés. |
| Notes | Un fichier Markdown par note dans `~/Library/Application Support/com.adnan.done/Notes/`, nommé d'après le titre. En tête du fichier, entre deux lignes `---` : identifiant, type, titre, projet, étiquettes, tâches, date, création et mise à jour. Un fichier sans en-tête est lu comme une note simple. Done relit le dossier dès qu'il change ; une note supprimée part à la corbeille. |
| Plan du jour (date, identifiants ordonnés, identifiants terminés) | SwiftData, local. Done en publie une copie dans `plan.json` pour le connecteur Claude ; le plan voulu par Claude arrive dans `plan-request.json`, que Done applique puis efface. |
| Sessions (tâche, tâche du plan, projet, type, début, fin, durée prévue, durée réelle, issue) | SwiftData, local |
| Interruptions (raison, début, fin, session) | SwiftData, local |
| Notes de reprise (texte, date, par tâche) | UserDefaults (`resume.notes`) |
| Bilan du soir, report au lendemain | UserDefaults (`review.lastDay`, `review.carryOver`) |
| Réglages | UserDefaults |

Remarques :

- Le fichier des tâches porte un numéro de version (`version`). Un champ absent prend sa valeur par défaut à la lecture : un fichier plus ancien reste lisible.
- Une échéance est enregistrée comme un jour (« 2026-10-31 »), sans heure ni fuseau.
- Les sessions gardent une copie du titre et du projet de la tâche, pour que les stats restent lisibles une fois la tâche cochée ou supprimée.
- Done et Claude écrivent dans le même `tasks.json` : chacun le relit et le réécrit sous un verrou (`.tasks.lock`), et Done relit le fichier dès qu'il change. Aucune écriture de l'un n'efface celle de l'autre.
- Done ne fait aucun appel réseau. Ce que Claude lit par le connecteur entre dans la conversation avec Claude, comme tout ce qu'on lui confie.

## 5. Choix techniques

- **Xcode, SwiftUI, une cible macOS** (macOS 14 minimum, pour SwiftData et `@Observable`).
- **Tâches en JSON**, plutôt qu'en SwiftData : un fichier lisible, facile à sauvegarder et à restaurer, et une logique (`TaskStore`) testable sans l'app.
- **SwiftData local** pour le plan, les sessions et les interruptions. Le modèle `BacklogSnapshot`, hérité de la version Todoist, reste déclaré pour ouvrir les bases existantes sans migration.
- **EventKit** pour la boîte Rappels (accès complet aux rappels demandé à la première lecture ; phrase d'autorisation dans `Done-Info.plist`, droit Calendrier du Hardened Runtime dans `Done.entitlements`, tous deux hors du dossier synchronisé).
- **App Raccourcis** (`/usr/bin/shortcuts run`) pour « Ne pas déranger », macOS n'ayant pas d'API publique pour les modes de concentration.
- **UserNotifications** pour les fins de session et de pause, les rappels du bilan et des réunions, **MenuBarExtra** pour le minuteur et la capture dans la barre de menus, **RegisterEventHotKey** (Carbon) pour le raccourci global, sans autorisation d'accessibilité à demander.
- **Connecteur MCP** (Model Context Protocol) écrit à la main : JSON-RPC sur l'entrée et la sortie standard, un message par ligne. Le même exécutable sert d'app et de connecteur (`Done --mcp`, point d'entrée `Launcher`), pour n'avoir ni seconde cible ni outil à installer. Le protocole et les outils sont de la logique pure (`Done/Core`), testée hors de l'app.
- App non sandboxée et signée localement : elle n'est pas distribuée.
- Aucune dépendance externe, aucun appel réseau.
