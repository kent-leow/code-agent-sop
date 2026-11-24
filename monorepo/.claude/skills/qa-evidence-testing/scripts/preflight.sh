#!/usr/bin/env bash
# Read-only readiness check for qa-evidence-testing. Prints one line per check; exit 1 if anything is missing.
# Run unsandboxed (reads ~/.nvm, ~/.agent-browser, probes port 9222).
set -uo pipefail
miss=0
ok()  { echo "  ok    $*"; }
bad() { echo "  MISS  $*"; miss=1; }

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh" >/dev/null
  if nvm ls 24 >/dev/null 2>&1; then ok "node 24 ($(nvm version 24))"; else bad "node 24 (nvm install 24)"; fi
  nvm use 24 >/dev/null 2>&1 || true
else bad "nvm ($NVM_DIR/nvm.sh)"; fi

AB="$HOME/.agent-browser/tools/node_modules/.bin/agent-browser"
if [ -x "$AB" ]; then ok "agent-browser $("$AB" --version 2>/dev/null | awk '{print $2}')"; else bad "agent-browser (~/.agent-browser/tools)"; fi

if find "$HOME/.agent-browser/browsers" -name "Google Chrome for Testing" -path "*/MacOS/*" 2>/dev/null | grep -q . \
   || find "$HOME/.agent-browser/browsers" -name chrome -type f 2>/dev/null | grep -q .; then ok "Chrome for Testing"
else bad "Chrome for Testing (agent-browser install)"; fi

FF="$HOME/.agent-browser/tools/bin/ffmpeg"
if [ -x "$FF" ] && "$FF" -hide_banner -encoders 2>/dev/null | grep -q libx264; then ok "ffmpeg with libx264 (recording)"
else bad "ffmpeg with libx264/libvpx (imageio-ffmpeg)"; fi

if lsof -i :9222 -sTCP:LISTEN >/dev/null 2>&1; then ok "Chrome CDP on :9222"; else echo "  info  Chrome CDP not running — start: bash <monorepo>/skills/web-exploration/chrome-cdp.sh"; fi

for h in "${QA_HOSTS:-dashboard.dev.gobusiness.io mockpass.dev.gobusiness.io agencyportal.dev.gobusiness.io}"; do
  for x in $h; do nc -z -w 3 "$x" 443 >/dev/null 2>&1 && ok "reach $x" || bad "reach $x (VPN?)"; done
done
exit $miss
