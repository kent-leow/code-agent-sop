#!/usr/bin/env bash
# get-metadata.sh — List all pages and top-level frames in a Figma file
# Usage: bash get-metadata.sh --file-key <fileKey>
#
# Requires: FIGMA_TOKEN set in environment (see SKILL.md for setup)
# Output:   A list of pages with their child frame names and node IDs

set -euo pipefail

FILE_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file-key) FILE_KEY="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ────────────────────────────────────────────────────────────────
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required. See SKILL.md#credential-setup}"
[[ -z "$FILE_KEY" ]] && { echo "Error: --file-key is required" >&2; exit 1; }

# ── Fetch file with depth=2 (pages + their direct children) ─────────────────
TMPFILE=$(mktemp /tmp/figma_metadata_XXXXXX.json)
trap 'rm -f "$TMPFILE"' EXIT

curl -s -f \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/${FILE_KEY}?depth=2" \
  -o "$TMPFILE"

# ── Parse and display ────────────────────────────────────────────────────────
python3 - "$TMPFILE" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

if "err" in data:
    print(f"Figma API error: {data['err']}", file=sys.stderr)
    sys.exit(1)

doc = data.get("document", {})
file_name = data.get("name", "unknown")

print(f"File: {file_name}")
print("=" * 60)

for page in doc.get("children", []):
    print(f"\nPage: {page['name']}  (id: {page['id']})")
    children = page.get("children", [])
    if not children:
        print("  (no top-level frames)")
    for frame in children:
        ftype = frame.get("type", "?")
        print(f"  {ftype:<12} id: {frame['id']:<20} name: {frame['name']}")
PYEOF
