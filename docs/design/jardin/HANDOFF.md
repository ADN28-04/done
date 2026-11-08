# Passage de Done au design system Jardin

Ce dossier décrit la direction « Jardin » qui remplace la v5 (indigo, Archivo SemiCondensed). La référence est `design-system/README.md` et `design-system/tokens.json` ; les aperçus HTML de `design-system/components/` montrent chaque composant et ses animations (classes `d-…` dans `components/bundle.css`). Ces aperçus sont des maquettes web : dans l'app, tout reste en SwiftUI, sans dépendance externe.

## Ce qui ne change pas

- Les noms des rôles de `DoneColor`, des styles de `DoneTextStyle` et des composants. Le code continue de ne référencer que des rôles, jamais une couleur de marque.
- Archivo pour le texte et tous les nombres (chiffres tabulaires).
- Les règles de `CLAUDE.md` : textes courts, pas de point d'exclamation, aucune dépendance, aucune donnée réelle.

## Étapes

1. **Couleurs** (`Done/Views/Theme.swift`, `DoneColor`) : reprendre toutes les valeurs clair et sombre de `tokens.json` > `color.tokens`. Attention : en sombre, `actionOnPrimary`, `stateOnActive` et `meetingOnNow` ne sont plus blancs (#0F2419). Ajouter quatre rôles : `sun`, `onSun`, `sunTint`, `sunText`. `meetingHatch` passe à 16 % d'opacité.
2. **Rayons** (`DoneRadius`) : `xs` 5, `chip` 8 (nouveau, remplace les 4 écrits en dur), `sm` 10, `md` 14, `lg` 20.
3. **Typographie** :
   - Copier `fonts/Fraunces-SoftSemiBold.ttf` dans `Done/Fonts` (nom PostScript `FrauncesSoft-SemiBold`, déjà pris en charge par `FontLoader`) et `fonts/OFL-Fraunces.txt` dans `docs/fonts/`.
   - `displayXL` 46/52, -0,01 em ; `displayL` 34/40, -0,005 em ; `displayM` 23/28 : tous en `FrauncesSoft-SemiBold`.
   - `numericXL` passe d'Archivo Light à Archivo Regular.
   - Retirer `Archivo-SemiCondensedSemiBold.ttf` s'il n'est plus utilisé nulle part.
4. **Mesures** : puces à 22 de haut (marge 8), case à cocher à 18 (rayon `xs`). Ombres de `shadow` dans `tokens.json`, teintées de l'encre #23281F en clair.
5. **Mouvement** : créer un `enum DoneMotion` avec les durées et courbes de `tokens.json` (`duration`, `easing`) et leurs équivalents SwiftUI listés dans la section Mouvement du README. Respecter `@Environment(\.accessibilityReduceMotion)` : fondus seulement, pas d'échelle, de rebond ni d'éclat.
6. **Composants** (voir chaque `components/<Nom>/README.md`) :
   - `StateChip` : le genre `active` devient « Aujourd'hui » avec `sun.max` sur `sunTint` ; ajouter un genre « Fait » sur `sunTint`, et garder le « fait un autre jour » en texte seul.
   - `NoticeBox` : ajouter le ton `success` (`sun.max`, `sunText` sur `sunTint`).
   - `TaskCheckbox` et ligne de tâche : rebond de la case, coche tracée, éclat de huit pétales `sun`, titre barré de gauche à droite, puce « Fait » qui rebondit, puis glissement vers « Fait aujourd'hui ».
   - Carte de fin de pomodoro (`SessionViews.swift`) : suivre `components/PomodoroDone/README.md`, avec la série du jour (une pastille `sun` par pomodoro fait) et la phrase « Ne pomodoro aujourd'hui ».
   - `DoneSegmented` : le segment choisi glisse (`matchedGeometryEffect`).
   - `NavItem` « Aujourd'hui » : icône `sun.max` en `sunText`.
7. **Logo** :
   - Remplacer les PNG de `Done/Assets.xcassets/AppIcon.appiconset` et `DoneGlyph.imageset` par ceux de `logo/` (mêmes noms, mêmes `Contents.json`).
   - Remplacer `docs/design/icon.svg` et `glyph.svg` par `logo/done-app-icon.svg` et `logo/done-glyph.svg`.
   - Mettre à jour la vue `DoneAppIcon` : dégradé #3B7A5B vers #204F3A, anneau crème #F7F3E8 à 24 %, arc de 300° (trim jusqu'à 0,833), soleil #F6C343 au milieu de l'ouverture (330°, rayon 56/824 de la taille).
   - `AccentColor` : `stateActive`, soit #3B7A5B en clair et #7CC39C en sombre.
8. **Documentation** : réécrire `docs/design-system.md` pour la v6 Jardin à partir de `design-system/README.md`, copier ce dossier dans `docs/design/jardin/`, et mettre à jour les mentions d'indigo et d'Archivo SemiCondensed dans `CLAUDE.md`.

## Vérifications

- L'app compile et se lance ; vérifier chaque écran en clair et en sombre.
- Toutes les paires texte et fond de `tokens.json` passent AA (les ratios sont dans le README) : ne pas « corriger » une couleur sans recalculer.
- Activer « Réduire les animations » dans macOS et vérifier qu'il ne reste que des fondus.
- Aucune couleur écrite en dur hors de `Theme.swift`.
