#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT"
APP_NAME=tictactoe
APP_BUNDLE="$ROOT/$APP_NAME.app"
ICON_SOURCE="$ROOT/assets/AppIcon.png"
swift build -c release
BIN_DIR=$(swift build -c release --show-bin-path)
RESOURCE_BUNDLE=
for candidate in "$BIN_DIR"/tictactoe_*.bundle; do
    if [ -d "$candidate" ]; then
        RESOURCE_BUNDLE="$candidate"
        break
    fi
done
if [ -z "$RESOURCE_BUNDLE" ]; then
    printf '%s\n' "Missing SwiftPM resource bundle in $BIN_DIR" >&2
    exit 1
fi
ICONSET_ROOT=$(mktemp -d)
ICONSET_DIR="$ICONSET_ROOT/$APP_NAME.iconset"
mkdir -p "$ICONSET_DIR"
trap 'rm -rf "$ICONSET_ROOT"' EXIT

if [ ! -f "$ICON_SOURCE" ]; then
    printf '%s\n' "Missing app icon: $ICON_SOURCE" >&2
    exit 1
fi

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    doubled=$((size * 2))
    sips -z "$doubled" "$doubled" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done
ICON_FILE="$ROOT/.build/$APP_NAME.icns"
iconutil --convert icns --output "$ICON_FILE" "$ICONSET_DIR"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp -R "$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/"
cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/$APP_NAME.icns"
cp Info.plist "$APP_BUNDLE/Contents/Info.plist"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
codesign --force --deep --sign - "$APP_BUNDLE"
printf '%s\n' "Built $APP_BUNDLE"
