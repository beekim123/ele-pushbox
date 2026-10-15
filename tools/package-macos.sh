#!/bin/sh
set -eu
PORTITOR_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
PORTITOR_PACKAGE_NAME=PORTITOR-Night-Development
PORTITOR_RELEASE=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --name)
      if [ "$#" -lt 2 ]; then
        echo '--name requires an app name.' >&2
        exit 1
      fi
      PORTITOR_PACKAGE_NAME=${2%.app}
      shift 2
      ;;
    --release)
      PORTITOR_RELEASE=true
      shift
      ;;
    *)
      echo 'Usage: tools/package-macos.sh [--name PORTITOR-Night-Development] [--release]' >&2
      exit 1
      ;;
  esac
done
case "$PORTITOR_PACKAGE_NAME" in
  ''|.*|*[!A-Za-z0-9._-]*)
    echo 'Choose a simple app name that does not replace a Stage1 package.' >&2
    exit 1
    ;;
esac
PORTITOR_PACKAGE_FOLDED=$(printf '%s' "$PORTITOR_PACKAGE_NAME" | tr '[:upper:]' '[:lower:]')
case "$PORTITOR_PACKAGE_FOLDED" in
  portitor-stage1*)
    echo 'Stage1 packages are preserved; choose a development app name.' >&2
    exit 1
    ;;
esac
PORTITOR_APP="$PORTITOR_ROOT/builds/$PORTITOR_PACKAGE_NAME.app"
. "$PORTITOR_ROOT/tools/godot-bin.sh"
find_portitor_godot
prepare_portitor_sdk
node "$PORTITOR_ROOT/game/tools/import_resources.mjs" import --no-model-routes
if [ "$PORTITOR_RELEASE" = true ]; then
  node "$PORTITOR_ROOT/game/tools/import_resources.mjs" release
  echo 'Release export requires completed stage-one acceptance in docs/status.md.' >&2
  exit 1
fi
mkdir -p "$PORTITOR_ROOT/builds"
"$PORTITOR_GODOT" --headless --path "$PORTITOR_ROOT/game" --import
"$PORTITOR_GODOT" --headless --path "$PORTITOR_ROOT/game" --export-debug 'macOS Development' "$PORTITOR_APP"
# The installed official template contains a universal debug binary. Export it
# unchanged first, then retain only its arm64 slice; the SDK is arm64-only.
PORTITOR_EXECUTABLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PORTITOR_APP/Contents/Info.plist")
/usr/bin/lipo "$PORTITOR_APP/Contents/MacOS/$PORTITOR_EXECUTABLE" -thin arm64 -output "$PORTITOR_APP/Contents/MacOS/$PORTITOR_EXECUTABLE.arm64"
mv "$PORTITOR_APP/Contents/MacOS/$PORTITOR_EXECUTABLE.arm64" "$PORTITOR_APP/Contents/MacOS/$PORTITOR_EXECUTABLE"
chmod +x "$PORTITOR_APP/Contents/MacOS/$PORTITOR_EXECUTABLE"
# Godot exports the library by basename; preserve the extension's res://bin path.
mkdir -p "$PORTITOR_APP/Contents/Frameworks/bin"
mv "$PORTITOR_APP/Contents/Frameworks/libele_godot.dylib" "$PORTITOR_APP/Contents/Frameworks/bin/libele_godot.dylib"
mkdir -p "$PORTITOR_APP/Contents/Resources/licenses"
cp "$PORTITOR_ROOT"/third_party/ele-sdk/LICENSE*.txt "$PORTITOR_APP/Contents/Resources/licenses/"
cp "$PORTITOR_ROOT/third_party/fonts/fusion-pixel-12px/OFL.txt" "$PORTITOR_APP/Contents/Resources/licenses/Fusion-Pixel-12px-OFL.txt"
cp "$PORTITOR_ROOT/third_party/fonts/fusion-pixel-10px/OFL.txt" "$PORTITOR_APP/Contents/Resources/licenses/Fusion-Pixel-10px-OFL.txt"
# Thinning and bundle assembly invalidate the template's original signature.
# Seal this local development bundle without changing the bundled SDK bytes.
/usr/bin/codesign --force --sign - --timestamp=none "$PORTITOR_APP"
/usr/bin/codesign --verify --strict "$PORTITOR_APP"
printf '%s\n' "$PORTITOR_APP"
