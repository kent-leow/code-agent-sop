#!/usr/bin/env bash
# get-styles.sh — List all shared styles (colours, text, effects, grids) in a Figma file
# Usage: bash get-styles.sh --file-key <fileKey>
#
# Useful for extracting design tokens defined at file level (shared across frames).
# Requires: FIGMA_TOKEN set in environment (see SKILL.md for setup)

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

# ── Fetch styles ─────────────────────────────────────────────────────────────
TMPFILE=$(mktemp /tmp/figma_styles_XXXXXX.json)
trap 'rm -f "$TMPFILE"' EXIT

curl -s -f \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/${FILE_KEY}/styles" \
  -o "$TMPFILE"

python3 - "$TMPFILE" <<'PYEOF'
import json, sys
from collections import defaultdict

with open(sys.argv[1]) as f:
    data = json.load(f)

if "err" in data:
    print(f"Figma API error: {data['err']}", file=sys.stderr)
    sys.exit(1)

styles = data.get("meta", {}).get("styles", [])
if not styles:
    print("No shared styles found in this file.")
    sys.exit(0)

by_type = defaultdict(list)
for s in styles:
    by_type[s.get("style_type", "UNKNOWN")].append(s)

for stype, items in sorted(by_type.items()):
    print(f"\n{stype} ({len(items)})")
    print("-" * 40)
    for item in sorted(items, key=lambda x: x.get("name", "")):
        print(f"  {item.get('name', '?'):<40}  key: {item.get('key', '?')}")
PYEOF
