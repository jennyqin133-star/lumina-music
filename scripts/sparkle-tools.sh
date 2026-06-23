#!/usr/bin/env bash
# scripts/sparkle-tools.sh
#
# Wrapper that exposes Sparkle's standalone tools (generate_keys, sign_update,
# generate_appcast) after `swift build` has fetched the Sparkle SwiftPM artifact.
#
# Usage:
#   ./scripts/sparkle-tools.sh generate-keys
#       → writes EdDSA keypair, stores private in ~/.config/lumina/, prints public.
#
#   ./scripts/sparkle-tools.sh sign <file>
#       → prints signature of the file using ~/.config/lumina/sparkle_ed_priv_key

set -euo pipefail

cd "$(dirname "$0")/.."

CMD="${1:-help}"
shift || true

# Find Sparkle bin dir.
SPARKLE_BIN_DIR="$(find .build -type f -name generate_appcast -print -quit 2>/dev/null | xargs -I{} dirname {} 2>/dev/null)"
if [[ -z "$SPARKLE_BIN_DIR" ]]; then
  echo "Sparkle tools not yet downloaded — running swift build to fetch..."
  swift build -c release >/dev/null
  SPARKLE_BIN_DIR="$(find .build -type f -name generate_appcast -print -quit 2>/dev/null | xargs -I{} dirname {} 2>/dev/null)"
fi
if [[ -z "$SPARKLE_BIN_DIR" ]]; then
  echo "ERROR: Sparkle tools still not found"; exit 1
fi

case "$CMD" in
  generate-keys)
    mkdir -p ~/.config/lumina
    chmod 700 ~/.config/lumina
    KEYFILE=~/.config/lumina/sparkle_ed_priv_key
    if [[ -f "$KEYFILE" ]]; then
      echo "⚠ $KEYFILE already exists — refusing to overwrite."
      echo "  Public key (from existing private key):"
      "$SPARKLE_BIN_DIR/sign_update" -p "$KEYFILE" 2>/dev/null || \
      "$SPARKLE_BIN_DIR/generate_keys" -p "$KEYFILE" 2>/dev/null || \
      echo "  (cannot derive — newer Sparkle stores public key separately)"
      exit 0
    fi
    "$SPARKLE_BIN_DIR/generate_keys" -f "$KEYFILE" 2>&1
    chmod 600 "$KEYFILE"
    echo ""
    echo "✓ Private key stored in $KEYFILE (chmod 600)"
    echo ""
    echo "  → Copy the public key printed above (starts with \"Public key:\")"
    echo "  → Set SPARKLE_PUBLIC_KEY=<that base64 string> when running build-app.sh"
    echo "  → Also add it as a GitHub Actions secret: SPARKLE_PUBLIC_KEY"
    echo "  → Add the private key (single line, base64) as: SPARKLE_PRIV_KEY"
    ;;

  sign)
    FILE="${1:-}"
    [[ -f "$FILE" ]] || { echo "Usage: $0 sign <file>"; exit 1; }
    KEYFILE=~/.config/lumina/sparkle_ed_priv_key
    [[ -f "$KEYFILE" ]] || { echo "Run: $0 generate-keys"; exit 1; }
    "$SPARKLE_BIN_DIR/sign_update" -f "$KEYFILE" "$FILE"
    ;;

  help|*)
    cat <<USAGE
sparkle-tools.sh — Wrapper around Sparkle's bundled binaries.

Subcommands:
  generate-keys    Create EdDSA keypair (one-time setup for releases)
  sign <file>      Sign a file with the stored private key

Note: regular release flow (sign every DMG + emit appcast.xml) is handled
by scripts/sparkle-appcast.sh, not by direct sign_update calls.
USAGE
    ;;
esac
