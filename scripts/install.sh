#!/bin/bash
# Compile Done en version finale, l'installe dans /Applications et la relance.
# Usage, depuis le dossier du projet : ./scripts/install.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# Utilise Xcode même quand ce sont les outils de ligne de commande qui sont sélectionnés.
if ! xcodebuild -version > /dev/null 2>&1; then
  XCODE_APP=$(ls -d /Applications/Xcode*.app 2> /dev/null | head -n 1 || true)
  if [ -z "$XCODE_APP" ]; then
    echo "Xcode est introuvable dans Applications." >&2
    exit 1
  fi
  export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"
fi

echo "Compilation de Done…"
xcodebuild -project Done.xcodeproj -target Done -configuration Release \
  SYMROOT="$PWD/build" -allowProvisioningUpdates -quiet build

APP="build/Release/Done.app"
if [ ! -d "$APP" ]; then
  echo "La compilation est terminée, mais $APP est introuvable." >&2
  exit 1
fi

# Ferme Done proprement si elle tourne : elle coupe alors « Ne pas déranger ».
if pgrep -x Done > /dev/null; then
  echo "Fermeture de la version en cours…"
  osascript -e 'quit app "Done"' > /dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    pgrep -x Done > /dev/null || break
    sleep 0.5
  done
fi

rm -rf /Applications/Done.app
cp -R "$APP" /Applications/
open /Applications/Done.app
echo "Done est à jour dans Applications."
