# Rail

Rail d'icônes à gauche de la fenêtre : la navigation principale de Done, en boutons ronds sur verre clair.

Composant ajouté par la direction Mymind. Il remplace la barre latérale de `RootView.swift` pour les écrans principaux ; les projets et étiquettes passent dans l'écran Listes.

## Contenu, de haut en bas

1. Les trois boutons de fenêtre de macOS (le rail commence sous la barre de titre transparente).
2. **Capturer** : bouton `accent` (braise) avec un +, qui ouvre la saisie complète (⌘N).
3. **Ma journée** (⌘1), **Calendrier** (⌘2), **Notes** (⌘3), **Listes** (⌘4), **Stats** (⌘5).
4. En bas : **Réglages**, puis le logo, qui montre le minuteur en cours quand une session tourne.

## Règles

- L'écran affiché est le bouton plein `actionPrimary` ; les autres sont sur `surfaceDefault` avec `shadowCard`.
- Listes porte une pastille `accent` : le nombre de tâches de l'Inbox à trier, jamais un autre compte.
- Chaque bouton a une aide au survol (son nom et son raccourci), puisqu'il n'a pas de libellé.

## Mesures

Largeur `rail-width` (84), boutons `rail-button` (44), écart 10, icônes de 19. Fond `bgSunken` à 70 % avec flou (en SwiftUI : `.background(.ultraThinMaterial)` teinté), trait `borderSubtle` à droite.

## Ce que fournit l'appelant

L'écran courant, le compte de l'Inbox et l'action de chaque bouton.
