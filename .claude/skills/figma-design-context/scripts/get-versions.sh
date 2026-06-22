#!/usr/bin/env bash
# get-versions.sh — Get version history of a Figma file
# Usage: bash get-versions.sh --file-key <fileKey> [--output <file.json>]
#
# Returns version history with:
# - Version ID, label, description
# - Created timestamp
# - User who created the version
#
# Requires: FIGMA_TOKEN set in environment

set -euo pipefail

FILE_KEY=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file-key) FILE_KEY="$2"; shift 2 ;;
    --output)   OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required}"
[[ -z "$FILE_KEY" ]] && { echo "Error: --file-key is required" >&2; exit 1; }

# ── Fetch versions ───────────────────────────────────────────────────────────
RESPONSE=$(curl -s -f \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/${FILE_KEY}/versions")

# ── Output ───────────────────────────────────────────────────────────────────
if [[ -n "$OUTPUT" ]]; then
  echo "$RESPONSE" | python3 -m json.tool > "$OUTPUT"
  echo "Saved to $OUTPUT"
else
  echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)

versions = data.get('versions', [])
print(f'Found {len(versions)} version(s):\n')

for v in versions[:20]:  # Show latest 20
    vid = v.get('id', '')
    label = v.get('label') or '(autosave)'
    desc = v.get('description', '')[:50] if v.get('description') else ''
    created = v.get('created_at', '')[:19].replace('T', ' ')
    user = v.get('user', {}).get('handle', 'Unknown')
    
    print(f'  [{created}] {label}')
    print(f'    id: {vid}')
    print(f'    by: {user}')
    if desc:
        print(f'    desc: {desc}')
    print()

if len(versions) > 20:
    print(f'... and {len(versions) - 20} older versions')
"
fi
