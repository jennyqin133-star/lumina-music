#!/usr/bin/env bash
# scripts/build-app.sh
#
# Build & bundle Lumina Music.app for distribution.
#
# Flow:
#   1. SwiftPM release build
#   2. Construct .app bundle structure
#   3. Copy executable + Sparkle.framework + Info.plist + AppIcon + privacy
#   4. Inject Sparkle public EdDSA key into Info.plist (if available)
#   5. Codesign with Developer ID or ad-hoc (fallback)
#
# Environment overrides:
#   DEVELOPER_ID         = "Developer ID Application: <name> (TEAMID)"
#                          → if unset, falls back to ad-hoc signing
#   SPARKLE_PUBLIC_KEY   = base64 EdDSA public key (Info.plist SUPublicEDKey)
#                          → if unset, the Info.plist key is left at "TBD"
#   SUFEEDURL_OVERRIDE   = override SUFeedURL (default: https://USER.github.io/...)
#
# Usage:  ./scripts/build-app.sh

set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Lumina Music"
EXE_NAME="LuminaMusic"
BUNDLE_DIR="dist/${APP_NAME}.app"
CONTENTS="${BUNDLE_DIR}/Contents"

echo "─── Lumina Music · build-app ───"

# ── 0. Pre-flight ─────────────────────────────────────────────────────────
if [[ ! -f Resources/AppIcon.icns ]]; then
  echo "  → no AppIcon.icns; generating..."
  scripts/make-icon.sh
fi

# ── 1. SwiftPM build ──────────────────────────────────────────────────────
echo ""
echo "─── swift build -c release ───"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)"
EXE_SRC="${BIN_PATH}/${EXE_NAME}"
SPARKLE_FW_SRC="${BIN_PATH}/Sparkle.framework"

if [[ ! -f "$EXE_SRC" ]]; then
  echo "ERROR: executable not at $EXE_SRC"
  exit 1
fi
if [[ ! -d "$SPARKLE_FW_SRC" ]]; then
  echo "ERROR: Sparkle.framework not at $SPARKLE_FW_SRC"
  exit 1
fi

# ── 2. Construct .app bundle ──────────────────────────────────────────────
echo ""
echo "─── bundling ───"
rm -rf "$BUNDLE_DIR"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources" "${CONTENTS}/Frameworks"

cp "$EXE_SRC" "${CONTENTS}/MacOS/${EXE_NAME}"
chmod +x "${CONTENTS}/MacOS/${EXE_NAME}"

# Inject @executable_path/../Frameworks rpath so dyld can find Sparkle.framework
# (SwiftPM's release build does not set this rpath by default for executable targets).
install_name_tool -add_rpath "@executable_path/../Frameworks" "${CONTENTS}/MacOS/${EXE_NAME}" 2>/dev/null || true

cp -R "$SPARKLE_FW_SRC" "${CONTENTS}/Frameworks/"

cp Resources/AppIcon.icns "${CONTENTS}/Resources/AppIcon.icns"
cp Resources/PrivacyInfo.xcprivacy "${CONTENTS}/Resources/PrivacyInfo.xcprivacy"

cp Resources/Info.plist "${CONTENTS}/Info.plist"

# ── 3. Inject Sparkle config into Info.plist ──────────────────────────────
if [[ -n "${SPARKLE_PUBLIC_KEY:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string ${SPARKLE_PUBLIC_KEY}" \
    "${CONTENTS}/Info.plist" 2>/dev/null \
  || /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey ${SPARKLE_PUBLIC_KEY}" \
    "${CONTENTS}/Info.plist"
  echo "  injected SUPublicEDKey"
fi
if [[ -n "${SUFEEDURL_OVERRIDE:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :SUFeedURL ${SUFEEDURL_OVERRIDE}" \
    "${CONTENTS}/Info.plist"
  echo "  set SUFeedURL → ${SUFEEDURL_OVERRIDE}"
fi

# ── 4. Codesign ───────────────────────────────────────────────────────────
echo ""
if [[ -n "${DEVELOPER_ID:-}" ]]; then
  echo "─── codesign (Developer ID: ${DEVELOPER_ID}) ───"
  # Sign frameworks first (deep order matters for hardened runtime)
  codesign --force --options=runtime --timestamp \
    --sign "$DEVELOPER_ID" \
    "${CONTENTS}/Frameworks/Sparkle.framework/Versions/B/Autoupdate" 2>/dev/null \
    || codesign --force --options=runtime --timestamp --sign "$DEVELOPER_ID" \
       "${CONTENTS}/Frameworks/Sparkle.framework/Autoupdate" 2>/dev/null \
    || true
  codesign --force --options=runtime --timestamp \
    --sign "$DEVELOPER_ID" \
    "${CONTENTS}/Frameworks/Sparkle.framework/Versions/B/Updater.app" 2>/dev/null \
    || codesign --force --options=runtime --timestamp --sign "$DEVELOPER_ID" \
       "${CONTENTS}/Frameworks/Sparkle.framework/Updater.app" 2>/dev/null \
    || true

  codesign --force --options=runtime --timestamp \
    --sign "$DEVELOPER_ID" \
    "${CONTENTS}/Frameworks/Sparkle.framework"

  codesign --force --options=runtime --timestamp \
    --entitlements Resources/Entitlements.plist \
    --sign "$DEVELOPER_ID" \
    "${BUNDLE_DIR}"
else
  echo "─── codesign (ad-hoc, unsigned for distribution) ───"
  echo "  Note: users will need to right-click → Open on first launch."
  codesign --force --deep --sign - "${BUNDLE_DIR}"
fi

# ── 5. Verify ─────────────────────────────────────────────────────────────
echo ""
echo "─── verifying ───"
codesign --verify --deep --strict --verbose=2 "${BUNDLE_DIR}" 2>&1 | tail -5
echo ""

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${CONTENTS}/Info.plist")"
echo "✓ Built: ${BUNDLE_DIR} (v${VERSION})"
echo ""
echo "  open \"${BUNDLE_DIR}\""
