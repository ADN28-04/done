# Stepper

Paire de boutons « − » et « + » qui fait varier un nombre entier dans les réglages.

Rendu web écrit à la main à partir de `DoneStepper` dans `Done/Views/Theme.swift`.

## Mesures

- Deux boutons secondaires compacts (`.d-btn--compact`, 28 de haut), espacés de `s4`.
- Le bouton qui sortirait de l'intervalle est désactivé.

## Ce que fournit l'appelant

La valeur liée, l'intervalle (`range`) et le pas (`step`, 1 par défaut). La valeur elle-même s'affiche à côté, en `numericM`, avec son unité (« 15 min »).
