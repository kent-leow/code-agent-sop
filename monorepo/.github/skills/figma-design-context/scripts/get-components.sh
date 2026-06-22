#!/usr/bin/env bash
# get-components.sh — List all published components and component sets in a Figma file
# Usage: bash get-components.sh --file-key <fileKey> [--output ./figma-components.json]
#
# Covers:
#   GET /v1/files/{fileKey}/components      — all published/local components
#   GET /v1/files/{fileKey}/component_sets  — variant groups (e.g. Button/Primary/Large)
#
# Useful for finding existing design system components before implementing UI,
# so you can map Figma INSTANCE nodes to real project component names.
# Requires: FIGMA_TOKEN set in environment (see SKILL.md for setup)

set -euo pipefail

FILE_KEY=""
OUTPUT="./figma-components.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file-key) FILE_KEY="$2"; shift 2 ;;
    --output)   OUTPUT="$2";   shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required. See SKILL.md#credential-setup}"
[[ -z "$FILE_KEY" ]] && { echo "Error: --file-key is required" >&2; exit 1; }

TMPFILE_COMP=$(mktemp "$TMPDIR/figma_comp_XXXXXX.json")
TMPFILE_SETS=$(mktemp "$TMPDIR/figma_sets_XXXXXX.json")
trap 'rm -f "$TMPFILE_COMP" "$TMPFILE_SETS"' EXIT

echo "Fetching components and component sets..."

curl -s -f \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/${FILE_KEY}/components" \
  -o "$TMPFILE_COMP"

curl -s -f \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/${FILE_KEY}/component_sets" \
  -o "$TMPFILE_SETS"

python3 - "$TMPFILE_COMP" "$TMPFILE_SETS" "$OUTPUT" <<'PYEOF'
import json, sys
from collections import defaultdict

with open(sys.argv[1]) as f:
    comp_data = json.load(f)
with open(sys.argv[2]) as f:
    sets_data = json.load(f)
out_path = sys.argv[3]

if "err" in comp_data:
    print(f"Figma API error (components): {comp_data['err']}", file=sys.stderr)
    sys.exit(1)
if "err" in sets_data:
    print(f"Figma API error (component_sets): {sets_data['err']}", file=sys.stderr)
    sys.exit(1)

components = comp_data.get("meta", {}).get("components", [])
comp_sets  = sets_data.get("meta", {}).get("component_sets", [])

result = {"components": components, "componentSets": comp_sets}
with open(out_path, "w") as f:
    json.dump(result, f, indent=2)

print(f"Components: {len(components)}   Component Sets: {len(comp_sets)}")
print(f"Saved to: {out_path}")
print()

# ── Component sets (variant groups) ──────────────────────────────────────────
if comp_sets:
    print(f"COMPONENT SETS / VARIANT GROUPS ({len(comp_sets)})")
    print("-" * 60)
    for s in sorted(comp_sets, key=lambda x: x.get("name", "")):
        desc = f"  — {s['description']}" if s.get("description") else ""
        print(f"  {s.get('name', '?'):<40}  key: {s.get('key', '?')}{desc}")
    print()

# ── Individual components ─────────────────────────────────────────────────────
if components:
    # Group by containing set where possible
    set_name_by_key = {s["key"]: s["name"] for s in comp_sets}

    by_set = defaultdict(list)
    standalone = []
    for c in components:
        # Component names in a set usually follow "SetName/Variant" convention
        parts = c.get("name", "").split("/", 1)
        if len(parts) > 1:
            by_set[parts[0]].append(c)
        else:
            standalone.append(c)

    if by_set:
        print(f"COMPONENTS BY GROUP ({sum(len(v) for v in by_set.values())})")
        print("-" * 60)
        for group_name in sorted(by_set):
            group_items = sorted(by_set[group_name], key=lambda x: x.get("name", ""))
            print(f"  {group_name}  ({len(group_items)} variants)")
            for c in group_items:
                variant = c.get("name", "?").split("/", 1)[-1]
                print(f"    {variant:<36}  key: {c.get('key', '?')}")
        print()

    if standalone:
        print(f"STANDALONE COMPONENTS ({len(standalone)})")
        print("-" * 60)
        for c in sorted(standalone, key=lambda x: x.get("name", "")):
            desc = f"  — {c['description']}" if c.get("description") else ""
            print(f"  {c.get('name', '?'):<40}  key: {c.get('key', '?')}{desc}")
        print()
PYEOF
