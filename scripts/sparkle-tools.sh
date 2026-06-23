#!/usr/bin/env bash
# scripts/sparkle-tools.sh
#
# Wrapper around Sparkle's standalone tools (generate_keys, sign_update).
#
# Sparkle 2.x stores the private signing key in your macOS Keychain by default.
# We additionally export it to ~/.config/lumina/sparkle_ed_priv_key so:
#   - sparkle-appcast.sh can sign DMGs (it expects a key file)
#   - the same key can be uploaded to GitHub Secrets for CI
#
# Subcommands:
#   generate-keys    Generate keypair, store in Keychain + export private to file
#                    + print public key for Info.plist / GitHub Secrets
#   sign <file>      Sign a file with the stored private key

set -euo pipefail

cd "$(dirname "$0")/.."

CMD="${1:-help}"
shift || true

# Find Sparkle bin dir.
SPARKLE_GEN_KEYS="$(find .build -type f -name generate_keys -print -quit 2>/dev/null)"
if [[ -z "$SPARKLE_GEN_KEYS" ]]; then
  echo "Sparkle tools not yet downloaded — running swift build to fetch..."
  swift build -c release >/dev/null
  SPARKLE_GEN_KEYS="$(find .build -type f -name generate_keys -print -quit 2>/dev/null)"
fi
if [[ -z "$SPARKLE_GEN_KEYS" ]]; then
  echo "ERROR: generate_keys still not found"; exit 1
fi
SPARKLE_BIN_DIR="$(dirname "$SPARKLE_GEN_KEYS")"

case "$CMD" in
  generate-keys)
    mkdir -p ~/.config/lumina
    chmod 700 ~/.config/lumina
    KEYFILE=~/.config/lumina/sparkle_ed_priv_key

    if [[ -f "$KEYFILE" ]]; then
      echo "⚠ $KEYFILE already exists — refusing to overwrite."
      echo ""
      echo "Current public key (re-derive):"
      "$SPARKLE_BIN_DIR/generate_keys" -p 2>/dev/null || echo "(could not derive — keychain key may have been deleted)"
      exit 0
    fi

    # Step 1: ensure a keypair exists in the Keychain.
    # The first run with no args generates a fresh keypair into the Keychain;
    # subsequent runs are no-ops and just print the existing public key.
    #
    # The Keychain may pop up an "Always Allow" prompt — click it.
    echo "→ Generating/ensuring Sparkle EdDSA key in macOS Keychain..."
    "$SPARKLE_BIN_DIR/generate_keys" 2>&1 | tee /tmp/sparkle-gen.log

    # Step 2: export the private key from the Keychain to a file
    # so the rest of the release toolchain (and CI secrets) can use it.
    echo ""
    echo "→ Exporting private key from Keychain to $KEYFILE ..."
    "$SPARKLE_BIN_DIR/generate_keys" -x "$KEYFILE"
    chmod 600 "$KEYFILE"

    # Step 3: print the public key cleanly so the wrapping script can capture it.
    echo ""
    echo "→ Public key (use for SPARKLE_PUBLIC_KEY secret + Info.plist SUPublicEDKey):"
    "$SPARKLE_BIN_DIR/generate_keys" -p
    ;;

  sign)
    FILE="${1:-}"
    [[ -f "$FILE" ]] || { echo "Usage: $0 sign <file>"; exit 1; }
    KEYFILE=~/.config/lumina/sparkle_ed_priv_key
    [[ -f "$KEYFILE" ]] || { echo "Run: $0 generate-keys first"; exit 1; }
    "$SPARKLE_BIN_DIR/sign_update" -f "$KEYFILE" "$FILE"
    ;;

  help|*)
    cat <<USAGE
sparkle-tools.sh — Wrapper around Sparkle's bundled binaries.

Subcommands:
  generate-keys    Create EdDSA keypair (Keychain + export to file)
                   One-time setup for releases.
  sign <file>      Sign a file with the stored private key.

Note: routine release flow (sign every DMG + emit appcast.xml) is handled
by scripts/sparkle-appcast.sh, not by direct sign_update calls.
USAGE
    ;;
esac
