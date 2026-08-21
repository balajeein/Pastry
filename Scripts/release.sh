#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Scripts/release.sh — Production Release Pipeline for Pastry
#
# Complete release workflow:
# 1. Validates Git working tree clean state (pass --skip-git-check to bypass)
# 2. Reads VERSION file (MARKETING_VERSION and BUILD_NUMBER)
# 3. Performs clean optimized release build
# 4. Injects version metadata into Info.plist
# 5. Signs with "Developer ID Application" + Hardened Runtime + Entitlements
#    (or falls back to local signing if Developer ID is not configured)
# 6. Verifies code signing strictly
# 7. Packages build/Pastry.dmg
# 8. Submits to Apple Notary Service via xcrun notarytool (if credentials configured)
# 9. Staples notarization ticket to DMG
# 10. Outputs final distribution artifact: build/Pastry.dmg
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

echo -e "${CYAN}${BOLD}🚀 Starting Pastry Production Release Workflow${NC}\n"

# ── 1. Validate Git Working Tree ─────────────────────────────
if [ "$SKIP_GIT_CHECK" = false ]; then
    if [ -d "$PROJECT_DIR/.git" ]; then
        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            echo -e "${RED}✘  Git working tree contains uncommitted changes.${NC}"
            echo -e "   Please commit or stash changes before releasing, or pass ${CYAN}--skip-git-check${NC}."
            exit 1
        fi
        echo -e "${GREEN}✅ Git working tree is clean.${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Skipping Git working tree check (--skip-git-check).${NC}"
fi

# ── 2. Read Version Source of Truth ───────────────────────────
VERSION_FILE="$PROJECT_DIR/VERSION"
MARKETING_VERSION="1.0.0"
BUILD_NUMBER="1"

if [ -f "$VERSION_FILE" ]; then
    source "$VERSION_FILE" 2>/dev/null || true
fi

echo -e "${CYAN}📌 Target Release: Pastry v${MARKETING_VERSION} (Build ${BUILD_NUMBER})${NC}"

# ── 3. Clean & Build Optimized Binary ─────────────────────────
echo -e "${CYAN}🔨 Compiling release binary…${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

xcrun swiftc \
    -swift-version 5 \
    -O \
    -o "$MACOS_DIR/Pastry" \
    $(find "$PROJECT_DIR/Pastry" "$PROJECT_DIR/PastryApp" -name "*.swift")

# ── 4. Inject Metadata into Info.plist ───────────────────────
cp "$PROJECT_DIR/Pastry/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleShortVersionString -string "$MARKETING_VERSION" "$APP_BUNDLE/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APP_BUNDLE/Contents/Info.plist"

if [ -f "$PROJECT_DIR/Pastry/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Pastry/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# ── 5. Code Signing (Developer ID vs Local) ───────────────────
DEV_ID=$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/' || true)

IS_DEVELOPER_ID=false
if [ -n "$DEV_ID" ]; then
    IS_DEVELOPER_ID=true
    echo -e "${CYAN}🔑 Signing with Developer ID: '${DEV_ID}' (Hardened Runtime enabled)…${NC}"
    codesign -s "$DEV_ID" \
        --force \
        --deep \
        --options runtime \
        --entitlements "$ENTITLEMENTS" \
        "$APP_BUNDLE"
else
    echo -e "${YELLOW}⚠️  Developer ID Application certificate NOT found in Keychain.${NC}"
    echo -e "   Falling back to local 'Pastry Dev' signing for testing build."
    if security find-identity -v -p codesigning 2>/dev/null | grep -q "Pastry Dev"; then
        codesign -s "Pastry Dev" --force --deep "$APP_BUNDLE" 2>/dev/null
    else
        codesign -s - --force --deep "$APP_BUNDLE" 2>/dev/null
    fi
fi

# ── 6. Verify Code Signature ──────────────────────────────────
echo -e "${CYAN}🔍 Verifying code signature…${NC}"
codesign --verify --deep --strict "$APP_BUNDLE"
echo -e "${GREEN}✅ Code signature verified.${NC}"

# ── 7. Package DMG ────────────────────────────────────────────
"$SCRIPT_DIR/package-dmg.sh"

# If signed with Developer ID, also sign the DMG container
if [ "$IS_DEVELOPER_ID" = true ]; then
    echo -e "${CYAN}🔑 Signing DMG with Developer ID…${NC}"
    codesign -s "$DEV_ID" "$DMG_FILE"
fi

# ── 8. Notarization & Stapling ────────────────────────────────
echo -e "\n${CYAN}🌐 Checking Apple Notarization Setup…${NC}"

NOTARY_KEYCHAIN_PROFILE="${NOTARY_KEYCHAIN_PROFILE:-AC_PASSWORD}"
HAS_NOTARY_CREDS=false

if xcrun notarytool history --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" >/dev/null 2>&1; then
    HAS_NOTARY_CREDS=true
fi

if [ "$IS_DEVELOPER_ID" = true ] && [ "$HAS_NOTARY_CREDS" = true ]; then
    echo -e "${CYAN}📤 Submitting $DMG_FILE to Apple Notary Service…${NC}"
    xcrun notarytool submit "$DMG_FILE" \
        --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" \
        --wait

    echo -e "${CYAN}📎 Stapling notarization ticket…${NC}"
    xcrun stapler staple "$DMG_FILE"
    xcrun stapler staple "$APP_BUNDLE"
    echo -e "${GREEN}✅ Notarization and stapling complete!${NC}"
else
    echo -e "${YELLOW}ℹ️  Apple Notarization skipped.${NC}"
    if [ "$IS_DEVELOPER_ID" = false ]; then
        echo -e "   Reason: No 'Developer ID Application' certificate installed."
    elif [ "$HAS_NOTARY_CREDS" = false ]; then
        echo -e "   Reason: Keychain profile '$NOTARY_KEYCHAIN_PROFILE' not configured."
        echo -e "   To enable Notarization:"
        echo -e "     1. Obtain Apple Developer Program membership"
        echo -e "     2. Store credentials in Keychain:"
        echo -e "        ${CYAN}xcrun notarytool store-credentials \"$NOTARY_KEYCHAIN_PROFILE\" --apple-id \"user@example.com\" --team-id \"TEAMID\"${NC}"
    fi
fi

# ── 9. Final Verification & Output ────────────────────────────
echo -e "\n${GREEN}${BOLD}🎉 Release Package Ready!${NC}"
echo -e "   File: ${BOLD}$DMG_FILE${NC}"
echo -e "   Size: $(du -h "$DMG_FILE" | cut -f1)"
echo -e "   Version: v${MARKETING_VERSION} (Build ${BUILD_NUMBER})\n"
