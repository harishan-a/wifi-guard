#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="WiFiGuard"
INSTALL_DIR="$HOME/Applications"

echo "Building WiFi Guard (release)..."
swift build -c release 2>&1

BUILD_DIR=".build/release"
BINARY="$BUILD_DIR/$APP_NAME"

if [ ! -f "$BINARY" ]; then
    echo "Build failed — binary not found."
    exit 1
fi

# Create a minimal .app bundle
APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"

mkdir -p "$MACOS_DIR"

# Copy binary
cp "$BINARY" "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp "Resources/Info.plist" "$CONTENTS/Info.plist"

# Copy entitlements (for reference, not needed at runtime for unsigned apps)
cp "Resources/WiFiGuard.entitlements" "$CONTENTS/"

echo ""
echo "Installed to: $APP_BUNDLE"
echo ""
echo "To launch: open $APP_BUNDLE"
echo "To remove: rm -rf $APP_BUNDLE"
echo ""

# Optionally open the app
read -p "Launch now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$APP_BUNDLE"
fi
