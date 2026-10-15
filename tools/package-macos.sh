#!/bin/sh
set -eu
PORTITOR_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$PORTITOR_ROOT/tools/godot-bin.sh"
find_portitor_godot
prepare_portitor_sdk
node "$PORTITOR_ROOT/game/tools/import_resources.mjs" import
if [ "${1:-}" = "--release" ]; then
  node "$PORTITOR_ROOT/game/tools/import_resources.mjs" release
  echo 'Release export requires completed stage-one acceptance in docs/status.md.' >&2
  exit 1
fi
mkdir -p "$PORTITOR_ROOT/builds"
"$PORTITOR_GODOT" --headless --path "$PORTITOR_ROOT/game" --import
"$PORTITOR_GODOT" --headless --path "$PORTITOR_ROOT/game" --export-debug 'macOS Development' "$PORTITOR_ROOT/builds/PORTITOR-Stage1-Candidate.app"
# The installed official template contains a universal debug binary. Export it
# unchanged first, then retain only its arm64 slice; the SDK is arm64-only.
PORTITOR_APP="$PORTITOR_ROOT/builds/PORTITOR-Stage1-Candidate.app"
PORTITOR_EXECUTABLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PORTITOR_APP/Contents/Info.plist")
/usr/bin/lipo "$PORTITOR_APP/Contents/MacOS/$PORTITOR_EXECUTABLE" -thin arm64 -output "$PORTITOR_APP/Contents/MacOS/$PORTITOR_EXECUTABLE.arm64"
mv "$PORTITOR_APP/Contents/MacOS/$PORTITOR_EXECUTABLE.arm64" "$PORTITOR_APP/Contents/MacOS/$PORTITOR_EXECUTABLE"
chmod +x "$PORTITOR_APP/Contents/MacOS/$PORTITOR_EXECUTABLE"
# Godot exports the library by basename; preserve the extension's res://bin path.
mkdir -p "$PORTITOR_APP/Contents/Frameworks/bin"
mv "$PORTITOR_APP/Contents/Frameworks/libele_godot.dylib" "$PORTITOR_APP/Contents/Frameworks/bin/libele_godot.dylib"
mkdir -p "$PORTITOR_ROOT/builds/PORTITOR-Stage1-Candidate.app/Contents/Resources/licenses"
cp "$PORTITOR_ROOT"/third_party/ele-sdk/LICENSE*.txt "$PORTITOR_ROOT/builds/PORTITOR-Stage1-Candidate.app/Contents/Resources/licenses/"
cp "$PORTITOR_ROOT/third_party/fonts/fusion-pixel-12px/OFL.txt" "$PORTITOR_ROOT/builds/PORTITOR-Stage1-Candidate.app/Contents/Resources/licenses/Fusion-Pixel-12px-OFL.txt"
cp "$PORTITOR_ROOT/third_party/fonts/fusion-pixel-10px/OFL.txt" "$PORTITOR_ROOT/builds/PORTITOR-Stage1-Candidate.app/Contents/Resources/licenses/Fusion-Pixel-10px-OFL.txt"
printf '%s\n' "$PORTITOR_ROOT/builds/PORTITOR-Stage1-Candidate.app"
