#!/bin/bash
# ──────────────────────────────────────────────────────────────
# dev.sh — Fast edit → build → run cycle for Pastry development
#
# Usage:  ./dev.sh          Build debug + launch
#         ./dev.sh build    Build debug only (no launch)
#         ./dev.sh run      Launch existing build (no compile)
# ──────────────────────────────────────────────────────────────
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/Pastry.app"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
BINARY="$MACOS_DIR/Pastry"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Kill any running Pastry instance ──────────────────────────
kill_pastry() {
    if pgrep -f "Pastry.app/Contents/MacOS/Pastry" > /dev/null 2>&1; then
        echo -e "${YELLOW}⏹  Stopping running Pastry…${NC}"
        pkill -f "Pastry.app/Contents/MacOS/Pastry" 2>/dev/null || true
        sleep 0.3
    fi
}

# ── Build (debug, no optimization) ───────────────────────────
build_debug() {
    echo -e "${CYAN}🔨 Building Pastry (debug)…${NC}"
    local start_time=$(date +%s)

    # Create bundle structure (only if missing)
    mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

    # Compile — debug mode (no -O), faster builds
    xcrun swiftc \
        -swift-version 5 \
        -g \
        -Onone \
        -o "$BINARY" \
        $(find "$PROJECT_DIR/Pastry" "$PROJECT_DIR/PastryApp" -name "*.swift")

    # Copy resources only if they've changed
    cp -u "$PROJECT_DIR/Pastry/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null \
        || cp "$PROJECT_DIR/Pastry/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

    if [ -f "$PROJECT_DIR/Pastry/Resources/AppIcon.icns" ]; then
        cp -u "$PROJECT_DIR/Pastry/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null \
            || cp "$PROJECT_DIR/Pastry/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    fi

    # Code sign — use persistent "Pastry Dev" cert so TCC permissions survive rebuilds.
    # Falls back to ad-hoc if the cert hasn't been set up yet (run ./setup-signing.sh).
    if security find-identity -v -p codesigning 2>/dev/null | grep -q "Pastry Dev"; then
        codesign -s "Pastry Dev" --force --deep "$APP_BUNDLE" 2>/dev/null
    else
        echo -e "${YELLOW}⚠  No 'Pastry Dev' certificate found — using ad-hoc signing.${NC}"
        echo -e "   Run ${CYAN}./setup-signing.sh${NC} once to preserve Accessibility permissions across rebuilds."
        codesign -s - --force --deep "$APP_BUNDLE" 2>/dev/null
    fi

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    echo -e "${GREEN}✅ Build succeeded${NC} (${elapsed}s) → ${BOLD}$APP_BUNDLE${NC}"
}

# ── Launch ────────────────────────────────────────────────────
launch_pastry() {
    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}✘  No build found. Run ./dev.sh first.${NC}"
        exit 1
    fi
    echo -e "${CYAN}🚀 Launching Pastry…${NC}"
    open "$APP_BUNDLE"
    sleep 0.5
    if pgrep -f "Pastry.app/Contents/MacOS/Pastry" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Pastry is running${NC} (menu bar)"
    else
        echo -e "${RED}✘  Pastry failed to launch. Check Console.app for crash logs.${NC}"
        exit 1
    fi
}

# ── Main ──────────────────────────────────────────────────────
case "${1:-}" in
    build)
        kill_pastry
        build_debug
        ;;
    run)
        kill_pastry
        launch_pastry
        ;;
    *)
        kill_pastry
        build_debug
        launch_pastry
        ;;
esac
