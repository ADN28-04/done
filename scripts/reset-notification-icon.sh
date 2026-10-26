#!/bin/bash
# Remet le logo de Done dans les notifications.
# macOS rattache les notifications à l'identifiant de l'app (com.adnan.done). Plusieurs copies
# portent cet identifiant (Xcode, dossier build, ancienne copie téléchargée), dont certaines datent
# d'avant l'icône : macOS peut garder la leur, et la notification s'affiche sans logo.
# Le script fait oublier ces copies à macOS, réenregistre celle d'Applications et relance le centre
# de notifications. Il ne supprime aucun fichier en dehors du dossier build du projet.
# Usage, depuis le dossier du projet : ./scripts/reset-notification-icon.sh
set -uo pipefail
cd "$(dirname "$0")/.."

BUNDLE_ID="com.adnan.done"
APP="/Applications/Done.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [ ! -d "$APP" ]; then
  echo "Done n'est pas dans Applications : lance d'abord ./scripts/install.sh." >&2
  exit 1
fi

# L'app installée doit contenir son icône, sinon le problème vient de la compilation.
ICON_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconName" "$APP/Contents/Info.plist" 2> /dev/null || true)
if [ -z "$ICON_NAME" ] || [ ! -f "$APP/Contents/Resources/Assets.car" ]; then
  echo "L'app installée n'a pas d'icône. Relance ./scripts/install.sh, puis ce script." >&2
  exit 1
fi

# Copies connues de Spotlight et de Launch Services, même celles qui ont été effacées depuis.
echo "Recherche des autres copies de Done…"
COPIES=$(
  {
    mdfind "kMDItemCFBundleIdentifier == '$BUNDLE_ID'" 2> /dev/null
    "$LSREGISTER" -dump 2> /dev/null | sed -nE 's/^path: +(.*\/Done\.app)( \(0x[0-9a-f]+\))?$/\1/p'
  } | sort -u
)

FORGOTTEN=()
while IFS= read -r copy; do
  if [ -z "$copy" ] || [ "$copy" = "$APP" ]; then
    continue
  fi
  # Une copie encore sur le disque doit être Done, pas une autre app du même nom.
  if [ -d "$copy" ]; then
    id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$copy/Contents/Info.plist" 2> /dev/null || true)
    [ "$id" = "$BUNDLE_ID" ] || continue
  fi
  "$LSREGISTER" -u "$copy" > /dev/null 2>&1 || true
  FORGOTTEN+=("$copy")
done <<< "$COPIES"

# La copie du dossier build ne sert qu'à l'installation : install.sh la recrée.
rm -rf build/Release/Done.app

"$LSREGISTER" -f "$APP"

# Ferme Done proprement si elle tourne : elle coupe alors « Ne pas déranger ».
if pgrep -x Done > /dev/null; then
  osascript -e 'quit app "Done"' > /dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    pgrep -x Done > /dev/null || break
    sleep 0.5
  done
fi

# Le centre de notifications relit les icônes à son redémarrage ; macOS le relance aussitôt.
# Les notifications déjà programmées sont conservées.
killall usernoted NotificationCenter > /dev/null 2>&1 || true
sleep 2
open "$APP"

echo
if [ ${#FORGOTTEN[@]} -gt 0 ]; then
  echo "Copies oubliées par macOS :"
  for copy in "${FORGOTTEN[@]}"; do
    if [ -d "$copy" ]; then
      echo "  $copy (encore sur le disque : supprime-la si tu n'en as plus besoin)"
    else
      echo "  $copy (déjà effacée)"
    fi
  done
else
  echo "Aucune autre copie de Done trouvée."
fi
echo
echo "Dans Done, ouvre Réglages › Notifications et clique sur Tester."
echo "Si le logo manque encore, ferme ta session macOS et rouvre-la : macOS vide alors son cache d'icônes."
