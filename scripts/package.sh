#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Network Dot.app"
STAGE="$ROOT/.build/dmg-root"
mkdir -p "$STAGE"
if [[ ! -d "$APP" ]]; then "$ROOT/scripts/build.sh"; fi
rm -rf "$STAGE/Network Dot.app"
ditto "$APP" "$STAGE/Network Dot.app"
ln -sfn /Applications "$STAGE/Applications"
rm -f "$STAGE/Read Me - 使用说明.md"
cp "$ROOT/README.md" "$STAGE/README.md"
cp "$ROOT/README.zh-CN.md" "$STAGE/README.zh-CN.md"
hdiutil create -volname 'Network Dot 1.1.1' -srcfolder "$STAGE" -ov -format UDZO "$DIST/Network-Dot-1.1.1-universal.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/Network-Dot-1.1.1-universal.zip"
(cd "$DIST" && shasum -a 256 Network-Dot-1.1.1-universal.dmg Network-Dot-1.1.1-universal.zip > SHA256SUMS.txt)
