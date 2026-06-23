#!/usr/bin/env bash
# scripts/first-time-setup.sh
#
# One-shot bootstrap for the GitHub + Sparkle workflow.
#
# What it does:
#   1. Asks for your GitHub username + repository name
#   2. Replaces "USER" / "USERPLACEHOLDER" placeholders in Info.plist + README
#   3. Creates the GitHub repository via gh
#   4. Generates a Sparkle EdDSA keypair (one-time)
#   5. Uploads SPARKLE_PUBLIC_KEY + SPARKLE_PRIV_KEY as repo secrets
#   6. Pushes main + makes a commit explaining the placeholder replacement
#   7. (Optional) Prompts for Apple Developer secrets and uploads them
#
# Idempotent: re-running is safe. Each step short-circuits if already done.

set -euo pipefail

cd "$(dirname "$0")/.."

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
say()  { echo -e "${GREEN}→${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
fail() { echo -e "${RED}✘${NC} $*"; exit 1; }

# ─── 0. Tool preflight ────────────────────────────────────────────────────
command -v git >/dev/null || fail "git missing"
command -v gh  >/dev/null || fail "gh missing — install with: brew install gh"
gh auth status >/dev/null 2>&1 || fail "gh not logged in — run: gh auth login"

# ─── 1. Identity ──────────────────────────────────────────────────────────
DEFAULT_USER="$(gh api user --jq .login 2>/dev/null || echo "")"
read -r -p "GitHub username [${DEFAULT_USER}]: " GH_USER
GH_USER="${GH_USER:-$DEFAULT_USER}"
[[ -n "$GH_USER" ]] || fail "username required"

read -r -p "Repository name [lumina-music]: " REPO_NAME
REPO_NAME="${REPO_NAME:-lumina-music}"

say "Target: https://github.com/${GH_USER}/${REPO_NAME}"
echo

# ─── 2. Replace placeholders ──────────────────────────────────────────────
if grep -q "USERPLACEHOLDER\|^USER/lumina-music" Resources/Info.plist README.md 2>/dev/null; then
  say "Replacing USER placeholders..."
  # macOS sed -i needs an empty quote arg
  sed -i '' "s|USERPLACEHOLDER|${GH_USER}|g" Resources/Info.plist
  sed -i '' "s|USER/lumina-music|${GH_USER}/${REPO_NAME}|g" README.md
  sed -i '' "s|USER\\.github\\.io|${GH_USER}.github.io|g" \
    README.md scripts/sparkle-appcast.sh 2>/dev/null || true
  sed -i '' "s|lumina-music/${REPO_NAME}|lumina-music|g" \
    README.md 2>/dev/null || true
  if git diff --quiet; then
    say "(nothing to replace)"
  else
    git add Resources/Info.plist README.md scripts/sparkle-appcast.sh
    git -c commit.gpgsign=false commit -m "config: substitute GitHub user ${GH_USER}/${REPO_NAME}"
  fi
else
  say "Placeholders already replaced."
fi

# ─── 3. Create GitHub repository ──────────────────────────────────────────
if ! git remote get-url origin >/dev/null 2>&1; then
  say "Creating remote repository on GitHub..."
  gh repo create "${GH_USER}/${REPO_NAME}" --public \
      --source=. --remote=origin \
      --description="AI music studio for macOS"
else
  CURRENT="$(git remote get-url origin)"
  warn "Remote 'origin' already exists → $CURRENT"
fi

if ! git push -u origin main 2>&1 | tail -2; then
  warn "push failed — check 'git remote -v' and try manually."
fi

# ─── 4. Sparkle EdDSA keypair ─────────────────────────────────────────────
KEYFILE=~/.config/lumina/sparkle_ed_priv_key

if [[ ! -f "$KEYFILE" ]]; then
  say "Generating Sparkle EdDSA keypair (Keychain may prompt — click Always Allow)..."
  scripts/sparkle-tools.sh generate-keys 2>&1 | tee /tmp/sparkle-keys.log
  # Public key is printed inside a plist snippet like:
  #   <key>SUPublicEDKey</key>
  #   <string>BASE64KEY=</string>
  # Extract just the base64 string between <string>…</string> that follows.
  PUBKEY="$(awk '/<string>/{gsub(/.*<string>|<\/string>.*/,""); if(length($0)>20) print; exit}' /tmp/sparkle-keys.log 2>/dev/null || true)"
  if [[ -z "$PUBKEY" ]]; then
    # Fallback: any long base64 looking string.
    PUBKEY="$(grep -oE '[A-Za-z0-9+/]{40,}=*' /tmp/sparkle-keys.log | tail -1)"
  fi
  if [[ -z "$PUBKEY" ]]; then
    warn "Could not auto-parse public key from sparkle-tools output."
    warn "Open /tmp/sparkle-keys.log, find SUPublicEDKey's <string>…</string>,"
    warn "then run:  gh secret set SPARKLE_PUBLIC_KEY -b '<paste>' -R ${GH_USER}/${REPO_NAME}"
  fi
else
  say "Sparkle private key already exists at $KEYFILE"
  # Re-derive public key from Keychain (no-op key generation, prints public).
  PUBKEY="$(scripts/sparkle-tools.sh generate-keys 2>/dev/null | awk '/<string>/{gsub(/.*<string>|<\/string>.*/,""); if(length($0)>20) print; exit}' || true)"
fi

# ─── 5. Upload Sparkle secrets ────────────────────────────────────────────
if [[ -f "$KEYFILE" ]]; then
  say "Uploading SPARKLE_PRIV_KEY secret..."
  gh secret set SPARKLE_PRIV_KEY -R "${GH_USER}/${REPO_NAME}" < "$KEYFILE" \
    || warn "SPARKLE_PRIV_KEY upload failed; set manually via 'gh secret set'."
fi
if [[ -n "${PUBKEY:-}" ]]; then
  say "Uploading SPARKLE_PUBLIC_KEY secret..."
  gh secret set SPARKLE_PUBLIC_KEY -R "${GH_USER}/${REPO_NAME}" -b "$PUBKEY" \
    || warn "SPARKLE_PUBLIC_KEY upload failed; set manually."
fi

# ─── 6. Apple Developer (optional) ────────────────────────────────────────
echo
read -r -p "Configure Apple Developer signing now? [y/N]: " WANT_APPLE
if [[ "${WANT_APPLE,,}" == "y" ]] || [[ "${WANT_APPLE,,}" == "yes" ]]; then
  echo
  echo "You'll need these on hand:"
  echo "  - .p12 export of 'Developer ID Application' cert (from Keychain Access)"
  echo "  - Cert password"
  echo "  - Your Apple ID email"
  echo "  - Your Team ID (10 chars, from developer.apple.com → Membership)"
  echo "  - App-specific Password (from appleid.apple.com → Security)"
  echo
  read -r -p "Path to .p12 file: " P12_PATH
  read -r -s -p "P12 password: " P12_PASS; echo
  read -r -p "Apple ID email: " APPLE_ID
  read -r -p "Team ID (10 chars): " TEAM_ID
  read -r -p "Developer ID common name (e.g. 'Developer ID Application: Jenny Qin ($TEAM_ID)'): " DEV_ID
  read -r -s -p "App-specific Password: " APP_PW; echo

  REPO="${GH_USER}/${REPO_NAME}"
  base64 -i "$P12_PATH" | gh secret set DEVELOPER_ID_CERT_P12_BASE64 -R "$REPO"
  gh secret set DEVELOPER_ID_CERT_PASSWORD -R "$REPO" -b "$P12_PASS"
  gh secret set APPLE_ID -R "$REPO" -b "$APPLE_ID"
  gh secret set APPLE_TEAM_ID -R "$REPO" -b "$TEAM_ID"
  gh secret set DEVELOPER_ID -R "$REPO" -b "$DEV_ID"
  gh secret set APPLE_APP_PASSWORD -R "$REPO" -b "$APP_PW"
  say "✓ Apple Developer secrets uploaded."
else
  warn "Skipping Apple Developer. Builds will be ad-hoc signed (right-click → Open required on first launch)."
fi

# ─── 7. JWT API key (local only) ──────────────────────────────────────────
if [[ ! -f ~/.config/lumina/secrets.env ]]; then
  echo
  warn "No MiniMax JWT yet."
  warn "Open https://platform.minimaxi.com → API Keys, then run:"
  warn "  mkdir -p ~/.config/lumina && chmod 700 ~/.config/lumina"
  warn "  cat > ~/.config/lumina/secrets.env <<EOF"
  warn "  MINIMAX_API_KEY=<paste JWT>"
  warn "  MINIMAX_GROUP_ID=<paste Group ID>"
  warn "  MINIMAX_API_BASE=https://api.minimaxi.com"
  warn "  EOF"
  warn "  chmod 600 ~/.config/lumina/secrets.env"
  warn "(Or paste them via Preferences → ⌘, after launching the app.)"
fi

# ─── 8. Done ──────────────────────────────────────────────────────────────
echo
say "Setup complete."
echo
echo "Next:  ./scripts/release.sh v0.1.1 \"first dry-run\""
echo "Then:  gh run watch       # follow CI"
echo "And:   gh release view v0.1.1 --web"
