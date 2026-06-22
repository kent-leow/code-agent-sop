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
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required}"

# ── Fetch user info ──────────────────────────────────────────────────────────
RESPONSE=$(curl -s -f \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/me")

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
