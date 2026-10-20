# Questions ouvertes

Points à trancher avant ou pendant le développement de la V1.

## Bloquant pour démarrer

1. **Compte Apple Developer payant (99 $/an) ou gratuit ?**
   Avec un compte gratuit, l'app installée sur l'iPhone expire au bout de 7 jours et doit être réinstallée depuis Xcode. Surtout, la synchronisation iCloud (CloudKit) n'est pas disponible. Sans compte payant, il faut soit renoncer à la synchro Mac / iPhone en V1, soit revenir à un backend (Supabase redevient alors une option sérieuse).

2. **Quelle version de l'API Todoist ?**
   Todoist a unifié ses API (REST v2 et Sync v9) dans une « API v1 » et déprécie les anciennes. Vérifier la documentation à jour avant d'écrire le client, notamment pour la lecture des tâches terminées utilisée dans les stats.

3. **Quel projet représente le « backlog Shop » ?**
   Les stats backlog ont besoin d'un périmètre précis : tous les projets, ou une sélection (Fiches produit, Marketing & Campagnes, Plus tard, Évolution E-Commerce, Daily eShop) ?

## Règles à valider à l'usage

4. **Le filtre des candidates est-il le bon ?**
   P1/P2, sans `Waiting`, avec `Chantier-actif` ou échéance sous 3 jours. À tester une semaine. Risque : liste trop longue si beaucoup de P2, ou tâche importante absente faute de label.

5. **Durées par label.**
   15 / 25 / 50 minutes pour `Quick` / défaut / `Deepwork` est un point de départ. À ajuster après quelques jours.

6. **Que faire d'une tâche sans sous-tâche ?**
   En V1, l'app propose la tâche entière. Si c'est trop flou pour attaquer, le découpage assisté (créer la prochaine action dans Todoist) remonte dans la V1.

7. **Que se passe-t-il pour les tâches du plan non terminées le soir ?**
   Reportées automatiquement dans les candidates du lendemain avec un signal visuel, ou oubliées ?

8. **Repérage des réunions.**
   Les réunions sont détectées par le préfixe « Réunion · » et une heure d'échéance. Est-ce stable dans l'outil qui les importe ? Faut-il aussi exclure les tâches « Préparer : … » ou au contraire les proposer avant la réunion ?

## Méthode et usage

9. **Combien de chantiers actifs en parallèle sont acceptables ?**
   Le jour du cadrage, six tâches portaient `Chantier-actif`, dont quatre en P1. Fixer une cible (une ? deux ?) donne un sens à la stat et à une future alerte.

10. **Données professionnelles.**
    Le Todoist contient des informations de travail (noms de collègues, projets internes). Elles restent sur l'appareil et dans iCloud personnel. Vérifier que c'est compatible avec les règles de l'employeur.

11. **Faut-il bloquer les distractions ?**
    Exclu de la V1. À réévaluer après un mois si la concentration reste le principal frein malgré le minuteur.
