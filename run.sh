#!/bin/bash
# ──────────────────────────────────────────────────────────────
# run.sh — Launch the built Pastry.app
#
# Kills any existing instance first, then launches the .app
# from build/. Works with both dev and release builds.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_BUNDLE="$PROJECT_DIR/build/Pastry.app"
BINARY="$APP_BUNDLE/Contents/MacOS/Pastry"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ ! -f "$BINARY" ]; then
    echo -e "${RED}✘  No build found at $APP_BUNDLE${NC}"
    echo -e "   Run ${CYAN}./dev.sh${NC} or ${CYAN}./build.sh${NC} first."
    exit 1
fi

# Kill existing instance
if pgrep -f "Pastry.app/Contents/MacOS/Pastry" > /dev/null 2>&1; then
    echo -e "${YELLOW}⏹  Stopping running Pastry…${NC}"
    pkill -f "Pastry.app/Contents/MacOS/Pastry" 2>/dev/null || true
    sleep 0.3
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
