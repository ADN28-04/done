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
   P1/P2, sans `Waiting`, avec `Chantier-actif` ou échéance sous 3 jours. À tester une semaine. Risque : liste trop longue si beaucoup de P2, ou tâche importante absente faute de label. Le bouton « Chercher une autre tâche » sert de filet.

5. **Durées par label.**
   15 / 25 / 50 minutes pour `Quick` / défaut / `Deepwork` est un point de départ, réglable dans l'app.

6. **Que faire d'une tâche sans sous-tâche ?**
   En V1, l'app propose la tâche entière. Si c'est trop flou pour attaquer, le découpage assisté (créer la prochaine action dans Todoist depuis Done) remonte dans les priorités.

7. **Que se passe-t-il pour les tâches du plan non terminées le soir ?**
   Aujourd'hui, le plan repart de zéro chaque matin. Les tâches non finies réapparaissent dans les candidates si elles remplissent les critères, sans signal particulier. Faut-il les marquer « reportée » ?

8. **Une tâche `Waiting` dont le parent n'a pas le label.**
   « Formulaire newsletter avec opt-in » attend le DPO, mais seule la tâche « Validation bloc newsletter par DPO » porte `Waiting`. L'app propose donc encore le formulaire. Faut-il poser `Waiting` sur le parent, ou que l'app détecte les tâches liées ?

## Méthode et usage

9. **Combien de chantiers actifs en parallèle sont acceptables ?**
   Le jour du cadrage, six tâches portaient `Chantier-actif`, dont quatre en P1. La cible est fixée à 2 par défaut dans les réglages. À confirmer.

10. **Données professionnelles.**
    Le Todoist contient des informations de travail (noms de collègues, projets internes). Elles transitent entre l'API Todoist et le Mac, et l'historique des sessions reste en local. Vérifier que c'est compatible avec les règles de l'employeur.

11. **Faut-il bloquer les distractions ?**
    Exclu de la V1. À réévaluer après un mois si la concentration reste le principal frein malgré le minuteur.
