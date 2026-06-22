#!/usr/bin/env bash
# get-team-styles.sh — Get all published styles from a team library
# Usage: bash get-team-styles.sh --team-id <teamId> [--output <file.json>]
#
# Returns all styles published to the team library:
# - FILL styles (colors)
# - TEXT styles (typography)
# - EFFECT styles (shadows, blurs)
# - GRID styles (layout grids)
#
# Requires: FIGMA_TOKEN set in environment

set -euo pipefail

TEAM_ID=""
OUTPUT=""
PAGE_SIZE="100"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --team-id) TEAM_ID="$2"; shift 2 ;;
    --output)  OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required}"
[[ -z "$TEAM_ID" ]] && { echo "Error: --team-id is required" >&2; exit 1; }

# ── Fetch styles (paginated) ─────────────────────────────────────────────────
ALL_STYLES="[]"
CURSOR=""

while true; do
  URL="https://api.figma.com/v1/teams/${TEAM_ID}/styles?page_size=${PAGE_SIZE}"
  [[ -n "$CURSOR" ]] && URL="${URL}&cursor=${CURSOR}"
  
  RESPONSE=$(curl -s -f -H "X-Figma-Token: $FIGMA_TOKEN" "$URL")
  
  # Extract styles and cursor
  RESULT=$(python3 - "$RESPONSE" "$ALL_STYLES" <<'PYEOF'
import json, sys

response = json.loads(sys.argv[1])
existing = json.loads(sys.argv[2])

meta = response.get('meta', {})
styles = meta.get('styles', [])
cursor = meta.get('cursor', {})

all_styles = existing + styles

print(json.dumps(all_styles))
print(cursor.get('after', ''))
PYEOF
)
  
  ALL_STYLES=$(echo "$RESULT" | head -1)
  CURSOR=$(echo "$RESULT" | tail -1)
  
  [[ -z "$CURSOR" ]] && break
done

# ── Output ───────────────────────────────────────────────────────────────────
if [[ -n "$OUTPUT" ]]; then
  echo "$ALL_STYLES" | python3 -m json.tool > "$OUTPUT"
  echo "Saved to $OUTPUT"
else
  echo "$ALL_STYLES" | python3 -c "
import json, sys
from collections import Counter

styles = json.load(sys.stdin)

# Group by type
by_type = {}
for s in styles:
    t = s.get('style_type', 'UNKNOWN')
    by_type.setdefault(t, []).append(s)

print(f'Found {len(styles)} team style(s):\n')

for style_type, items in sorted(by_type.items()):
    print(f'{style_type} ({len(items)}):')
    for s in items[:5]:
        name = s.get('name', 'Unnamed')
        key = s.get('key', '')
        print(f'  • {name} (key: {key})')
    if len(items) > 5:
        print(f'  ... and {len(items) - 5} more')
    print()
"
fi
