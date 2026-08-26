#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Scripts/build.sh — Optimized release build of Pastry.app
#
# Produces: build/Pastry.app  (code-signed, ready for testing/release)
# Does NOT create a DMG. Use ./release.sh for full release workflow.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Pastry.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

VERSION_FILE="$PROJECT_DIR/VERSION"
MARKETING_VERSION="1.0.0"
BUILD_NUMBER="1"
if [ -f "$VERSION_FILE" ]; then
    source "$VERSION_FILE" 2>/dev/null || true
fi

echo -e "${CYAN}🔨 Building Pastry (release, v${MARKETING_VERSION} build ${BUILD_NUMBER})…${NC}"
start_time=$(date +%s)

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Compile Universal 2 (arm64 + x86_64) targeting macOS 11.0
xcrun swiftc \
    -swift-version 5 \
    -target arm64-apple-macos11.0 \
    -O \
    -o "$MACOS_DIR/Pastry-arm64" \
    $(find "$PROJECT_DIR/Pastry" "$PROJECT_DIR/PastryApp" -name "*.swift")

xcrun swiftc \
    -swift-version 5 \
    -target x86_64-apple-macos11.0 \
    -O \
    -o "$MACOS_DIR/Pastry-x86_64" \
    $(find "$PROJECT_DIR/Pastry" "$PROJECT_DIR/PastryApp" -name "*.swift")

lipo -create -output "$MACOS_DIR/Pastry" "$MACOS_DIR/Pastry-arm64" "$MACOS_DIR/Pastry-x86_64"
rm -f "$MACOS_DIR/Pastry-arm64" "$MACOS_DIR/Pastry-x86_64"

# Copy Info.plist and inject current version numbers
cp "$PROJECT_DIR/Pastry/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$MARKETING_VERSION" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true

if [ -f "$PROJECT_DIR/Pastry/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Pastry/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Code sign — use Developer ID Application if present, else Pastry Dev, else ad-hoc
if security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID Application"; then
    DEV_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
    echo -e "${CYAN}🔑 Signing with Developer ID: ${DEV_ID}${NC}"
    codesign -s "$DEV_ID" --force --deep --options runtime --entitlements "$PROJECT_DIR/Pastry/Resources/Pastry.entitlements" "$APP_BUNDLE"
elif security find-identity -v -p codesigning 2>/dev/null | grep -q "Pastry Dev"; then
    echo -e "${CYAN}🔑 Signing with local 'Pastry Dev' certificate…${NC}"
    codesign -s "Pastry Dev" --force --deep "$APP_BUNDLE" 2>/dev/null
else
    echo -e "${YELLOW}⚠  Using ad-hoc signature.${NC}"
    codesign -s - --force --deep "$APP_BUNDLE" 2>/dev/null
fi

end_time=$(date +%s)
elapsed=$((end_time - start_time))
echo -e "${GREEN}✅ Release build succeeded${NC} (${elapsed}s)"
echo -e "   ${BOLD}$APP_BUNDLE${NC}"
