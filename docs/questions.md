# Questions ouvertes

Points à trancher pendant l'usage de la V1.

## Tranché

- **Plateforme** : Mac uniquement en V1. Pas de compte Apple Developer payant nécessaire, pas de synchro iCloud, données SwiftData locales. Une version iPhone reviendra avec un compte payant (voir « Plus tard » dans `spec.md`).
- **API Todoist** : API v1 (`https://api.todoist.com/api/v1/`). Les endpoints et formats utilisés ont été vérifiés dans le SDK Python officiel de Doist : pagination par `next_cursor`, priorité 4 = P1, `due.date` avec ou sans heure, `POST /tasks/{id}/close`, `GET /tasks/completed/by_completion_date`.

## À valider dès les premiers jours

1. **Quel périmètre pour le « backlog Shop » ?**
   Par défaut, les stats couvrent tous les projets. À régler dans Réglages › Backlog : Fiches produit, Marketing & Campagnes, Plus tard, Évolution E-Commerce, Daily eShop ?

2. **Les blocs de travail de l'agenda sont-ils bien reconnus ?**
   « Réunion · Deepword » (9h-12h) est lu comme un bloc de travail grâce au mot-clé « deepword ». Si d'autres blocs portent un autre nom, il faut ajouter le mot-clé dans les réglages. Sinon, l'app les traite comme des réunions et raccourcit les sessions avant.

3. **Le préfixe « Réunion » est-il stable ?**
   L'app repère les réunions par ce préfixe et une heure d'échéance. Si l'outil qui importe l'agenda change de format, les réunions ne seront plus détectées.

## Règles à valider à l'usage

4. **Le filtre des candidates est-il le bon ?**
   P1/P2, sans `Waiting`, avec `Chantier-actif` ou échéance sous 3 jours. Une tâche datée plus loin est écartée, même `Chantier-actif`, car la date sert de « pas avant » (exemple : retirer des promos en fin de mois). À tester une semaine. Risque : liste trop longue si beaucoup de P2, ou tâche importante absente faute de label. Le bouton « Chercher une autre tâche » sert de filet.

5. **Durées par label.**
   15 / 25 / 50 minutes pour `Quick` / défaut / `Deepwork` est un point de départ, réglable dans l'app.

6. **Le découpage assisté suffit-il ?**
   Tranché à l'usage : une seule prochaine action ne suffisait pas, la tâche paraissait abandonnée après la première étape. Done crée maintenant toutes les étapes d'un coup, dans l'ordre, et les propose l'une après l'autre.

7. **« Plus tard » et « en file d'attente » ne déplacent rien dans Todoist.**
   Le bilan « Plus tard » laisse la tâche où elle est, et le garde-fou retire seulement `@Chantier-actif`. Faut-il aussi déplacer la tâche dans « Plus tard › File d'attente », comme dans ta méthode actuelle ?

8. **Une tâche `Waiting` dont le parent n'a pas le label.**
   « Formulaire newsletter avec opt-in » attend le DPO, mais seule la tâche « Validation bloc newsletter par DPO » porte `Waiting`. L'app propose donc encore le formulaire. Faut-il poser `Waiting` sur le parent, ou que l'app détecte les tâches liées ?

## Méthode et usage

9. **Combien de chantiers actifs en parallèle sont acceptables ?**
   Le jour du cadrage, six tâches portaient `Chantier-actif`, dont quatre en P1. La cible est fixée à 2 par défaut dans les réglages. À confirmer.

10. **Données professionnelles.**
    Le Todoist contient des informations de travail (noms de collègues, projets internes). Elles transitent entre l'API Todoist et le Mac, et l'historique des sessions reste en local. Avec le découpage par Claude, la tâche, la méthode, la liste des fichiers du dossier de contexte, les fichiers que Claude lit et les pièces jointes partent chez Anthropic. Vérifier que c'est compatible avec les règles de l'employeur.

11. **« Ne pas déranger » pendant une pause manuelle ?**
    Aujourd'hui, le mode est coupé dès que le minuteur est en pause ou interrompu. Si les pauses sont très courtes, on pourrait le garder actif pour éviter les allers-retours.

12. **Faut-il bloquer les distractions ?**
    Exclu de la V1. À réévaluer après un mois si la concentration reste le principal frein malgré le minuteur.

13. **La note de reprise doit-elle aller dans Todoist ?**
    Elle reste sur le Mac pour l'instant. Done sait maintenant commenter une tâche (étape bloquée) : poster aussi la note de reprise en commentaire ne coûterait plus d'écriture nouvelle, seulement du bruit dans Todoist.

14. **Durée et portée de la pause obligatoire.**
    Elle reprend la pause normale (5 min, 10 après une session Deepwork) et ne s'impose pas après une interruption, pour laisser passer une urgence. À l'usage : faut-il une durée à part, ou l'imposer aussi après « Choisir autre chose » ?

15. **Seuil d'enchaînement.**
    Done propose d'enchaîner sur l'étape suivante s'il reste au moins une minute au pomodoro. Un seuil plus haut (5 min) éviterait d'ouvrir une étape qu'on n'aura pas le temps d'avancer.

16. **Débloquer une étape depuis Done ?**
    Une étape bloquée revient quand on retire `@Waiting` dans Todoist. Si c'est trop loin de l'usage, Done pourrait lister les étapes bloquées (dans le plan du jour ou le bilan du soir) avec un bouton « Débloquer ».
