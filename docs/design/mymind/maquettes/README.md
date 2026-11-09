# Maquettes validées

Aperçus HTML interactifs, validés avant d'être codés en SwiftUI. Ouvrir un fichier dans un navigateur.

- `minuteur-de-focus.html` : écran de session. Version retenue, la piste C « Grands chiffres » :
  - chiffres du minuteur en Oswald SemiBold, minutes sur deux chiffres (« 08:42 ») ; chaque chiffre dans une
    case de largeur fixe (le chiffre le plus large de la police, moins 0,04 em ; deux-points : sa largeur moins
    0,01 em), pour des chiffres serrés qui ne bougent pas d'une seconde à l'autre ;
  - dessous, une règle de 1000 points au plus (seule sa longueur suit la place, les tailles sont fixes),
    graduée de 0 à gauche à la durée de la session à droite, une graduation par minute (2 × 11 toutes les
    5 min, 1,2 × 6 sinon), un chiffre toutes les 5 min (toutes les 10 au-delà de 30 min), sans unité ;
  - une barre de 11 points ancrée à gauche, en braise (cobalt en pause café, gris à l'arrêt), dont le bout
    avance vers 0 et pointe les minutes qui restent ; elle luit doucement dans la dernière minute ;
  - en pause, les chiffres clignotent lentement ; « Réduire les animations » coupe clignotement et lueur.
  Les pistes A (cadran gradué) et B (disque d'une heure) restent dans la page pour mémoire.
- `ambiance-ma-journee.html` : animations d'ambiance de Ma journée. Retenues : les halos en dérive lente
  (une petite ellipse en 22 et 26 secondes, en contretemps) et le soleil de la date qui fait un tour en 4 s
  à l'ouverture. Immobiles avec « Réduire les animations ».
