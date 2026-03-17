#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="WiFiGuard"
INSTALL_DIR="$HOME/Applications"

echo "Building WiFi Guard (release)..."
swift build -c release 2>&1

BINARY=".build/release/$APP_NAME"

if [ ! -f "$BINARY" ]; then
    echo "Build failed — binary not found."
    exit 1
fi

# Kill any running instance
pkill -x "$APP_NAME" 2>/dev/null && sleep 1 || true

# Create .app bundle
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BINARY" "$MACOS_DIR/$APP_NAME"
cp "Resources/Info.plist" "$CONTENTS/Info.plist"
[ -f "Resources/AppIcon.icns" ] && cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

# Touch the bundle so Finder refreshes the icon cache
touch "$APP_BUNDLE"

echo ""
echo "Installed to: $APP_BUNDLE"
echo ""
echo "To launch:  open '$APP_BUNDLE'"
echo "To remove:  rm -rf '$APP_BUNDLE'"
echo ""

read -p "Launch now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$APP_BUNDLE"
fi
