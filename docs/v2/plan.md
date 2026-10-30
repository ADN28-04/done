# Done v2 : remplacer Todoist

Plan de travail pour faire de Done l'unique outil de gestion de mes tâches pro, à la place de Todoist, en comblant les lacunes de Todoist pour mon usage.

## 1. Contexte

Aujourd'hui, Done s'appuie sur Todoist : Todoist stocke les tâches, Done me fait avancer plus vite dessus. Mon système d'organisation repose sur des règles que Todoist affiche dans les descriptions de projets mais n'applique pas :

- 3 chantiers actifs maximum, une section par chantier ;
- un chantier se termine avant d'en ouvrir un nouveau, la file d'attente est ordonnée ;
- un seul sujet de fond à la fois ;
- aucune tâche datée sur un jour de congé ou un jour férié.

Limites constatées dans Todoist :

- le chantier n'existe pas comme objet : « actif » est un label posé à la main sur chaque tâche, et les sous-tâches qui ne l'ont pas sortent du filtre Focus ;
- clôturer un sujet revient à archiver un projet, le bilan disparaît ;
- les durées sont saisies mais jamais additionnées : rien ne signale une journée trop chargée ;
- le label Waiting n'a ni personne, ni date de début, ni date de relance ;
- pas de dépendances entre tâches ;
- les statistiques comptent des tâches cochées, pas l'avancement des chantiers.

## 2. Contraintes et décisions

- **Desktop uniquement (Mac).** Pas d'usage iPhone, volontairement : c'est ce qui me permet de couper pro et perso. Ne rien optimiser pour le mobile.
- **Réunions saisies à la main.** Mon employeur n'autorise pas la connexion d'outils tiers à Outlook. Pas de synchro calendrier, pas de capture d'écran.
- **Connexion obligatoire avec mon projet Claude (claude.ai).** Claude doit pouvoir lire et modifier mes tâches dans Done comme il le fait aujourd'hui avec le connecteur Todoist. C'est une condition pour quitter Todoist, pas une option.
- **Pas d'IA intégrée dans Done.** L'intelligence (rédiger une relance, préparer une revue, trier l'Inbox) passe par Claude via le connecteur. Done reste un outil simple et déterministe.
- **Usage personnel, un seul utilisateur.** Pas de multi-utilisateur, pas de partage.
- **Les règles vivent côté serveur.** La limite de 3 chantiers, l'interdiction de dater sur un congé, etc. sont appliquées par l'API, pas seulement par l'interface. Elles s'appliquent donc aussi quand Claude passe par le connecteur.

## 3. Hors périmètre

- application iPhone ou version mobile ;
- synchronisation Outlook ou tout autre calendrier ;
- collaboration, attribution de tâches à d'autres personnes ;
- IA embarquée dans Done.

## 4. Modèle de données cible

À adapter à la stack existante de Done. Les noms sont indicatifs.

**Tâche**
- titre, description (texte riche simple), notes
- statut : à faire, en attente, terminée
- date d'échéance (jour, heure optionnelle), date limite ferme (deadline) distincte
- durée estimée
- type de travail : Deepwork, Quick, Meeting
- priorité (P1 à P4)
- rattachement : un chantier, un domaine récurrent, ou l'Inbox
- tâche parente (sous-tâches)
- dépendances : liste de tâches qui doivent être terminées avant
- personnes liées
- historique des reports (chaque changement de date est enregistré)
- dates de création et de complétion

**Attente** (portée par une tâche au statut « en attente »)
- personne attendue
- date de début de l'attente
- date de prochaine relance
- objet de l'attente en une phrase

**Chantier**
- nom, objectif, livrable attendu, critère de fin
- statut : en file, actif, terminé, abandonné
- position dans la file d'attente
- interlocuteurs
- journal des décisions (date + décision)
- bilan de clôture (ce qui a été livré, ce qui reste, ce que j'en retiens)
- règle : 3 chantiers actifs maximum, refus côté API au-delà

**Sujet de fond**
- même structure que le chantier, avec une limite de 1 actif

**Domaine récurrent** (remplace le projet Run Shop)
- Pages dédiées, Front-end, Promos et campagnes, Reporting, Homepage et mises en avant
- pas de limite, pas de clôture

**Idée**
- titre, description, date d'ajout ; peut être promue en chantier ou en tâche

**Personne**
- nom, rôle
- ordre du jour du prochain point (tâches et attentes liées)

**Réunion** (saisie manuelle, remplace le projet Agenda)
- titre, date, heure de début, heure de fin
- type : réunion, congé, férié
- un congé ou un férié bloque la journée entière

**Paramètres de travail**
- jours travaillés, heures de début et de fin par jour
- marge de sécurité (par défaut 20 % du temps disponible)

## 5. Connecteur Claude (serveur MCP)

Done expose un serveur MCP distant que j'ajoute comme connecteur personnalisé dans claude.ai, à côté de mes autres connecteurs.

Exigences :

- serveur accessible en HTTPS sur mon domaine o2switch, disponible même quand mon Mac est éteint ;
- authentification obligatoire (OAuth si possible) : les tâches contiennent des informations de travail, l'URL ne doit jamais être ouverte sans authentification ;
- vérifier dans la documentation Anthropic à jour (docs.claude.com et support.claude.com) le transport et le mode d'authentification attendus par les connecteurs personnalisés de claude.ai avant de développer ;
- chaque appel en écriture est journalisé (date, outil, avant, après) pour que je puisse retrouver ce que Claude a modifié ;
- les règles métier sont vérifiées par le serveur ; un refus renvoie un message clair (« 3 chantiers déjà actifs : X, Y, Z »).

Outils à exposer, au minimum :

| Outil | Rôle |
|---|---|
| `get_overview` | chantiers actifs, file d'attente, domaines, nombre de tâches par statut |
| `find_tasks` | recherche par texte, statut, date, chantier, domaine, type, personne |
| `get_task` | détail complet d'une tâche, attente et dépendances comprises |
| `create_tasks` | création d'une ou plusieurs tâches |
| `update_tasks` | modification (date, durée, statut, rattachement...) |
| `complete_tasks` | complétion |
| `list_waiting` | attentes avec personne, ancienneté et relance due |
| `get_chantier` / `update_chantier` | lecture et modification d'un chantier, ajout d'une décision |
| `activate_chantier` / `close_chantier` | ouverture (refusée au-delà de 3) et clôture avec bilan |
| `add_meetings` | saisie de réunions, congés, fériés |
| `get_capacity` | pour une date ou une semaine : temps disponible, réunions, durées planifiées, surcharge |
| `get_weekly_review` | données de la revue hebdo (voir phase 6) |
| `get_person` | ordre du jour du prochain point avec une personne |

## 6. Phases

L'ordre compte : Done ne devient source de vérité qu'une fois le connecteur Claude en place, sinon je perds l'accès de Claude à mes tâches.

### Phase 0 : état des lieux
- Relire le code actuel de Done et documenter la stack, l'hébergement, l'intégration Todoist existante.
- Proposer les adaptations du modèle de données de la section 4 à cette stack.
- **Fini quand :** un court document d'architecture est validé par moi.

### Phase 1 : stockage propre
- Base de données Done avec le modèle cible.
- Sauvegarde quotidienne automatique sur o2switch, et export JSON complet à la demande.
- **Fini quand :** je peux créer, modifier, compléter une tâche dans Done sans passer par Todoist, et restaurer une sauvegarde.

### Phase 2 : connecteur Claude
- Serveur MCP avec authentification et les outils de la section 5.
- Règles métier appliquées côté serveur.
- **Fini quand :** depuis mon projet claude.ai, Claude liste mes chantiers, crée une tâche, et se voit refuser l'ouverture d'un quatrième chantier.

### Phase 3 : import Todoist et bascule
- Import ponctuel via l'API Todoist, avec cette correspondance :
  - projet Chantiers : chaque section devient un chantier actif ;
  - projet Plus tard : section « Sujets de fond » vers sujets de fond, « File d'attente » vers chantiers en file (ordre conservé), « Idées » vers idées ;
  - projet Run Shop : chaque section devient un domaine récurrent ;
  - projet Agenda : vers réunions, congés et fériés ;
  - Inbox : vers l'Inbox de Done ;
  - labels Quick, Deepwork, Meeting : vers le type de travail ;
  - label Waiting : vers le statut en attente (personne et relance à compléter à la main) ;
  - labels Zoé, Laurane : vers les personnes liées ;
  - label Chantier-actif : supprimé, l'information vient du statut du chantier ;
  - conserver descriptions, sous-tâches, durées, priorités, dates et deadlines.
- Rapport d'import : nombre d'éléments par type, éléments non reconnus.
- Todoist reste en lecture seule pendant 2 à 3 semaines.
- **Fini quand :** je travaille uniquement dans Done pendant 2 semaines sans rouvrir Todoist.

### Phase 4 : le confort de base
Ce sont les fonctions qui décident si je peux vraiment quitter Todoist. À soigner avant les suivantes.
- Capture rapide : un raccourci clavier dans l'app ouvre un champ unique, validation à Entrée, la tâche part dans l'Inbox.
- Dates en français dans le champ de capture : « jeudi 14h », « demain », « 12/11 », « dans 3 jours », « tous les lundis ».
- Récurrences, y compris « tous les lundis sauf congés et fériés ».
- Rappels par notification du navigateur sur Mac.
- Recherche plein texte.
- Raccourcis clavier pour les actions courantes (compléter, reporter, changer de chantier).
- **Fini quand :** saisir une tâche datée me prend moins de temps que dans Todoist.

### Phase 5 : chantiers, attentes, personnes
- Vue Focus automatique : tâches des chantiers actifs (sous-tâches comprises), plus ce qui est dû aujourd'hui ou en retard. Plus de label à poser.
- Ouverture d'un chantier refusée au-delà de 3 ; la clôture d'un chantier propose le suivant de la file.
- Clôture avec bilan obligatoire ; les chantiers terminés restent consultables.
- Attentes : liste triée par relance due, ancienneté affichée (« depuis 9 jours »).
- Dépendances : une tâche bloquée est signalée, et une échéance est marquée « à risque » si une dépendance n'a pas bougé.
- Fiche personne : ordre du jour du prochain point.
- **Fini quand :** je n'utilise plus de règle écrite en description pour piloter mes chantiers.

### Phase 6 : capacité
- Saisie rapide des réunions en une ligne : « lun 10h-11h Point Zoé », « 11/11 férié », « 23/12 au 2/1 congé ».
- Vue jour et semaine : temps disponible (heures de travail moins réunions moins marge), somme des durées planifiées, alerte de surcharge.
- Refus de dater une tâche sur un congé ou un férié.
- Placement suggéré : Deepwork sur les créneaux longs, Quick dans les trous de 30 minutes.
- **Fini quand :** je vois en un coup d'oeil qu'une journée est pleine avant d'y ajouter une tâche.

### Phase 7 : revue hebdo
- Avancement par chantier (tâches faites, restantes, dernière activité).
- Attentes de plus de 7 jours.
- Tâches reportées 3 fois ou plus.
- Charge de la semaine suivante.
- **Fini quand :** la revue du vendredi me prend moins de 15 minutes.

## 7. Points d'attention

- **Données de travail sur un hébergement personnel.** Les tâches mentionnent des projets et des collègues Partenamut. Aucune donnée client ne doit jamais y entrer.
- **Notifications.** Sur Mac, les rappels du navigateur ne fonctionnent que si Done est ouvert ou installé comme app. Acceptable pour un usage au bureau, à confirmer à l'usage.
- **Réversibilité.** L'export JSON complet doit permettre de revenir à Todoist ou à un autre outil si Done ne tient pas.
