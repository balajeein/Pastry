#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Scripts/package-dmg.sh — Package build/Pastry.app into a DMG
#
# Creates: build/Pastry.dmg
# Includes an Applications folder symlink for drag-and-drop install.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Pastry.app"
DMG_FILE="$BUILD_DIR/Pastry.dmg"
STAGING_DIR="$BUILD_DIR/dmg_staging"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

if [ ! -d "$APP_BUNDLE" ]; then
    echo -e "${RED}✘  No Pastry.app found at $APP_BUNDLE${NC}"
    echo -e "   Run ${CYAN}./Scripts/build.sh${NC} first."
    exit 1
fi

echo -e "${CYAN}📦 Creating Pastry.dmg installer…${NC}"

# Prepare staging directory
rm -rf "$STAGING_DIR" "$DMG_FILE"
mkdir -p "$STAGING_DIR"

# Copy Pastry.app into staging
cp -R "$APP_BUNDLE" "$STAGING_DIR/Pastry.app"

# Create Applications symlink for drag-and-drop installation
ln -s /Applications "$STAGING_DIR/Applications"

# Create UDZO compressed DMG
hdiutil create -volname "Pastry" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_FILE" >/dev/null

# Clean staging directory
rm -rf "$STAGING_DIR"

echo -e "${GREEN}✅ DMG created successfully${NC}"
echo -e "   ${BOLD}$DMG_FILE${NC}"
