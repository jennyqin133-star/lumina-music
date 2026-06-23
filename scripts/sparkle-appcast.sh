#!/usr/bin/env bash
# scripts/sparkle-appcast.sh
#
# Update appcast.xml in the gh-pages/ branch with the latest release DMGs.
#
# Sparkle ships a `generate_appcast` tool inside its release zip; we extract
# it on first use into ~/.cache/lumina/.
#
# Required env:
#   SPARKLE_PRIV_KEY     — base64-encoded EdDSA private key (one line)
#                          generate once with `sign_update --generate-keys`
#                          (companion tool of generate_appcast)
#
# Input:   dist/  (directory of recent DMGs)
# Output:  gh-pages/appcast.xml (overwritten)
#
# Usage:   ./scripts/sparkle-appcast.sh

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -z "${SPARKLE_PRIV_KEY:-}" ]]; then
  if [[ -f ~/.config/lumina/sparkle_ed_priv_key ]]; then
    SPARKLE_PRIV_KEY="$(cat ~/.config/lumina/sparkle_ed_priv_key)"
  else
    echo "ERROR: no SPARKLE_PRIV_KEY env var and ~/.config/lumina/sparkle_ed_priv_key missing"
    echo ""
    echo "  Generate keys once:"
    echo "    ./scripts/sparkle-tools.sh generate-keys"
    echo "  → public key goes into Resources/Info.plist (SUPublicEDKey via build-app.sh)"
    echo "  → private key stays in ~/.config/lumina/sparkle_ed_priv_key (chmod 600)"
    echo "  →                  + GitHub Actions secret SPARKLE_PRIV_KEY"
    exit 1
  fi
fi

if [[ ! -d dist ]] || ! ls dist/*.dmg >/dev/null 2>&1; then
  echo "ERROR: no DMGs in dist/ — run build-app.sh + package-dmg.sh first"
  exit 1
fi

# Locate generate_appcast from the Sparkle SwiftPM artifact bundle.
SPARKLE_BIN_DIR="$(find .build -type d -path '*/Sparkle-*/bin' 2>/dev/null | head -1)"
if [[ -z "$SPARKLE_BIN_DIR" ]]; then
  # Newer SwiftPM layout: artifacts under .build/artifacts/sparkle-project/
  SPARKLE_BIN_DIR="$(find .build -type f -name generate_appcast -print -quit 2>/dev/null | xargs -I{} dirname {} 2>/dev/null)"
fi
if [[ -z "$SPARKLE_BIN_DIR" || ! -x "$SPARKLE_BIN_DIR/generate_appcast" ]]; then
  echo "ERROR: generate_appcast not found in .build/"
  echo "  Try: swift build -c release    (then re-run this script)"
  exit 1
fi

# Stash the private key into a temp file generate_appcast can read.
KEYFILE="$(mktemp)"
trap 'rm -f "$KEYFILE"' EXIT
echo "$SPARKLE_PRIV_KEY" > "$KEYFILE"

GH_PAGES_DIR="gh-pages-checkout"
mkdir -p "$GH_PAGES_DIR"

FEED_URL="${SUFEEDURL_OVERRIDE:-https://jennyqin133-star.github.io/lumina-music/appcast.xml}"
DL_BASE_URL="${SPARKLE_DOWNLOAD_BASE_URL:-https://github.com/USER/lumina-music/releases/download}"

# generate_appcast expects a directory containing the .dmg(s) (and optional
# release notes <version>.html files). It writes appcast.xml in-place.
cp dist/*.dmg "$GH_PAGES_DIR/"
"$SPARKLE_BIN_DIR/generate_appcast" \
    --ed-key-file "$KEYFILE" \
    --download-url-prefix "$DL_BASE_URL/" \
    --link "$FEED_URL" \
    "$GH_PAGES_DIR"

ls -la "$GH_PAGES_DIR/appcast.xml"
echo ""
echo "✓ appcast.xml updated in $GH_PAGES_DIR/"
echo "  next: commit + push to gh-pages branch (CI does this)"
