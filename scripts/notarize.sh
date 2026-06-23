#!/usr/bin/env bash
# scripts/notarize.sh
#
# Submit a built DMG to Apple's notarization service and staple the result.
#
# Requires:
#   - Apple Developer ID Team
#   - Xcode 13+ (for `xcrun notarytool`)
#   - One of the following auth methods stored as env vars / keychain entries:
#       Option A (env-based):  APPLE_ID + APPLE_APP_PASSWORD + APPLE_TEAM_ID
#       Option B (keychain):   NOTARYTOOL_KEYCHAIN_PROFILE
#
# Input:   first positional arg = path to .dmg
# Output:  same .dmg, with notarization ticket stapled (works offline now).
#
# Usage:   ./scripts/notarize.sh dist/Lumina-Music-0.1.1.dmg

set -euo pipefail

DMG="${1:-}"
if [[ -z "$DMG" || ! -f "$DMG" ]]; then
  echo "Usage: $0 <path-to.dmg>"
  exit 1
fi

cd "$(dirname "$0")/.."

# ── Auth: keychain profile preferred, env-based fallback ───────────────────
NOTARYTOOL_AUTH=()
if [[ -n "${NOTARYTOOL_KEYCHAIN_PROFILE:-}" ]]; then
  NOTARYTOOL_AUTH+=(--keychain-profile "$NOTARYTOOL_KEYCHAIN_PROFILE")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  NOTARYTOOL_AUTH+=(
    --apple-id "$APPLE_ID"
    --team-id "$APPLE_TEAM_ID"
    --password "$APPLE_APP_PASSWORD"
  )
else
  echo "ERROR: missing notarization credentials"
  echo ""
  echo "  Option A:  export NOTARYTOOL_KEYCHAIN_PROFILE=<profile name>"
  echo "    set up with:"
  echo "    xcrun notarytool store-credentials <profile> \\"
  echo "        --apple-id <you@example.com> \\"
  echo "        --team-id <TEAMID> \\"
  echo "        --password <app-specific password>"
  echo ""
  echo "  Option B:  export APPLE_ID APPLE_APP_PASSWORD APPLE_TEAM_ID"
  exit 1
fi

echo "─── Notarizing $DMG ───"

# ── Submit + wait ──────────────────────────────────────────────────────────
LOG_JSON="$(mktemp).json"
set +e
xcrun notarytool submit "$DMG" \
    "${NOTARYTOOL_AUTH[@]}" \
    --wait \
    --output-format json \
    > "$LOG_JSON"
SUB_RC=$?
set -e

cat "$LOG_JSON"

if [[ $SUB_RC -ne 0 ]]; then
  echo "ERROR: notarytool submit failed (rc=$SUB_RC)"
  exit $SUB_RC
fi

STATUS="$(python3 -c "import json,sys; print(json.load(open('$LOG_JSON')).get('status',''))")"
SUB_ID="$(python3 -c "import json,sys; print(json.load(open('$LOG_JSON')).get('id',''))")"

if [[ "$STATUS" != "Accepted" ]]; then
  echo ""
  echo "ERROR: notarization not Accepted (status=$STATUS)"
  echo "Fetching full log..."
  xcrun notarytool log "$SUB_ID" "${NOTARYTOOL_AUTH[@]}" || true
  exit 1
fi

# ── Staple the ticket so the DMG works offline ─────────────────────────────
echo ""
echo "─── Stapling ticket ───"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo ""
echo "✓ Notarized + stapled: $DMG"
