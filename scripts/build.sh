#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build"
APP="$ROOT/dist/Network Dot.app"
mkdir -p "$BUILD/module-cache" "$APP/Contents/MacOS" "$APP/Contents/Resources"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
for ARCH in arm64 x86_64; do
    xcrun swiftc -O -sdk "$SDK" -target "$ARCH-apple-macos13.0" \
        -module-cache-path "$BUILD/module-cache" \
        -framework AppKit -framework Network -framework ServiceManagement \
        "$ROOT/Sources/ConnectivityState.swift" "$ROOT/Sources/main.swift" \
        -o "$BUILD/NetworkDot-$ARCH"
done
lipo -create "$BUILD/NetworkDot-arm64" "$BUILD/NetworkDot-x86_64" -output "$APP/Contents/MacOS/NetworkDot"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.henry.NetworkDot</string>
<key>CFBundleName</key><string>Network Dot</string>
<key>CFBundleDisplayName</key><string>Network Dot</string>
<key>CFBundleExecutable</key><string>NetworkDot</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
codesign --force --sign "${CODE_SIGN_IDENTITY:--}" --options runtime "$APP"
codesign --verify --deep --strict "$APP"
echo "Built universal app: $APP"
