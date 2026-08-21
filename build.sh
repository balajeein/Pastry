#!/bin/bash
# ──────────────────────────────────────────────────────────────
# build.sh — Optimized release build of Pastry.app
#
# Produces: build/Pastry.app  (code-signed, ready to distribute)
# Does NOT create a DMG. Use  make release  for that.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Pastry.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}🔨 Building Pastry (release, optimized)…${NC}"
start_time=$(date +%s)

# Clean previous build
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Compile — release mode with full optimization
xcrun swiftc \
    -swift-version 5 \
    -O \
    -o "$MACOS_DIR/Pastry" \
    $(find "$PROJECT_DIR/Pastry" "$PROJECT_DIR/PastryApp" -name "*.swift")

# Copy resources
cp "$PROJECT_DIR/Pastry/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

if [ -f "$PROJECT_DIR/Pastry/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Pastry/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Ad-hoc code sign
codesign -s - --force --deep "$APP_BUNDLE"

end_time=$(date +%s)
elapsed=$((end_time - start_time))
echo -e "${GREEN}✅ Release build succeeded${NC} (${elapsed}s)"
echo -e "   ${BOLD}$APP_BUNDLE${NC}"
echo ""
echo -e "   To launch:  ${CYAN}./run.sh${NC}"
echo -e "   To make DMG: ${CYAN}make release${NC}"
