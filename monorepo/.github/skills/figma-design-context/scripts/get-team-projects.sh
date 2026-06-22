#!/usr/bin/env bash
# get-team-projects.sh — List all projects in a team
# Usage: bash get-team-projects.sh --team-id <teamId> [--output <file.json>]
#
# Requires: FIGMA_TOKEN set in environment

set -euo pipefail

TEAM_ID=""
OUTPUT=""

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

# ── Fetch projects ───────────────────────────────────────────────────────────
RESPONSE=$(curl -s -f \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/teams/${TEAM_ID}/projects")

# ── Output ───────────────────────────────────────────────────────────────────
if [[ -n "$OUTPUT" ]]; then
  echo "$RESPONSE" | python3 -m json.tool > "$OUTPUT"
  echo "Saved to $OUTPUT"
else
  echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)

projects = data.get('projects', [])
print(f'Found {len(projects)} project(s):\n')

for p in projects:
    name = p.get('name', 'Unnamed')
    pid = p.get('id', '')
    print(f'  {name}')
    print(f'    id: {pid}')
    print()
"
fi
