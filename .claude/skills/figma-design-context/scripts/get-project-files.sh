#!/usr/bin/env bash
# get-project-files.sh — List all files in a project
# Usage: bash get-project-files.sh --project-id <projectId> [--output <file.json>]
#
# Requires: FIGMA_TOKEN set in environment

set -euo pipefail

PROJECT_ID=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-id) PROJECT_ID="$2"; shift 2 ;;
    --output)     OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required}"
[[ -z "$PROJECT_ID" ]] && { echo "Error: --project-id is required" >&2; exit 1; }

# ── Fetch files ──────────────────────────────────────────────────────────────
RESPONSE=$(curl -s -f \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/projects/${PROJECT_ID}/files")

# ── Output ───────────────────────────────────────────────────────────────────
if [[ -n "$OUTPUT" ]]; then
  echo "$RESPONSE" | python3 -m json.tool > "$OUTPUT"
  echo "Saved to $OUTPUT"
else
  echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)

files = data.get('files', [])
print(f'Found {len(files)} file(s):\n')

for f in files:
    name = f.get('name', 'Unnamed')
    key = f.get('key', '')
    last_modified = f.get('last_modified', '')[:10]
    
    print(f'  {name}')
    print(f'    key: {key}')
    print(f'    modified: {last_modified}')
    print()
"
fi
