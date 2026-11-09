# Questions ouvertes

Points à trancher à l'usage.

## Tranché

- **Plateforme** : Mac uniquement. Pas de compte Apple Developer payant, pas de synchro iCloud, données locales.
- **Todoist** : abandonné. Done gère les tâches lui-même. Les tâches ouvertes ont été reprises une fois, par un fichier généré hors de l'app ; aucune fonction d'import n'est prévue. L'idée d'un serveur avec un connecteur pour Claude (« Done v2 ») a été écartée pour garder l'outil simple.
- **Claude** : connecteur local plutôt que serveur. Claude sur ce Mac (app de bureau, Claude Code) lance `Done --mcp` ; il lit tout, crée et modifie tâches, notes, projets, étiquettes, réunions et plan du jour, et ne supprime rien. Claude sur le web ou l'iPhone n'y a pas accès.
- **IA intégrée** : retirée. Le découpage se fait à la main, étape par étape.
- **Découpage** : une seule prochaine action ne suffisait pas, la tâche paraissait abandonnée après la première étape. Done ajoute toutes les étapes d'un coup, dans l'ordre, et les propose l'une après l'autre.

## Règles à valider à l'usage

1. **Le filtre des candidates est-il le bon ?**
   Les tâches P1 et P2, et toutes celles qui arrivent à échéance sous 3 jours ou sont en retard. Une tâche datée plus loin est écartée, car la date sert de « pas avant » (exemple : retirer des promos en fin de mois). Risque : liste trop longue si beaucoup de P2. Le bouton « Chercher une autre tâche » sert de filet.

2. **Durées par type.**
   15 / 25 / 50 minutes pour rapide / normale / Deepwork est un point de départ, réglable dans l'app.

3. **Durée et portée de la pause obligatoire.**
   Elle reprend la pause normale (5 min, 10 après une session Deepwork) et ne s'impose pas après une interruption, pour laisser passer une urgence. Faut-il une durée à part, ou l'imposer aussi après « Choisir autre chose » ?

4. **Seuil d'enchaînement.**
   Done propose d'enchaîner sur l'étape suivante s'il reste au moins une minute au pomodoro. Un seuil plus haut (5 min) éviterait d'ouvrir une étape qu'on n'aura pas le temps d'avancer.

5. **Faut-il des tâches récurrentes ?**
   Pas pour l'instant. Si des tâches reviennent chaque semaine (reporting, point d'équipe), on ajoutera une récurrence simple.

6. **Les réunions saisies à la main suffisent-elles ?**
   Elles servent à ne pas lancer une session qui déborde et au rappel avant la réunion. Les réunions récurrentes et le glisser au calendrier allègent la saisie ; si elle reste pénible, une saisie en une ligne (« lun 10h-11h Point Zoé ») serait la prochaine étape.

13. **Le rappel des blocs de travail.**
   Il arrive 5 min avant le bloc, sans réglage, avec « Décaler de 30 min ». Si c'est trop tôt ou trop tard, on pourra le régler comme le rappel des réunions, ou proposer d'autres décalages.

14. **Jusqu'où créer les réunions récurrentes.**
   Done crée les occurrences de la semaine en cours, de la suivante et de celle qu'affiche le calendrier (un an au plus), jusqu'à la fin choisie s'il y en a une. Si l'on veut plutôt un nombre d'occurrences (« dix séances »), on l'ajoutera à côté de la date.

## Méthode et usage

7. **Données professionnelles.**
   Les tâches mentionnent des projets et des collègues. Elles restent sur le Mac, dans un fichier et une base locale, sauvegardés par Time Machine si elle est active. Rien ne part ailleurs. Exception : ce qui est noté sur l'iPhone dans la liste Rappels « Done » passe par iCloud, le temps que Done le récupère et supprime le rappel. Autre exception : ce que Claude lit par le connecteur entre dans la conversation avec Claude, comme un texte qu'on lui colle.

8. **« Ne pas déranger » pendant une pause manuelle ?**
   Aujourd'hui, le mode est coupé dès que le minuteur est en pause ou interrompu. Si les pauses sont très courtes, on pourrait le garder actif pour éviter les allers-retours.

9. **Jusqu'où laisser écrire Claude ?**
   Claude crée, modifie, coche et fixe le plan du jour directement, sans validation dans Done. Si un changement surprend, deux pistes : faire du plan une proposition à valider dans Done, ou marquer d'un signe ce que Claude a créé. Il ne supprime jamais rien : c'est voulu.

10. **Une seconde avant qu'une tâche cochée parte.**
   Le temps de voir la coche, et d'annuler d'un second clic. Si c'est trop long quand on coche plusieurs tâches d'affilée, on peut descendre à une demi-seconde ; si on annule souvent trop tard, monter à deux.

11. **Ce qui compte comme un pomodoro.**
   La série de la carte de fin compte les minuteurs menés au bout, rallonges comprises. Une tâche cochée avant la fin ne compte pas. Si cela décourage de cocher tôt, on pourra compter toute session de plus de 20 minutes.

12. **Faut-il bloquer les distractions ?**
   Exclu pour l'instant. À réévaluer après un mois si la concentration reste le principal frein malgré le minuteur.
