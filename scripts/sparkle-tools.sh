#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

CMD="${1:-help}"
shift || true

SPARKLE_GEN_KEYS="$(find .build -type f -name generate_keys -print -quit 2>/dev/null)"
if [[ -z "$SPARKLE_GEN_KEYS" ]]; then
  echo "Sparkle tools not yet downloaded — running swift build to fetch..."
  swift build -c release >/dev/null
  SPARKLE_GEN_KEYS="$(find .build -type f -name generate_keys -print -quit 2>/dev/null)"
fi
[[ -n "$SPARKLE_GEN_KEYS" ]] || { echo "ERROR: generate_keys not found"; exit 1; }
SPARKLE_BIN_DIR="$(dirname "$SPARKLE_GEN_KEYS")"

case "$CMD" in
  generate-keys)
    mkdir -p ~/.config/lumina
    chmod 700 ~/.config/lumina
    KEYFILE=~/.config/lumina/sparkle_ed_priv_key

    if [[ -f "$KEYFILE" ]]; then
      echo "⚠ $KEYFILE already exists — skipping."
      "$SPARKLE_BIN_DIR/generate_keys" -p 2>/dev/null || true
      exit 0
    fi

    echo "→ Generating EdDSA key in macOS Keychain (allow the prompt)..."
    "$SPARKLE_BIN_DIR/generate_keys"

    echo ""
    echo "→ Exporting private key to $KEYFILE ..."
    "$SPARKLE_BIN_DIR/generate_keys" -x "$KEYFILE"
    chmod 600 "$KEYFILE"

    echo ""
    echo "→ Public key (capture this):"
    "$SPARKLE_BIN_DIR/generate_keys" -p
    ;;
  sign)
    FILE="${1:-}"
    [[ -f "$FILE" ]] || { echo "Usage: $0 sign <file>"; exit 1; }
    KEYFILE=~/.config/lumina/sparkle_ed_priv_key
    [[ -f "$KEYFILE" ]] || { echo "Run: $0 generate-keys first"; exit 1; }
    "$SPARKLE_BIN_DIR/sign_update" -f "$KEYFILE" "$FILE"
    ;;
  *)
    echo "usage: $0 generate-keys|sign <file>"
    ;;
esac
