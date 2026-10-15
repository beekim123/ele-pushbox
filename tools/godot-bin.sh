#!/bin/sh
# Sourced by the two user entry points and the test runner.
find_portitor_godot() {
  if [ -n "${PUSHBOX_GODOT_BIN:-}" ]; then
    PORTITOR_GODOT=$PUSHBOX_GODOT_BIN
  elif command -v godot >/dev/null 2>&1; then
    PORTITOR_GODOT=$(command -v godot)
  elif [ -x /Applications/Godot.app/Contents/MacOS/Godot ]; then
    PORTITOR_GODOT=/Applications/Godot.app/Contents/MacOS/Godot
  elif [ -x "$PORTITOR_ROOT/../ele-proj/zips/Godot.app/Contents/MacOS/Godot" ]; then
    PORTITOR_GODOT="$PORTITOR_ROOT/../ele-proj/zips/Godot.app/Contents/MacOS/Godot"
  else
    echo 'Godot 4.7.2 not found. Set PUSHBOX_GODOT_BIN to its executable.' >&2
    return 1
  fi
  PORTITOR_VERSION=$("$PORTITOR_GODOT" --version) || return 1
  case "$PORTITOR_VERSION" in
    4.7.2.*) ;;
    *) echo "Godot 4.7.2 required; found $PORTITOR_VERSION" >&2; return 1 ;;
  esac
  export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1
}

prepare_portitor_sdk() {
  mkdir -p "$PORTITOR_ROOT/game/bin" "$PORTITOR_ROOT/game/.godot"
  cp "$PORTITOR_ROOT/third_party/ele-sdk/libele_godot.dylib" "$PORTITOR_ROOT/game/bin/"
  cp "$PORTITOR_ROOT/third_party/ele-sdk/palette.gdshader" "$PORTITOR_ROOT/game/bin/"
  printf '%s\n' 'res://ele.gdextension' > "$PORTITOR_ROOT/game/.godot/extension_list.cfg"
}
