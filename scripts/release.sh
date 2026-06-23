#!/usr/bin/env bash
# scripts/release.sh
#
# One-shot release driver: bumps version, commits, tags, pushes.
# The actual build/sign/notarize/publish happens in GitHub Actions
# (.github/workflows/release.yml) when it sees the new tag.
#
# Usage:  ./scripts/release.sh v0.1.1
#         ./scripts/release.sh v0.1.1 "Notes about this release"

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION_TAG="${1:-}"
NOTES="${2:-}"

if [[ -z "$VERSION_TAG" ]]; then
  echo "Usage: $0 v<version> [\"release notes\"]"
  echo "Example: $0 v0.1.1 \"First dry-run distribution build\""
  exit 1
fi

# Strip leading "v" for plist value.
if [[ ! "$VERSION_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  echo "ERROR: tag must look like vX.Y.Z (got '$VERSION_TAG')"
  exit 1
fi
VERSION="${VERSION_TAG#v}"

# ── Preconditions ─────────────────────────────────────────────────────────
if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: working tree is dirty — commit or stash first"
  git status --short
  exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
  echo "ERROR: not on 'main' (currently on '$BRANCH')"
  exit 1
fi

if git rev-parse "$VERSION_TAG" >/dev/null 2>&1; then
  echo "ERROR: tag $VERSION_TAG already exists"
  exit 1
fi

# ── Bump version in Info.plist ────────────────────────────────────────────
PLIST="Resources/Info.plist"
OLD_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")"
OLD_BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")"
NEW_BUILD=$(( OLD_BUILD + 1 ))

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST"

echo "  bumped $OLD_VERSION ($OLD_BUILD)  →  $VERSION ($NEW_BUILD)"

# ── Update CHANGELOG.md ───────────────────────────────────────────────────
TODAY="$(date +%Y-%m-%d)"
NEW_HEADER="## [${VERSION}] - ${TODAY}"


# Insert just after "## [Unreleased]" section block.
python3 - <<PY
import re, pathlib
p = pathlib.Path("CHANGELOG.md")
src = p.read_text()
header = "$NEW_HEADER"
notes = """$NOTES"""
block = header + "\n\n"
if notes:
    block += "### Notes\n- " + notes + "\n\n"
# Insert after the first "## [Unreleased]" subsection.
src = re.sub(
    r"(## \[Unreleased\][\s\S]*?)(\n## \[)",
    r"\1\n" + block + r"\2",
    src, count=1
)
p.write_text(src)
PY

# ── Commit + tag + push ───────────────────────────────────────────────────
git add Resources/Info.plist CHANGELOG.md
git commit -m "release: ${VERSION_TAG}${NOTES:+ — $NOTES}"
git tag -a "$VERSION_TAG" -m "${VERSION_TAG}${NOTES:+ — $NOTES}"

echo ""
echo "Tag created locally."
read -r -p "Push 'main' + '${VERSION_TAG}' to origin now? (CI will build+sign+notarize+publish.) [y/N] " ans
case "$ans" in
  y|Y|yes)
    git push origin main
    git push origin "$VERSION_TAG"
    echo ""
    echo "✓ Pushed.  Watch CI:  gh run watch"
    echo "  Once green, the DMG appears at:"
    echo "    https://github.com/USER/lumina-music/releases/tag/${VERSION_TAG}"
    ;;
  *)
    echo ""
    echo "Skipped push.  When ready:"
    echo "  git push origin main && git push origin ${VERSION_TAG}"
    ;;
esac
