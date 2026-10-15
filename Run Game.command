#!/bin/sh
PORTITOR_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$PORTITOR_ROOT/run.sh" "$@"
