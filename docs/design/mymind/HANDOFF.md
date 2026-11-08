# Passage de Done au design system Mymind

Ce dossier décrit la direction « Mymind », qui remplace la v5 (indigo, Archivo). Les références sont `design-system/README.md`, `design-system/tokens.json` et `design-system/components/` (un README et un aperçu HTML par composant, classes `d-…` dans `components/bundle.css`). L'écran cible est `design-system/components/ControlCenter/`, rendu dans `ma-journee-clair.png` et `ma-journee-sombre.png`. Les aperçus sont des maquettes web : dans l'app, tout reste en SwiftUI, sans dépendance externe.

## Ce qui ne change pas

- La logique (`Done/Core`, `Done/State`, `Done/Services`), le connecteur Claude, le format des fichiers.
- Les noms des rôles existants de `DoneColor` et des styles de `DoneTextStyle`. Le code continue de ne référencer que des rôles.
- Les règles de `CLAUDE.md` : textes courts, pas de point d'exclamation, aucune dépendance, aucune donnée réelle.

## Étapes

1. **Couleurs** (`Done/Views/Theme.swift`, `DoneColor`) : reprendre toutes les valeurs clair et sombre de `tokens.json` > `color.tokens`. Ajouter `accent`, `onAccent`, `accentTint`, `accentText`, `success`, `successTint`, `successText`, `tagPink`, `tagYellow`, `cardParchment`, `cardSage`, `cardSlate`, `cardBlush`, `haloWarm`, `haloPink`. Attention : en sombre, `actionPrimary` devient clair et `actionOnPrimary` sombre (pilule inversée).
2. **Polices** : copier les TTF de `fonts/` dans `Done/Fonts` (chargés par `FontLoader`) et les licences dans `docs/fonts/`. Retirer les fichiers Archivo.
   - `displayXL` 46/50 et `displayL` 32/38 : `NewsreaderDisplay-Medium` ; la salutation en `NewsreaderDisplay-MediumItalic`.
   - `displayM` 22/28 et `noteTitle` 17/22 : `NewsreaderText-Medium`.
   - Texte : `NunitoSans-Regular`, `-SemiBold` (titres de tâche, libellés), `-Bold` (`title`, `label`).
   - Nombres : `NunitoSans-Light` pour `numericXL` 60/64 et `numericL` 44/48, `-SemiBold` pour `numericM` et `numericS`. Les chiffres de Nunito Sans sont déjà à chasse fixe.
   - `noteMono` 13/19 : `CourierPrime-Regular`, seulement dans les cartes de note.
3. **Rayons et mesures** (`DoneRadius`, `DoneSpace`) : `xs` 6, `sm` 12, `md` 18, `lg` 24, et `pill` (capsule). Contrôles à 34, compacts à 28, puces à 22, case à 18, anneau à 6 de trait. Ombres `shadowCard`, `shadowRaised`, `shadowControl` de `tokens.json`.
4. **Composants existants** (un README par composant) : boutons et puces en capsule, bouton principal en encre, cartes avec `shadowCard` et rayon 24, `StateChip` (`today` en `accentTint`, `done` en `successTint`), `NoticeBox` ton `success`, `ProgressRing` en braise.
5. **Nouveaux composants** : `Rail`, `Greeting`, `SearchField` (⌘K), `CaptureBar`, `NoteCard` et la mosaïque, `TagPill`, `DayTimeline` revue.
6. **Écran Ma journée** (`ControlCenter`) : nouvel écran d'arrivée qui remplace Focus, Aujourd'hui et Plan du jour (les vues peuvent être réutilisées comme cartes). La session de focus reste plein écran. Projets et étiquettes passent dans un écran Listes (⌘4) avec sa propre colonne (`NavItem`). Raccourcis : ⌘1 Ma journée, ⌘2 Calendrier, ⌘3 Notes, ⌘4 Listes, ⌘5 Stats.
7. **Mouvement** : un `enum DoneMotion` avec les durées et courbes de `tokens.json` (équivalents SwiftUI dans la section Mouvement du README), et `@Environment(\.accessibilityReduceMotion)` respecté partout.
8. **Logo** : remplacer les PNG de `AppIcon.appiconset` et `DoneGlyph.imageset` par ceux de `logo/` (mêmes noms), `docs/design/icon.svg` et `glyph.svg` par les SVG de `logo/`, et redessiner `DoneAppIcon` (fond blanc, deux halos, anneau fin à 30/824, ouverture de 60°, point braise). `AccentColor` = `focusRing` (#1573DD en clair, #5AA2F0 en sombre).
9. **Documentation** : réécrire `docs/design-system.md` à partir de `design-system/README.md`, mettre à jour `docs/spec.md` (écran Ma journée, raccourcis) et les mentions de la v5 dans `CLAUDE.md`.

## Vérifications

- L'app compile ; chaque écran est vérifié en clair et en sombre, à 1376 × 852 et à 1100 de large.
- Toutes les paires texte et fond de `tokens.json` passent AA : ne pas changer une couleur sans recalculer.
- « Réduire les animations » activé : il ne reste que des fondus.
- Aucune couleur ni police écrite en dur hors de `Theme.swift`.
