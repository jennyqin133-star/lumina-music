#!/usr/bin/env bash
# scripts/package-dmg.sh
#
# Build a distributable DMG containing Lumina Music.app + an Applications symlink.
#
# Requires:  brew install create-dmg
# Input:     dist/Lumina Music.app  (from scripts/build-app.sh)
# Output:    dist/Lumina-Music-<version>.dmg
#
# Environment overrides:
#   DEVELOPER_ID         — if set, the resulting DMG is also codesigned
#                          (notarization happens in scripts/notarize.sh, separately).

set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Lumina Music"
BUNDLE="dist/${APP_NAME}.app"

if [[ ! -d "$BUNDLE" ]]; then
  echo "ERROR: $BUNDLE not found — run scripts/build-app.sh first"
  exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
  echo "ERROR: create-dmg not installed"
  echo "  brew install create-dmg"
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${BUNDLE}/Contents/Info.plist")"
DMG="dist/Lumina-Music-${VERSION}.dmg"
echo "─── Lumina Music · DMG packaging (v${VERSION}) ───"

# Clean any stale dmg
rm -f "$DMG" "dist/rw.${DMG##*/}"

# create-dmg generates a styled DMG: app icon + symlink to /Applications,
# both at fixed positions with custom layout.
# We pass --no-internet-enable to skip XCode-style automounts.
create-dmg \
    --volname "Lumina Music ${VERSION}" \
    --window-pos 200 120 \
    --window-size 660 420 \
    --icon-size 120 \
    --icon "${APP_NAME}.app" 170 200 \
    --app-drop-link 490 200 \
    --no-internet-enable \
    "$DMG" \
    "$BUNDLE" \
    || true  # create-dmg can return 2 on AppleScript warnings; verify below

if [[ ! -f "$DMG" ]]; then
  echo "ERROR: DMG was not produced (check create-dmg output above)"
  exit 1
fi

# Codesign the DMG itself if a Developer ID is available.
if [[ -n "${DEVELOPER_ID:-}" ]]; then
  echo "  codesign DMG with: ${DEVELOPER_ID}"
  codesign --force --sign "$DEVELOPER_ID" "$DMG"
fi

size_mb="$(du -m "$DMG" | cut -f1)"
echo ""
echo "✓ Built: $DMG (${size_mb} MB)"
