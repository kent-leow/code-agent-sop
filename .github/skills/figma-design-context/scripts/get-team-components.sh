#!/usr/bin/env bash
# get-team-components.sh — Get all published components from a team library
# Usage: bash get-team-components.sh --team-id <teamId> [--output <file.json>]
#
# Returns all components published to the team library, including:
# - Component key, name, description
# - Containing file key and node ID
# - Thumbnail URL
#
# To find your team ID: Open any file → File menu → "Move to project" → 
# look at URL: figma.com/files/team/<teamId>/...
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

# ── Fetch components (paginated) ─────────────────────────────────────────────
ALL_COMPONENTS="[]"
CURSOR=""

while true; do
  URL="https://api.figma.com/v1/teams/${TEAM_ID}/components?page_size=${PAGE_SIZE}"
  [[ -n "$CURSOR" ]] && URL="${URL}&cursor=${CURSOR}"
  
  RESPONSE=$(curl -s -f -H "X-Figma-Token: $FIGMA_TOKEN" "$URL")
  
  # Extract components and cursor
  RESULT=$(python3 - "$RESPONSE" "$ALL_COMPONENTS" <<'PYEOF'
import json, sys

response = json.loads(sys.argv[1])
existing = json.loads(sys.argv[2])

meta = response.get('meta', {})
components = meta.get('components', [])
cursor = meta.get('cursor', {})

# Merge components
all_components = existing + components

# Output: components JSON, then cursor on separate line
print(json.dumps(all_components))
print(cursor.get('after', ''))
PYEOF
)
  
  ALL_COMPONENTS=$(echo "$RESULT" | head -1)
  CURSOR=$(echo "$RESULT" | tail -1)
  
  [[ -z "$CURSOR" ]] && break
done

# ── Output ───────────────────────────────────────────────────────────────────
if [[ -n "$OUTPUT" ]]; then
  echo "$ALL_COMPONENTS" | python3 -m json.tool > "$OUTPUT"
  echo "Saved to $OUTPUT"
else
  echo "$ALL_COMPONENTS" | python3 -c "
import json, sys
components = json.load(sys.stdin)

print(f'Found {len(components)} team component(s):\n')
for comp in components[:20]:  # Show first 20
    name = comp.get('name', 'Unnamed')
    key = comp.get('key', '')
    desc = comp.get('description', '')[:50]
    file_key = comp.get('containing_frame', {}).get('file_key', comp.get('file_key', ''))
    node_id = comp.get('node_id', '')
    
    print(f'  {name}')
    print(f'    key: {key}')
    print(f'    file: {file_key}, node: {node_id}')
    if desc:
        print(f'    desc: {desc}...')
    print()

if len(components) > 20:
    print(f'... and {len(components) - 20} more')
"
fi
