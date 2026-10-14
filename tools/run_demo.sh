#!/bin/bash
set -euo pipefail
TASK_PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -n "${PUSHBOX_GODOT_BIN:-}" ]]; then
  TASK_GODOT_BIN="$PUSHBOX_GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  TASK_GODOT_BIN="$(command -v godot)"
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  TASK_GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
else
  TASK_GODOT_BIN="$HOME/Desktop/CURRGO/ele-proj/zips/Godot.app/Contents/MacOS/Godot"
fi
if [[ ! -x "$TASK_GODOT_BIN" ]]; then
  echo '找不到 Godot 4.7.2。请设置 PUSHBOX_GODOT_BIN 为可执行文件的完整路径。' >&2
  exit 1
fi
if [[ "$("$TASK_GODOT_BIN" --version)" != 4.7.2.* ]]; then
  echo '本工程验收版本是 Godot 4.7.2，请使用此版本。' >&2
  exit 1
fi
if [[ ! -f "$TASK_PROJECT_DIR/bin/libele_godot.dylib" ]]; then
  echo '缺少 SDK 扩展。先运行 tools/prepare_sdk.sh。' >&2
  exit 1
fi
mkdir -p "$TASK_PROJECT_DIR/.godot"
printf 'res://ele.gdextension\n' > "$TASK_PROJECT_DIR/.godot/extension_list.cfg"
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1
exec "$TASK_GODOT_BIN" --single-threaded-scene --max-fps 60 --path "$TASK_PROJECT_DIR" "$@"
