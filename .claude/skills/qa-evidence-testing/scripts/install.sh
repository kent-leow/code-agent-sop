#!/usr/bin/env bash
# One-time tool install for qa-evidence-testing. Run ONLY after the user approves (network + home-dir writes, unsandboxed).
# Pinned: Node 24 (nvm), agent-browser@0.39.1, Chrome for Testing (agent-browser install), imageio-ffmpeg==0.6.0.
set -euo pipefail
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh" >/dev/null || { echo "ERROR: nvm not found at $NVM_DIR" >&2; exit 1; }
nvm install 24 >/dev/null && nvm use 24 >/dev/null
echo "node $(node --version)"

T="$HOME/.agent-browser/tools"
# npm leaves agent-browser's postinstall unapproved (allowScripts); the bundled binary works without it.
npm install --prefix "$T" agent-browser@0.39.1 >/dev/null
export PATH="$T/bin:$T/node_modules/.bin:$PATH"
echo "$(agent-browser --version)"

# Install Chrome for Testing explicitly: web-exploration/chrome-cdp.sh exits silently under `set -e`
# when ~/.agent-browser/browsers doesn't exist yet, so it never reaches its own install branch.
find "$HOME/.agent-browser/browsers" -name "Google Chrome for Testing" -path "*/MacOS/*" 2>/dev/null | grep -q . \
  || agent-browser install

# Recording needs ffmpeg with libx264 + libvpx; Homebrew/mise shims often lack libx264.
if command -v uv >/dev/null 2>&1; then uv pip install --target "$T/py" imageio-ffmpeg==0.6.0
else python3 -m pip install --quiet --target "$T/py" imageio-ffmpeg==0.6.0; fi
mkdir -p "$T/bin"
ln -sf "$(PYTHONPATH="$T/py" python3 -c 'import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())')" "$T/bin/ffmpeg"
agent-browser doctor --record --offline 2>&1 | grep -E "ffmpeg|Summary"
