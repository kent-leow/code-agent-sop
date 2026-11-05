#!/usr/bin/env bash
# whoami.sh — Get current authenticated user info
# Usage: bash whoami.sh
#
# Returns:
# - User ID
# - Email
# - Handle (username)
# - Profile image URL
#
# Requires: FIGMA_TOKEN set in environment

set -euo pipefail

# ── Validate ─────────────────────────────────────────────────────────────────
source "$(dirname "${BASH_SOURCE[0]}")/_http.sh"

# ── Fetch user info ──────────────────────────────────────────────────────────
RESPONSE=$(figma_curl -f \
  "$FIGMA_API/me")

# ── Output ───────────────────────────────────────────────────────────────────
echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)

if 'id' in data:
    print('Authenticated as:')
    print(f'  ID:     {data.get(\"id\", \"\")}')
    print(f'  Email:  {data.get(\"email\", \"\")}')
    print(f'  Handle: {data.get(\"handle\", \"\")}')
    img = data.get('img_url', '')
    if img:
        print(f'  Avatar: {img}')
elif 'err' in data:
    print(f'Error: {data.get(\"err\")}')
else:
    print(json.dumps(data, indent=2))
"
