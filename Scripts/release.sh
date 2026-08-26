#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Scripts/release.sh — Public Production Release Pipeline for Pastry
#
# Strict Public Release Workflow:
# 1. Validates Git working tree clean state (or --skip-git-check)
# 2. Validates VERSION source of truth file exists
# 3. Validates Info.plist bundle identifier == com.balajee.Pastry
# 4. Validates required entitlements file exists
# 5. REQUIRES a valid "Developer ID Application" certificate in Keychain
#    (FAILS IMMEDIATELY if missing — does NOT fall back to local dev cert)
# 6. Performs clean optimized release build (-O)
# 7. Injects MARKETING_VERSION and BUILD_NUMBER into Info.plist
# 8. Signs with Developer ID Application + Hardened Runtime + Entitlements
# 9. Verifies code signature strictly (codesign --verify, codesign -dv)
# 10. Packages build/Pastry.dmg (with drag-and-drop Applications shortcut)
# 11. Signs build/Pastry.dmg with Developer ID Application
# 12. Submits to Apple Notary Service via xcrun notarytool
# 13. Staples notarization ticket (xcrun stapler staple)
# 14. Outputs final verified public release artifact: build/Pastry.dmg
# ──────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Pastry.app"
DMG_FILE="$BUILD_DIR/Pastry.dmg"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
ENTITLEMENTS="$PROJECT_DIR/Pastry/Resources/Pastry.entitlements"
INFO_PLIST_SRC="$PROJECT_DIR/Pastry/Resources/Info.plist"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SKIP_GIT_CHECK=false
for arg in "$@"; do
    if [ "$arg" == "--skip-git-check" ]; then
        SKIP_GIT_CHECK=true
    fi
done

echo -e "${CYAN}${BOLD}🚀 Pastry Public Production Release Pipeline${NC}\n"

# ── 1. Validate Version File ──────────────────────────────────
VERSION_FILE="$PROJECT_DIR/VERSION"
if [ ! -f "$VERSION_FILE" ]; then
    echo -e "${RED}✘  VERSION file missing at $VERSION_FILE${NC}"
    exit 1
fi

source "$VERSION_FILE"

echo -e "${CYAN}📌 Target Release: Pastry v${MARKETING_VERSION} (Build ${BUILD_NUMBER})${NC}"

# ── 2. Validate Bundle Identifier ─────────────────────────────
BUNDLE_ID=$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST_SRC" 2>/dev/null || grep -A1 "CFBundleIdentifier" "$INFO_PLIST_SRC" | tail -n1 | sed -E 's/.*<string>(.*)<\/string>.*/\1/' | tr -d ' \t')
if [ "$BUNDLE_ID" != "com.balajee.Pastry" ]; then
    echo -e "${RED}✘  Invalid bundle identifier: '$BUNDLE_ID' (expected 'com.balajee.Pastry')${NC}"
    exit 1
fi

# ── 3. Validate Entitlements File ─────────────────────────────
if [ ! -f "$ENTITLEMENTS" ]; then
    echo -e "${RED}✘  Missing entitlements file at $ENTITLEMENTS${NC}"
    exit 1
fi

# ── 4. Validate Git Working Tree ─────────────────────────────
if [ "$SKIP_GIT_CHECK" = false ]; then
    if [ -d "$PROJECT_DIR/.git" ]; then
        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            echo -e "${RED}✘  Git working tree contains uncommitted changes.${NC}"
            echo -e "   Commit or stash changes before releasing, or pass ${CYAN}--skip-git-check${NC}."
            exit 1
        fi
        echo -e "${GREEN}✅ Git working tree clean.${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Skipping Git working tree check (--skip-git-check).${NC}"
fi

# ── 5. REQUIRE Developer ID Application Certificate ───────────
echo -e "${CYAN}🔑 Checking Developer ID Application certificate…${NC}"
DEV_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)

if [ -z "$DEV_ID" ]; then
    echo -e "\n${RED}${BOLD}Developer ID Application certificate is required for public release.${NC}"
    echo -e "${YELLOW}Pastry Dev certificate is for local development only and cannot be used for public releases.${NC}"
    echo -e "To configure Apple Developer ID:"
    echo -e "  1. Join Apple Developer Program (https://developer.apple.com)"
    echo -e "  2. Download & install 'Developer ID Application' certificate into Mac Keychain"
    echo -e "  3. Re-run ./release.sh\n"
    echo -e "For local testing without Developer ID, use:"
    echo -e "  ${CYAN}./build.sh${NC}        (creates local release build/Pastry.app)"
    echo -e "  ${CYAN}./package-dmg.sh${NC}  (creates local testing build/Pastry.dmg)\n"
    exit 1
fi

echo -e "${GREEN}✅ Found Developer ID Application: '${DEV_ID}'${NC}"

# ── 6. Clean Build Directory ──────────────────────────────────
echo -e "${CYAN}🧹 Cleaning release build artifacts…${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# ── 7. Compile Release Binary ─────────────────────────────────
echo -e "${CYAN}🔨 Compiling release binary (optimized -O)…${NC}"
xcrun swiftc \
    -swift-version 5 \
    -O \
    -o "$MACOS_DIR/Pastry" \
    $(find "$PROJECT_DIR/Pastry" "$PROJECT_DIR/PastryApp" -name "*.swift")

# ── 8. Inject Metadata into Info.plist ───────────────────────
cp "$INFO_PLIST_SRC" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$MARKETING_VERSION" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"

if [ -f "$PROJECT_DIR/Pastry/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Pastry/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# ── 9. Code Sign with Developer ID & Hardened Runtime ─────────
echo -e "${CYAN}🔑 Signing Pastry.app with Developer ID Application + Hardened Runtime…${NC}"
codesign -s "$DEV_ID" \
    --force \
    --deep \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    "$APP_BUNDLE"

# ── 10. Strict Code Signature Verification ────────────────────
echo -e "${CYAN}🔍 Performing strict signature verification…${NC}"
codesign --verify --deep --strict --verbose "$APP_BUNDLE"
codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1 | grep -E "Authority|Identifier|TeamIdentifier|Sealed Resources"

# Confirm signature authority is Developer ID
if ! codesign -dv "$APP_BUNDLE" 2>&1 | grep -q "Developer ID Application"; then
    echo -e "${RED}✘  Signing verification failed: Certificate is not Developer ID Application.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Code signature verified strictly.${NC}"

# ── 11. Package DMG ───────────────────────────────────────────
"$SCRIPT_DIR/package-dmg.sh"

echo -e "${CYAN}🔑 Signing Pastry.dmg container with Developer ID…${NC}"
codesign -s "$DEV_ID" "$DMG_FILE"

# ── 12. Apple Notarization & Stapling ─────────────────────────
echo -e "\n${CYAN}🌐 Submitting to Apple Notary Service (xcrun notarytool)…${NC}"

NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-AC_PASSWORD}"

if ! xcrun notarytool history --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" >/dev/null 2>&1; then
    echo -e "\n${RED}${BOLD}Notarization credentials profile '$NOTARY_KEYCHAIN_PROFILE' not found in Keychain.${NC}"
    echo -e "To configure notarytool credentials:"
    echo -e "  ${CYAN}xcrun notarytool store-credentials \"$NOTARY_KEYCHAIN_PROFILE\" --apple-id \"your-apple-id@example.com\" --team-id \"YOUR_TEAM_ID\"${NC}\n"
    exit 1
fi

xcrun notarytool submit "$DMG_FILE" \
    --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
    --wait

echo -e "${CYAN}📎 Stapling notarization ticket to DMG & App…${NC}"
xcrun stapler staple "$DMG_FILE"
xcrun stapler staple "$APP_BUNDLE"

echo -e "${CYAN}🔍 Assessing Gatekeeper notarization status…${NC}"
spctl --assess --type open --context context:primary-signature --verbose "$DMG_FILE"

# ── 13. Final Success Output ──────────────────────────────────
echo -e "\n${GREEN}${BOLD}🎉 Public Release Package Successfully Created & Notarized!${NC}"
echo -e "   File: ${BOLD}$DMG_FILE${NC}"
echo -e "   Size: $(du -h "$DMG_FILE" | cut -f1)"
echo -e "   Version: v${MARKETING_VERSION} (Build ${BUILD_NUMBER})\n"
