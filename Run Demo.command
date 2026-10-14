#!/bin/bash
set -euo pipefail
TASK_PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$TASK_PROJECT_DIR/tools/run_demo.sh"
