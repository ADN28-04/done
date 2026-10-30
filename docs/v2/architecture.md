# Done v2 : architecture

Statut : **proposition à valider** (phase 0 de `docs/v2/plan.md`). Rien n'est développé tant que la section 10 n'est pas tranchée.

## 1. En bref

- Un **serveur Done** sur o2switch devient la seule source de vérité. Il porte la base, les règles métier, le journal des écritures et les sauvegardes.
- Ce serveur a deux portes vers le même code métier : une **API REST** pour l'app Mac et un **serveur MCP** pour claude.ai. Une règle écrite une fois s'applique donc aux deux.
- L'**app Mac native reste la seule interface**. Pas de web app : les notifications restent celles de macOS, déjà en place, et le point d'attention sur les notifications du navigateur disparaît.
- **TypeScript sur Node.js** côté serveur, avec le SDK MCP officiel, et **MariaDB** pour la base, les deux fournis par o2switch.
- **OAuth** pour claude.ai, avec un seul client enregistré à l'avance, et un **jeton d'app** pour le Mac.
- L'IA intégrée actuelle (découpage par l'API Claude) est **retirée** à la bascule, comme le demande la section 2 du plan.

## 2. Ce qui existe aujourd'hui

**Stack.** App macOS native : SwiftUI, SwiftData, Swift 5, macOS 14+, sans dépendance externe, environ 7 400 lignes. La logique pure (`Done/Core`) est séparée des vues et testée hors de l'app.

**Hébergement.** Aucun. Tout tourne sur le Mac. Done ne parle qu'à deux services : l'API Todoist et l'API Claude (découpage).

**Données.**

| Donnée | Source de vérité | Où dans l'app |
|---|---|---|
| Tâches, projets, sections, labels, dates, durées | Todoist | En mémoire, rechargées au lancement et à ⌘R |
| Réunions du jour | Todoist (tâches « Réunion · … » avec heure) | En mémoire |
| Tâches terminées (stats backlog) | Todoist | En mémoire, 8 semaines |
| Plan du jour, sessions, interruptions, photo du backlog | App | SwiftData, local |
| Notes de reprise, pièces jointes, bilan du soir | App | UserDefaults |
| Token Todoist, clé API Claude | Moi | Trousseau du Mac |

**Intégration Todoist** (`Done/Services/TodoistClient.swift`, API v1, token personnel) :

- lectures : tâches, projets, tâches terminées ;
- écritures : cocher, créer une sous-tâche, remplacer les labels, commenter.

Todoist structure aussi la logique de l'app, et c'est ce qui change le plus :

- les labels `Chantier-actif`, `Waiting`, `Quick` et `Deepwork` portent les règles du `Planner` ;
- les réunions sont des tâches dont le titre commence par « Réunion » ;
- la priorité est inversée (4 = P1) ;
- les identifiants Todoist sont stockés localement : plan du jour, sessions, notes de reprise, pièces jointes.

## 3. Architecture proposée

```
  App Mac (SwiftUI)                 Serveur Done (o2switch)              claude.ai
  ───────────────────               ─────────────────────────            ─────────────
  Focus, minuteur, pauses   HTTPS   /api/v1   API REST          HTTPS    connecteur
  écrans chantiers, semaine ──────▶ /mcp      serveur MCP     ◀───────── personnalisé
  notifications macOS       jeton   domaine   règles métier     OAuth    (projet Claude)
  cache local (lecture)     d'app   journal   des écritures
                                    MariaDB + sauvegardes
```

### 3.1 Serveur

- **Langage : TypeScript sur Node.js 24.** o2switch fait tourner Node avec l'outil « Setup Node.js App » (Phusion Passenger), versions récentes comprises. Le SDK MCP officiel en TypeScript est le plus complet. Les mêmes schémas de validation (Zod) servent à l'API REST et aux outils MCP.
  - PHP serait plus natif chez o2switch, mais son SDK MCP est plus jeune.
  - Python est équivalent à TypeScript ; je le garde en alternative.
- **Base : MariaDB.** C'est la base native d'o2switch : gérée depuis cPanel, visible dans phpMyAdmin, comprise dans les sauvegardes de l'hébergeur.
  - PostgreSQL est aussi proposé chez o2switch.
  - SQLite est écarté : un fichier partagé par plusieurs processus Passenger sur un hébergement mutualisé, c'est un risque inutile pour la source de vérité.
- **MCP en Streamable HTTP, sans état, réponses JSON.** C'est le transport recommandé par Anthropic (l'ancien transport SSE est en voie d'abandon). Sans session ni flux ouvert, chaque appel est une requête courte, ce qui convient à Passenger, qui peut arrêter le processus entre deux appels.
- **Limites côté claude.ai** : 150 000 caractères environ par résultat d'outil et 240 secondes par appel. `find_tasks` pagine ses résultats.
- **Adresses** sur un sous-domaine dédié (par exemple `done.ton-domaine.fr`), avec un certificat Let's Encrypt géré par cPanel :

| Chemin | Rôle | Accès |
|---|---|---|
| `/mcp` | serveur MCP | jeton OAuth |
| `/api/v1/…` | API de l'app Mac | jeton d'app |
| `/.well-known/oauth-protected-resource`, `/.well-known/oauth-authorization-server` | découverte OAuth | public (métadonnées seulement) |
| `/oauth/authorize`, `/oauth/token` | autorisation et jetons | page de connexion, puis code PKCE |

### 3.2 Authentification

Deux clients, deux mécanismes. Rien n'est lisible sans authentification.

**claude.ai → OAuth 2.1.** Sur un forfait personnel, c'est la seule option fiable. L'authentification par en-tête fixe existe, mais elle est en bêta et réservée à certaines organisations. Ce que la documentation Anthropic à jour impose, et ce que je propose :

- **Code d'autorisation avec PKCE S256** obligatoire ; Claude suit les spécifications d'autorisation MCP 2025-03-26, 2025-06-18 et 2025-11-25.
- **Un seul client « Claude »**, enregistré à l'avance avec l'adresse de retour `https://claude.ai/api/mcp/auth_callback`. Tu saisis son identifiant et son secret dans claude.ai, option « Utiliser ton propre client OAuth », en ajoutant le connecteur.
  - Pas d'enregistrement dynamique : personne d'autre ne peut créer de client.
  - Pour Claude Code un jour, il suffira d'accepter aussi une adresse de retour locale (`localhost`, port quelconque).
- **Page de connexion** avec mot de passe et code à usage unique (application d'authentification). Elle ne sert qu'à l'ajout du connecteur, ou si l'accès est révoqué.
- **Jetons** :
  - jeton d'accès d'une heure, jeton de rafraîchissement renouvelé à chaque usage ;
  - erreur `invalid_grant` quand un jeton n'est plus valide, réponse en moins de 10 secondes ;
  - révocation possible depuis les Réglages de l'app.
- **Découverte** :
  - toute requête non authentifiée sur `/mcp` reçoit un `401` avec `WWW-Authenticate: Bearer resource_metadata="…"` ;
  - le champ `resource` des métadonnées est exactement l'adresse du serveur MCP.
- **Défense en profondeur (option)** : `/mcp` n'accepte que les requêtes venant de la plage d'Anthropic, `160.79.104.0/21`. À vérifier : o2switch doit transmettre l'adresse IP réelle derrière son proxy.

**App Mac → jeton d'app.** C'est un long jeton aléatoire créé sur le serveur et rangé dans le trousseau du Mac, comme le token Todoist aujourd'hui. Il est stocké haché côté serveur et révocable.

Les secrets vivent dans un fichier `.env` sur le serveur, jamais dans le dépôt. Les jetons sont stockés hachés. La page de connexion limite le nombre d'essais.

### 3.3 Règles métier côté serveur

Elles vivent dans un module `domain/` sans HTTP ni base, testé seul, sur le modèle de `Done/Core`. REST et MCP l'appellent tous les deux.

| Règle | Vérifiée à | Message en cas de refus |
|---|---|---|
| 3 chantiers actifs au plus | activation, création d'un chantier actif | « 3 chantiers déjà actifs : X, Y, Z. Clôture-en un ou mets celui-ci en file. » |
| 1 sujet de fond actif au plus | idem | « Un sujet de fond est déjà actif : X. » |
| Pas de tâche datée sur un congé ou un férié | création, modification, report, prochaine occurrence d'une récurrence | « Le 11/11 est férié. » |
| Clôture d'un chantier avec bilan | clôture | « Le bilan est obligatoire : livré, reste, ce que j'en retiens. » |
| Pas de dépendance circulaire | ajout d'une dépendance | « A dépend déjà de B. » |
| Une sous-tâche suit le rattachement de sa parente | création, déplacement | (corrigé automatiquement) |
| Toute écriture est journalisée | toujours | date, source (app ou Claude), outil, avant, après |

Une attente sans personne ni date de relance est acceptée, ce qui est le cas des tâches importées de Todoist. La liste des attentes la signale comme incomplète.

### 3.4 App Mac

**Ce qui ne bouge pas** : le Focus, le minuteur, les pauses, l'enchaînement des étapes, « Ne pas déranger », la barre de menus, les stats de sessions, le design system.

**Ce qui change** :

- `TodoistClient` est remplacé par un `DoneClient` qui appelle l'API REST, et `TodoistTask` par des types qui suivent le modèle de la section 4.
- Le `Planner` lit des champs au lieu de labels :

| Aujourd'hui (Todoist) | Demain (Done) |
|---|---|
| label `Chantier-actif` | statut du chantier |
| label `Waiting` | statut « en attente » et sa fiche d'attente |
| labels `Quick`, `Deepwork` | type de travail |
| tâche « Réunion · … » datée | réunion saisie dans Done |
| priorité 4 = P1 | priorité 1 = P1 |
| garde-fou (retrait du label) | règle serveur, refus à l'activation |

- « Bloqué… », ajouté récemment, devient naturellement une attente : statut « en attente », et ce qui bloque devient l'objet de l'attente.
- Les nouveaux écrans arrivent phase par phase : capture rapide, Inbox, chantiers, attentes, personnes, semaine (capacité), revue.

**Hors ligne.** Le dernier état reste en cache sur le Mac, en lecture seule. Les écritures demandent le réseau. Le minuteur fonctionne sans réseau.

**Ce qui reste sur le Mac.** Les sessions Pomodoro, le plan du jour et les notes de reprise restent locaux : aucun outil du connecteur n'en a besoin. On pourra les remonter plus tard si la revue hebdo le demande.

**IA intégrée retirée.** Sont concernés `ClaudeClient`, le découpage par Claude, le dossier de contexte et les pièces jointes. Le découpage manuel reste. Le découpage intelligent passe par Claude dans ton projet claude.ai, qui crée les sous-tâches avec `create_tasks`. Il a de toute façon un meilleur contexte que l'app.

**Transition.** Pendant les phases 1 et 2, un réglage caché « Source des tâches » (Todoist ou serveur Done) permet de tester le serveur sans casser l'usage quotidien, qui reste sur Todoist jusqu'à la bascule.

## 4. Modèle de données

**Conventions** :

- identifiants UUID v7, en texte : triables par date de création, sans collision lors de l'import ;
- dates calendaires en `DATE` (jour local), horodatages en UTC ;
- fuseau du compte dans les paramètres ;
- priorité 1 = P1 : fin de l'inversion Todoist ;
- chaque objet importé garde son `todoist_id`.

| Table | Champs principaux | Notes |
|---|---|---|
| `tasks` | `title`, `description`, `notes`, `status` (todo, waiting, done), `due_date`, `due_time`, `deadline`, `estimate_minutes`, `work_type` (deepwork, quick, meeting), `priority` (1 à 4), `chantier_id` ou `domain_id` (aucun = Inbox), `parent_id`, `position`, `recurrence`, `created_at`, `completed_at`, `updated_at` | Description et notes en Markdown simple (gras, listes, liens). Un seul rattachement à la fois. |
| `waits` | `task_id`, `person_id`, `since`, `next_follow_up`, `subject` | Une par tâche en attente. |
| `task_dependencies` | `task_id`, `depends_on_id` | Sans cycle. |
| `task_people` | `task_id`, `person_id` | |
| `task_reschedules` | `task_id`, `from_date`, `to_date`, `at`, `source` | Écrite à chaque changement de date. Le nombre de reports en découle. |
| `chantiers` | `kind` (chantier, fond), `name`, `objective`, `deliverable`, `done_criterion`, `status` (queued, active, done, abandoned), `queue_position`, `delivered`, `remaining`, `learned`, `activated_at`, `closed_at` | Le sujet de fond est un chantier de type `fond`. |
| `chantier_people` | `chantier_id`, `person_id` | Interlocuteurs. |
| `decisions` | `chantier_id`, `date`, `text` | Journal des décisions. |
| `domains` | `name`, `position` | Pages dédiées, Front-end, etc. |
| `ideas` | `title`, `description`, `created_at`, `promoted_to` | |
| `people` | `name`, `role` | L'ordre du jour est calculé : tâches et attentes ouvertes liées. |
| `events` | `title`, `kind` (meeting, leave, holiday), `start_date`, `end_date`, `start_time`, `end_time` | Un congé ou un férié bloque chaque jour de sa période. |
| `settings` | jours travaillés, heures par jour, marge (20 %), fuseau | Une seule ligne. |
| `audit_log` | `at`, `source`, `action`, `entity`, `entity_id`, `before`, `after` | Toutes les écritures, de l'app comme de Claude. |
| `oauth_*`, `app_tokens` | clients, codes, jetons hachés | |

**Écarts proposés par rapport à la section 4 du plan** :

1. **Sujet de fond** : un chantier de type `fond`, plutôt qu'une table à part. Mêmes champs, mêmes outils, seule la limite change (1 au lieu de 3).
2. **Réunions** : `start_date` et `end_date`, pour saisir « 23/12 au 2/1 congé » en une ligne.
3. **Ordre du jour d'une personne** : calculé à la lecture, pas stocké.
4. **Récurrence** : une règle structurée sur la tâche (fréquence, jours, « sauf congés et fériés »). La prochaine occurrence est créée à la complétion, en sautant les jours bloqués. Ça arrive en phase 4.

## 5. Connecteur : outils

Les 13 outils de la section 5 du plan, tels quels.

- Les outils de lecture portent l'annotation `readOnlyHint` : claude.ai peut ainsi ne demander confirmation que pour les écritures.
- `complete_tasks` et `close_chantier` sont marqués comme destructifs.
- Chaque écriture renvoie l'état après modification, pour que Claude n'ait pas à relire.

Deux ajouts que je propose, pour que Claude puisse aussi trier l'Inbox :

- `create_chantier`, pour mettre un nouveau chantier en file ;
- `manage_ideas`, pour ajouter une idée ou la promouvoir en tâche ou en chantier.

## 6. Sauvegarde, export, restauration

- **Sauvegarde quotidienne** : une tâche cron d'o2switch écrit un export JSON complet et un dump SQL dans un dossier hors du web, et garde 30 jours. o2switch a aussi ses propres sauvegardes ; je vérifierai lesquelles avec toi.
- **Export à la demande** : un bouton dans les Réglages de l'app télécharge le JSON complet. Le format porte un numéro de version et il est documenté, pour la réversibilité.
- **Restauration** : un script recharge un export JSON dans une base vide. Il est testé pour de vrai en phase 1, puisque c'est le critère de fin.

## 7. Import Todoist et bascule (phase 3)

- **L'import** est un script du serveur, lancé une fois, avec le token Todoist. Il a un mode d'essai qui produit d'abord le rapport (nombre d'éléments par type, éléments non reconnus) sans rien écrire. La correspondance est celle de la phase 3 du plan.
- **Migration locale** : l'app réécrit ses identifiants Todoist (plan du jour, sessions, notes de reprise) grâce au `todoist_id` gardé sur chaque objet. Les stats de sessions survivent à la bascule.
- **Bascule** :
  - dans claude.ai, bloquer les outils d'écriture du connecteur Todoist (Personnaliser › Connecteurs › outil › Bloqué), ce qui garde Todoist en lecture seule ;
  - mettre à jour les instructions du projet Claude pour qu'il passe par Done ;
  - retirer le connecteur Todoist après les 2 à 3 semaines.

## 8. Code, tests et déploiement

**Un seul dépôt**, organisé ainsi :

```
Done/          app Mac (inchangé)
server/
  src/domain/  règles et calculs (capacité, récurrences, revue), sans HTTP ni base
  src/db/      accès MariaDB, migrations
  src/api/     API REST de l'app
  src/mcp/     outils MCP
  src/oauth/   autorisation, connexion, jetons
  scripts/     sauvegarde, restauration, import Todoist, déploiement
  test/
```

**Tests** :

- les règles du domaine sont testées seules ;
- les outils MCP sont testés avec le client du SDK ;
- le parcours OAuth est vérifié de bout en bout en local, puis avec MCP Inspector, avant d'ajouter le connecteur dans claude.ai.

**Déploiement** : Git sur o2switch (par SSH, ou par l'outil Git de cPanel), puis installation des dépendances, compilation et redémarrage de l'app Node, le tout dans un script `server/scripts/deploy.sh`.

## 9. Risques et points ouverts

- **Données de travail sur un hébergement personnel.** Le serveur ne peut pas empêcher une donnée client d'entrer. La règle reste une discipline. Vaut-il la peine de vérifier ce que ton employeur autorise pour un outil hébergé chez toi ? Pour Todoist, c'était un service tiers connu.
- **Disponibilité.** Si o2switch tombe :
  - l'app passe en lecture seule sur son cache, et le minuteur continue ;
  - Claude perd l'accès jusqu'au retour du serveur.
- **Démarrage à froid.** Passenger arrête l'app Node après un moment d'inactivité, et le premier appel suivant prend une à deux secondes de plus. C'est acceptable, et nettement sous la limite de 10 secondes de claude.ai pour les jetons.
- **Surface publique.** La page de connexion est exposée sur Internet. D'où le code à usage unique, la limite d'essais, le journal et la plage IP d'Anthropic sur `/mcp`.
- **Non vérifié depuis ici.** La FAQ d'o2switch n'était pas accessible depuis cette session. Les versions de Node, PostgreSQL, l'accès SSH et l'adresse IP réelle derrière le proxy sont à confirmer dans ton cPanel avant la phase 1.

## 10. Décisions à valider

| # | Décision | Ma recommandation |
|---|---|---|
| 1 | Interface | App Mac native seule, pas de web app |
| 2 | Langage du serveur | TypeScript sur Node.js 24 |
| 3 | Base | MariaDB |
| 4 | Connexion de claude.ai | OAuth, un client enregistré à l'avance, mot de passe et code à usage unique |
| 5 | Hors ligne | Lecture seule sur le cache, écritures en ligne |
| 6 | IA intégrée | Retirée à la bascule (phase 3) |
| 7 | Sessions, plan du jour, notes de reprise | Restent sur le Mac |
| 8 | Sujet de fond | Chantier de type `fond` |
| 9 | Outils en plus | `create_chantier` et `manage_ideas` |
| 10 | Adresse | Sous-domaine à choisir (par exemple `done.ton-domaine.fr`) |
| 11 | Fuseau horaire | Europe/Brussels, à confirmer |

## Sources

- [Authentication for connectors](https://claude.com/docs/connectors/building/authentication) (Anthropic)
- [Build an MCP server for Claude](https://claude.com/docs/connectors/building) (Anthropic)
- [Add a connector that isn't in the directory](https://claude.com/docs/connectors/custom/add-unlisted) (Anthropic)
- [Déployer une application NodeJS sur un hébergement o2switch](https://faq.o2switch.fr/cpanel/logiciels/hebergement-nodejs-multi-version/) (o2switch)
- [Bases de données o2switch](https://wpmarmite.com/wordpress/hebergement/o2switch/cpanel/o2switch-base-donnees/) (WPMarmite, source tierce)
