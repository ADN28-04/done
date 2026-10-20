# Done

App Pomodoro personnelle pour macOS, branchée sur Todoist. Le matin, je choisis mes trois tâches les plus importantes. Ensuite, Done ne m'affiche qu'une chose : la prochaine action concrète, avec un minuteur adapté.

Le cadrage est dans `docs/` : `vision.md` (le problème), `spec.md` (fonctionnalités, écrans, données) et `questions.md` (ce qui reste ouvert).

## Lancer l'app

Il faut un Mac sous macOS 14 ou plus récent, et Xcode 16 ou plus récent.

1. Ouvrir `Done.xcodeproj` dans Xcode.
2. Dans la cible **Done**, onglet **Signing & Capabilities**, choisir son équipe (un Apple ID gratuit, « Personal Team », suffit). Sans équipe, Xcode signe en local, ce qui marche aussi, mais le Mac redemande l'accès au trousseau après chaque compilation.
3. Lancer avec ⌘R.
4. Au premier lancement, coller le token API Todoist : Todoist › Réglages › Intégrations › Développeur.
5. Accepter les notifications quand macOS les demande.

## Organisation du code

```
Done/
  App/        point d'entrée, fenêtre et barre de menus
  Core/       logique pure, sans SwiftUI : modèles Todoist, règles, choix de la tâche, stats
  Data/       modèles SwiftData (plan du jour, sessions, interruptions, photos du backlog)
  Services/   client API Todoist, trousseau, notifications, appels AppKit
  State/      AppModel (tâches et plan) et FocusEngine (minuteur)
  Views/      écrans SwiftUI
```

Le projet utilise un dossier synchronisé : tout fichier ajouté dans `Done/` est compilé, sans modifier le projet Xcode.

## Règles de l'app

- **Candidates du matin** : P1 ou P2, sans `@Waiting`, avec `@Chantier-actif` ou une échéance dans les 3 jours.
- **Prochaine action** : la première sous-tâche sans `@Waiting`, dans l'ordre de Todoist.
- **Durée** : 15 min pour `@Quick`, 50 min pour `@Deepwork`, 25 min sinon. Pause de 10 min après une session Deepwork, 5 min sinon.
- **Réunions** : tâches datées avec une heure et dont le titre commence par « Réunion ». Si le titre contient « deepwork », « deepword » ou « focus », c'est un bloc de travail.
- **Avant une réunion** : si la tâche prévue ne tient pas, Done propose la suivante du plan qui tient, puis une tâche `@Quick`, puis la préparation de la réunion ou une pause.

Tout est réglable dans l'écran Réglages, sauf les noms de labels (dans `Done/Core/Rules.swift`).
