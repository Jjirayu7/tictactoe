#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$ROOT"
swift build -c release
rm -rf tictactoe.app
mkdir -p tictactoe.app/Contents/MacOS tictactoe.app/Contents/Resources
cp .build/arm64-apple-macosx/release/tictactoe tictactoe.app/Contents/MacOS/tictactoe
cp -R .build/arm64-apple-macosx/release/tictactoe_tictactoe.bundle tictactoe.app/Contents/Resources/
cp Info.plist tictactoe.app/Contents/Info.plist
chmod +x tictactoe.app/Contents/MacOS/tictactoe
codesign --force --deep --sign - tictactoe.app
printf '%s\n' "Built $ROOT/tictactoe.app"
