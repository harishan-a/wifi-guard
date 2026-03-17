#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Building WiFi Guard..."
swift build -c release 2>&1

BUILD_DIR=".build/release"
if [ -f "$BUILD_DIR/WiFiGuard" ]; then
    echo ""
    echo "Build successful!"
    echo "Binary: $BUILD_DIR/WiFiGuard"
    echo "Size: $(du -h "$BUILD_DIR/WiFiGuard" | awk '{print $1}')"
    echo ""
    echo "Run with: $BUILD_DIR/WiFiGuard"
else
    echo "Build failed — binary not found."
    exit 1
fi
