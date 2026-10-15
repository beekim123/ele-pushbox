#!/bin/sh
set -eu
PORTITOR_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$PORTITOR_ROOT/tools/godot-bin.sh"
find_portitor_godot
prepare_portitor_sdk
node "$PORTITOR_ROOT/game/tools/import_resources.mjs" import --no-model-routes
"$PORTITOR_GODOT" --headless --path "$PORTITOR_ROOT/game" --import --log-file "$PORTITOR_ROOT/game/reports/import.log"
exec "$PORTITOR_GODOT" --path "$PORTITOR_ROOT/game" "$@"
