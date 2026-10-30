# Brief design : Done, app Pomodoro pour macOS

> Brief d'origine, écrit quand Done lisait ses tâches dans Todoist. Il reste la référence des maquettes v9 ; l'app gère maintenant ses tâches elle-même (voir `spec.md`).

## Contexte

Je construis Done, une app macOS pour mon usage personnel. Elle ne sera pas publiée. Elle se connecte à Todoist et transforme mes tâches en sessions de concentration. Le code SwiftUI existe déjà, avec une interface par défaut. Je veux une vraie identité visuelle : l'interface de chaque écran et un logo.

## Le problème que l'app résout

J'ai beaucoup de tâches prioritaires en même temps. Quand tout est urgent, je n'arrive plus à choisir, je démarre mal et je finis peu. Done règle ça en deux temps. Le matin, je choisis mes trois tâches les plus importantes. Ensuite, l'app ne m'affiche qu'une seule chose : la prochaine action concrète, avec un minuteur. Quand une réunion approche, elle me propose une tâche qui tient dans le temps restant.

## Principes de design

1. **Une seule chose à l'écran.** Pendant une session, on ne voit que l'action en cours et le temps restant.
2. **Calme.** Peu de couleur, pas d'animation gratuite, aucune gamification : pas de confettis, de badges ni de séries.
3. **Hiérarchie claire.** L'action d'abord, le temps ensuite, le contexte (projet, tâche parente) en discret.
4. **Natif macOS.** L'app doit ressembler à une app Apple soignée, pas à un site web ni à un dashboard SaaS.
5. **Lisible d'un coup d'œil.** Le minuteur et l'action en cours se lisent sans effort depuis l'autre bout du bureau.

## Contraintes techniques

- SwiftUI, macOS 14 minimum. Sur macOS 26, les contrôles natifs prennent le style Liquid Glass automatiquement : le design doit s'appuyer sur ce comportement, pas lutter contre.
- Composants natifs : barre latérale (NavigationSplitView), boutons système (bordered et borderedProminent), Stepper, Picker segmenté, formulaire groupé, Swift Charts.
- Typographie : SF Pro (police système). SF Pro Rounded pour les chiffres du minuteur. Chiffres à chasse fixe partout où un nombre change.
- Icônes de l'interface : SF Symbols uniquement.
- Couleurs : une couleur d'accent, plus les couleurs sémantiques du système. Mode clair et mode sombre obligatoires.
- Pas de police personnalisée, pas d'image bitmap dans l'interface.
- Fenêtre : 860 × 580 minimum, redimensionnable.
- Interface en français.

## Couleurs imposées

Je garde les couleurs de priorité de Todoist pour les reconnaître tout de suite : P1 rouge, P2 orange, P3 bleu, P4 gris. Le rouge est réservé à P1 et aux erreurs. Le orange signale une contrainte de temps (réunion proche) ou un dépassement de cible. Propose la couleur d'accent.

## Structure

Une fenêtre avec une barre latérale à quatre entrées : Focus, Plan du jour, Stats, Réglages. Un bouton Rafraîchir dans la barre d'outils. Un minuteur dans la barre de menus du Mac.

## Écrans et états à dessiner

### 1. Connexion (premier lancement)
Logo, nom « Done », phrase « Une tâche à la fois, avec un minuteur. », champ sécurisé pour le token API Todoist, lien « Ouvrir la page Développeur de Todoist », bouton « Se connecter ». États : chargement, erreur (token refusé).

### 2. Plan du jour (le rituel du matin, moins de deux minutes)
- Titre et phrase : « Choisis tes 3 tâches les plus importantes, dans l'ordre. Le reste attendra. »
- Bandeau horizontal des créneaux du jour : heure de début et de fin, titre. Les blocs de travail se distinguent des réunions. Les créneaux passés sont estompés.
- Colonne gauche « Candidates » : liste de tâches. Chaque ligne a un badge de priorité, le titre, une ligne de détails (projet · échéance · nombre de sous-tâches · labels) et un bouton « + ».
- Colonne droite « Aujourd'hui » : liste numérotée, réordonnable par glisser-déposer. Les trois premières sont mises en avant, la 4e et la 5e en retrait. Bouton pour retirer une tâche. Avertissement discret au-delà de trois tâches. Compteur des tâches terminées aujourd'hui. Bouton principal « Valider le plan ».
- États vides des deux colonnes.

### 3. Focus (l'écran le plus important)
- Une carte centrale avec, de haut en bas : une ligne de contexte (« TÂCHE 1 SUR 3 · FICHES PRODUIT »), la tâche parente en secondaire, l'action en très grand, sa description éventuelle, une note orange quand une réunion contraint le choix, un sélecteur de durée (« 25 min »), puis les boutons « Changer de tâche », « Passer » et « Démarrer » (bouton principal).
- Sous la carte, une liste discrète « Ensuite » avec le reste du plan.
- Au-dessus, un bandeau de réunion : « Réunion en cours… jusqu'à 15:00 », « Bloc Deepword jusqu'à 12:00 » ou « Prochaine réunion : Kick-off Dashboards BI à 14:00, dans 1 h 20 ».
- États à dessiner :
  - Prêt (l'état normal).
  - Plan vide : invitation à préparer le plan.
  - Tout est en attente : les tâches du plan dépendent de quelqu'un d'autre.
  - Pas le temps avant la réunion : « Kick-off Dashboards BI commence à 14:00 », « Il reste 8 min », avec les boutons « Préparer : Kick-off Dashboards BI », « Faire une pause » et « Ignorer la réunion ».

### 4. Session en cours
Contexte en petit (projet · tâche parente), l'action en grand, un grand anneau de progression avec le minuteur au centre (« 24:13 », et « sur 25 min » en dessous). Boutons « Pause » (barre d'espace), « Interrompre » (menu : Réunion, Urgence, Autre) et « Terminer ». État en pause : l'anneau passe en gris, avec « En pause ».

### 5. Interruption
Icône de la raison, « Interrompu : Réunion », « Depuis 12 min », rappel de la tâche et du temps qu'il restait. Boutons « Choisir autre chose », « Insérer une tâche urgente… » et « Reprendre » (principal).

### 6. Fin de session
« Session terminée », « 25 min sur « Créer l'étiquette Saison hiver sur les 9 fiches » ». Boutons « Terminé, cocher dans Todoist » (principal), « Je continue (25 min) », « Pause » et « Arrêter là ». États : envoi à Todoist en cours, erreur.

### 7. Pause
Grand compte à rebours, une phrase courte (« Lève-toi, bois de l'eau, regarde loin de l'écran. »), bouton « Passer la pause ».

### 8. Stats
- Onglet **Focus** : navigation semaine par semaine. Quatre tuiles : Temps de focus, Sessions, Tâches cochées, Interruptions. Barres des minutes de focus par jour, du lundi au dimanche. Barres horizontales du temps par projet. Interruptions par raison.
- Onglet **Backlog** : quatre tuiles. Chantiers ouverts, Âge moyen, Chantiers actifs avec leur cible (orange si la cible de 2 est dépassée), Fermés cette semaine. Courbes jour après jour : chantiers ouverts, âge moyen, chantiers actifs avec une ligne de cible en pointillés. Barres des chantiers fermés par semaine.

### 9. Réglages
Formulaire groupé natif. Sections : Todoist (connexion, dernière synchro, changer de token, se déconnecter), Durées des sessions, Plan du jour, Backlog (liste des projets à cocher), Notifications.

### 10. Barre de menus
- Au repos : l'icône seule.
- Pendant une session : icône et temps restant (« 24:13 »).
- En pause ou interrompu : icône de pause et temps restant.
- Session terminée : « Fini ».
- Pause café : icône de tasse et compte à rebours.
- Panneau au clic (280 px de large) : action en cours, temps restant, Pause ou Reprendre, Ouvrir Done, Quitter.

## Contenu réaliste pour les maquettes

- Plan du jour :
  1. Mettre en place les modifications Gohy (P1, Fiches produit, @Chantier-actif)
  2. Mettre en ligne la LP Luminothérapie et vitamines d'hiver (P1, Marketing & Campagnes, 4 sous-tâches)
  3. Refonte des fiches produits AMD (P1, Fiches produit, @Deepwork)
- Action proposée : « Créer l'étiquette Saison hiver sur les 9 fiches », tâche parente « Mettre en ligne la LP Luminothérapie », 25 min.
- Créneaux du jour : 09:00–12:00 Deepword (bloc de travail), 14:00–15:00 Kick-off Dashboards BI, 15:05–15:35 Normalisation des attributs.
- Note de contrainte : « « Kick-off Dashboards BI » commence à 14:00 : cette tâche tient dans les 20 min restantes. »
- Candidates : Ajouter bloc de mise en avant Luminette et Tempur (P1, @Quick, aujourd'hui), Formulaire inscription newsletter avec opt-in (P1, demain), Préparer : Kick-off Dashboards BI (P2, aujourd'hui 13:30).

## Logo

- Nom : Done.
- L'idée à exprimer : le passage de « je me concentre sur une seule chose » à « c'est fait ». Pistes possibles : un anneau de minuteur qui se referme en coche, un point unique au centre d'un cercle, une progression qui se termine. Propose trois directions, puis affine celle que je choisis.
- Contraintes :
  - Icône d'app macOS : forme et grille officielles d'Apple, 1024 × 1024, rendu correct sur fond clair et sombre.
  - Variante monochrome pour la barre de menus (image « template »), lisible à 16–18 px, sans détail fin.
  - Pas de texte dans l'icône.
  - Cohérente avec la couleur d'accent de l'interface.
- À éviter : la tomate (cliché du Pomodoro), la coche verte générique des apps de to-do, le sablier.

## Livrables attendus

1. Tokens : couleur d'accent et palette en clair et en sombre (hex), échelle typographique, espacements, rayons.
2. Maquettes de chaque écran et état listés ci-dessus, en clair et en sombre, fenêtre de 1200 × 760.
3. Specs des composants réutilisés : ligne de tâche, badge de priorité, carte Focus, tuile de stat, bandeau de réunion, anneau du minuteur.
4. Logo : trois pistes, puis l'icône finale en 1024 px et le glyphe de barre de menus en SVG.
5. Notes d'implémentation SwiftUI chaque fois qu'un choix s'écarte des composants natifs.

## Ce que je ne veux pas

- Une app qui ressemble à un dashboard SaaS ou à un site web.
- Des couleurs vives partout, des dégradés chargés, des effets de verre appuyés en plus de ceux du système.
- De nouvelles fonctionnalités : dessine les écrans listés, sans en ajouter.
