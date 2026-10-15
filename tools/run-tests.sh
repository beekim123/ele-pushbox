#!/bin/sh
set -eu
PORTITOR_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$PORTITOR_ROOT/tools/godot-bin.sh"
find_portitor_godot
prepare_portitor_sdk
exec python3 "$PORTITOR_ROOT/game/tools/run_tests.py" "$PORTITOR_GODOT" "$@"
