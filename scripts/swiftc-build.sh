#!/usr/bin/env bash
# Build Lumina Music.app — no Xcode IDE required, swiftc direct compile.
# Based on user.md technique from NCMFLACConverter (2026-06-17).

set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Lumina Music"
EXE_NAME="LuminaMusic"
BUNDLE="build/${APP_NAME}.app"
MIN_OS="13.0"

echo "─── Lumina Music · build ───"

# Clean
rm -rf "build"
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"

# Collect Swift sources
SRC=$(find Sources -name "*.swift" | sort)

echo "  sources:"
echo "${SRC}" | sed 's|^|    |'

# Detect SDK
SDK=$(xcrun --sdk macosx --show-sdk-path)
ARCH=$(uname -m)
TARGET="${ARCH}-apple-macosx${MIN_OS}"

echo "  target: ${TARGET}"
echo "  sdk:    ${SDK}"
echo ""
echo "─── compiling ───"

# Compile
xcrun swiftc \
  -target "${TARGET}" \
  -sdk "${SDK}" \
  -O \
  -parse-as-library \
  -o "${BUNDLE}/Contents/MacOS/${EXE_NAME}" \
  ${SRC} \
  -framework SwiftUI \
  -framework AppKit \
  -framework Combine

# Plist
cp Resources/Info.plist "${BUNDLE}/Contents/Info.plist"

# Permissions
chmod +x "${BUNDLE}/Contents/MacOS/${EXE_NAME}"

echo ""
echo "✓ Built: ${BUNDLE}"
echo ""
echo "─── launching ───"
echo "  open \"${BUNDLE}\""
