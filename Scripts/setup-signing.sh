#!/bin/bash
# ──────────────────────────────────────────────────────────────
# Scripts/setup-signing.sh — Create a persistent self-signed
# code-signing certificate for Pastry development.
#
# This certificate lives in your login keychain and gives every
# dev build a STABLE identity so macOS TCC (Accessibility)
# remembers permissions across rebuilds.
#
# Run this ONCE. Safe to re-run (skips if cert exists).
# ──────────────────────────────────────────────────────────────
set -euo pipefail

CERT_NAME="Pastry Dev"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if security find-identity -v -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
    echo -e "${GREEN}✅ Certificate '$CERT_NAME' already exists.${NC}"
    echo -e "   No action needed."
    exit 0
fi

echo -e "${CYAN}🔐 Creating self-signed code-signing certificate: '$CERT_NAME'${NC}"
echo -e "${YELLOW}   You may see a Keychain Access prompt — enter your Mac login password.${NC}"
echo ""

TMPDIR_CERT=$(mktemp -d)

# Generate key + self-signed cert (valid 10 years)
openssl req -x509 -newkey rsa:2048 \
    -keyout "$TMPDIR_CERT/key.pem" \
    -out "$TMPDIR_CERT/cert.pem" \
    -days 3650 \
    -nodes \
    -subj "/CN=$CERT_NAME" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" \
    -addext "basicConstraints=critical,CA:false" \
    2>/dev/null

# Convert to p12 — use -legacy for OpenSSL 3.x / macOS compatibility
openssl pkcs12 -export \
    -legacy \
    -inkey "$TMPDIR_CERT/key.pem" \
    -in "$TMPDIR_CERT/cert.pem" \
    -out "$TMPDIR_CERT/cert.p12" \
    -passout pass:pastrydev \
    2>/dev/null

# Import into login keychain
security import "$TMPDIR_CERT/cert.p12" \
    -k ~/Library/Keychains/login.keychain-db \
    -P "pastrydev" \
    -T /usr/bin/codesign

# Trust for code signing
security add-trusted-cert -d -r trustRoot \
    -p codeSign \
    -k ~/Library/Keychains/login.keychain-db \
    "$TMPDIR_CERT/cert.pem" 2>/dev/null || true

# Clean up temp files
rm -rf "$TMPDIR_CERT"

echo ""
if security find-identity -v -p codesigning 2>/dev/null | grep -q "$CERT_NAME"; then
    echo -e "${GREEN}✅ Certificate '$CERT_NAME' created successfully.${NC}"
    echo -e "   All ./dev.sh builds will now use this identity."
    echo -e "   TCC permissions (Accessibility) will persist across rebuilds."
else
    echo -e "${RED}✘  Certificate not found after import.${NC}"
    echo -e "   Open Keychain Access.app → login → My Certificates to debug."
    exit 1
fi
