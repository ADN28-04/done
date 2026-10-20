#!/bin/bash
# Compile Done en version finale, l'installe dans /Applications et la relance.
# Usage, depuis le dossier du projet : ./scripts/install.sh
set -euo pipefail
cd "$(dirname "$0")/.."

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
