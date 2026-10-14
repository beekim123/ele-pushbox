#!/bin/bash
set -euo pipefail
TASK_PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TASK_SDK_DIR="$TASK_PROJECT_DIR/vendor/ele-base-cpp"
TASK_SOURCE="${PUSHBOX_SDK_SOURCE:-https://github.com/beekim123/ele-base-cpp.git}"
TASK_PYTHON="${PUSHBOX_PYTHON_BIN:-python3}"
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
  echo '本工程使用 Godot 4.7.2。源码构建还须满足 SDK 锁定环境，详见 README.md。' >&2
  exit 1
fi
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1
mkdir -p "$TASK_PROJECT_DIR/vendor" "$TASK_PROJECT_DIR/bin" "$TASK_PROJECT_DIR/artifacts/logs"
touch "$TASK_PROJECT_DIR/vendor/.gdignore"
if [[ ! -d "$TASK_SDK_DIR/.git" ]]; then
  git clone "$TASK_SOURCE" "$TASK_SDK_DIR"
  git -C "$TASK_SDK_DIR" checkout --detach dacb93e
fi
if [[ "$(git -C "$TASK_SDK_DIR" rev-parse --short=7 HEAD)" != dacb93e ]]; then
  echo '项目内 SDK 必须固定到 dacb93e；不自动改动已有的另一版本。' >&2
  exit 1
fi
if [[ ! -x "$TASK_SDK_DIR/.venv/bin/python" ]]; then
  "$TASK_PYTHON" -m venv "$TASK_SDK_DIR/.venv"
  "$TASK_SDK_DIR/.venv/bin/python" -m pip install --require-hashes -r "$TASK_SDK_DIR/tools/requirements-build.txt"
fi
mkdir -p "$TASK_SDK_DIR/.local"
"$TASK_PYTHON" - "$TASK_SDK_DIR/.local/config.json" "$TASK_GODOT_BIN" <<'PY'
import json,sys
from pathlib import Path
Path(sys.argv[1]).write_text(json.dumps({'godot_path': sys.argv[2]})+'\n')
PY
cd "$TASK_SDK_DIR"
.venv/bin/python tools/fetch_deps.py
.venv/bin/python tools/check_environment.py --mode all > "$TASK_PROJECT_DIR/artifacts/logs/environment.json"
nice -n 10 .venv/bin/python tools/build.py --mode godot --config release --jobs 1 > "$TASK_PROJECT_DIR/artifacts/logs/sdk-build.log" 2>&1
cp build/godot/release/libele_godot.dylib "$TASK_PROJECT_DIR/bin/"
cp adapters/godot/shaders/palette.gdshader "$TASK_PROJECT_DIR/bin/"
cp examples/godot/demos/ele.gdextension "$TASK_PROJECT_DIR/"
cp LICENSE "$TASK_PROJECT_DIR/bin/LICENSE-ele-base-cpp.txt"
cp THIRD_PARTY.md "$TASK_PROJECT_DIR/bin/THIRD_PARTY.md"
cp vendor/godot-cpp/LICENSE.md "$TASK_PROJECT_DIR/bin/LICENSE-godot-cpp.txt"
cp vendor/box2d/LICENSE "$TASK_PROJECT_DIR/bin/LICENSE-box2d.txt"
"$TASK_PYTHON" - "$TASK_PROJECT_DIR/bin/build-metadata.json" "$TASK_PROJECT_DIR/bin/libele_godot.dylib" "$TASK_SDK_DIR" "$TASK_GODOT_BIN" <<'PY'
import hashlib,json,subprocess,sys
from pathlib import Path
metadata,library,sdk,godot = sys.argv[1:]
data = {
    'sdk_version': '1.2.0',
    'sdk_commit': subprocess.check_output(['git','-C',sdk,'rev-parse','HEAD'], text=True).strip(),
    'godot_version': subprocess.check_output([godot,'--version'], text=True).strip(),
    'build_mode': 'godot',
    'config': 'release',
    'jobs': 1,
    'dylib_sha256': hashlib.sha256(Path(library).read_bytes()).hexdigest(),
}
Path(metadata).write_text(json.dumps(data, indent=2)+'\n')
PY
mkdir -p "$TASK_PROJECT_DIR/.godot"
printf 'res://ele.gdextension\n' > "$TASK_PROJECT_DIR/.godot/extension_list.cfg"
echo 'SDK 扩展已准备。构建始终使用 --jobs 1，详细输出在 artifacts/logs/sdk-build.log。'
