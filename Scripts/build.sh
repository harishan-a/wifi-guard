#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Building WiFi Guard..."
swift build -c release 2>&1

BINARY=".build/release/WiFiGuard"
if [ ! -f "$BINARY" ]; then
    echo "Build failed — binary not found."
    exit 1
fi

# Create a .app bundle (required for UNUserNotificationCenter, SMAppService, etc.)
APP_BUNDLE=".build/WiFiGuard.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"

cp "$BINARY" "$MACOS_DIR/WiFiGuard"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"

echo ""
echo "Build successful!"
echo "App bundle: $APP_BUNDLE"
echo "Size: $(du -sh "$APP_BUNDLE" | awk '{print $1}')"
echo ""
echo "Run with: open $APP_BUNDLE"
