#!/usr/bin/env bash
# get-page-full.sh — Fetch complete node tree for a specific Figma page
# Usage: bash get-page-full.sh --file-key <fileKey> --page-id <pageId> [--depth 10] [--output ./figma-page.json]
#
# Use this when you need the full element inventory of a page:
#   - All node types (FRAME, COMPONENT, INSTANCE, TEXT, CONNECTOR, VECTOR, GROUP …)
#   - Counts of flow connectors and prototype interactions
#   - Every frame/section on the page to inform subsequent get-design-context.sh calls
#
# Accepts page IDs in both API format (0:1) and URL format (0-1)
# Requires: FIGMA_TOKEN set in environment (see SKILL.md for setup)

set -euo pipefail

FILE_KEY=""
PAGE_ID=""
DEPTH="10"
OUTPUT="./figma-page.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file-key) FILE_KEY="$2"; shift 2 ;;
    --page-id)  PAGE_ID="$2";  shift 2 ;;
    --depth)    DEPTH="$2";    shift 2 ;;
    --output)   OUTPUT="$2";   shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required. See SKILL.md#credential-setup}"
[[ -z "$FILE_KEY" ]] && { echo "Error: --file-key is required" >&2; exit 1; }
[[ -z "$PAGE_ID" ]]  && { echo "Error: --page-id is required (run get-metadata.sh to find page IDs)" >&2; exit 1; }

# ── Normalise node ID ─────────────────────────────────────────────────────────
NORMALISED_PAGE_ID=$(echo "$PAGE_ID" | python3 -c "
import sys, re
raw = sys.stdin.read().strip()
if ':' not in raw:
    raw = re.sub(r'^(\d+)-(\d+)$', r'\1:\2', raw)
print(raw)
")
ENCODED_PAGE_ID="${NORMALISED_PAGE_ID//:/%3A}"

echo "Fetching full page tree (depth=${DEPTH})..."

HTTP_STATUS=$(curl -s -w "%{http_code}" \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/${FILE_KEY}/nodes?ids=${ENCODED_PAGE_ID}&depth=${DEPTH}" \
  -o "$OUTPUT")

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "Error: Figma API returned HTTP $HTTP_STATUS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

python3 - "$OUTPUT" <<'PYEOF'
import json, sys
from collections import Counter

with open(sys.argv[1]) as f:
    data = json.load(f)

if "err" in data:
    print(f"Figma API error: {data['err']}", file=sys.stderr)
    sys.exit(1)

nodes = data.get("nodes", {})
if not nodes:
    print("Warning: no nodes returned. Verify --page-id is a valid page (not a frame).", file=sys.stderr)
    sys.exit(1)

type_counter    = Counter()
connector_count = 0
interaction_count = 0
frames_list     = []   # (id, name, w, h)

def walk(node, depth=0):
    global connector_count, interaction_count
    ntype = node.get("type", "UNKNOWN")
    nid   = node.get("id", "")
    nname = node.get("name", "")
    type_counter[ntype] += 1

    if ntype == "CONNECTOR":
        connector_count += 1

    ixns = node.get("interactions")
    if ixns:
        interaction_count += len(ixns)

    if ntype in ("FRAME", "COMPONENT", "COMPONENT_SET", "SECTION") and depth <= 1:
        bounds = node.get("absoluteBoundingBox", {})
        frames_list.append({
            "id":   nid,
            "name": nname,
            "type": ntype,
            "w":    bounds.get("width"),
            "h":    bounds.get("height"),
        })

    for child in node.get("children", []):
        walk(child, depth + 1)

for node_id, node_data in nodes.items():
    doc = node_data.get("document", {})
    walk(doc)

file_bytes = len(json.dumps(data).encode("utf-8"))
print(f"Page tree saved  ({file_bytes / 1024:.0f} KB)")
print()

# ── Top-level frames ──────────────────────────────────────────────────────────
if frames_list:
    print(f"TOP-LEVEL FRAMES / SECTIONS ({len(frames_list)})")
    print("-" * 60)
    for fr in frames_list:
        dims = f"{fr['w']} × {fr['h']} px" if fr["w"] is not None else ""
        print(f"  {fr['type']:<16} id: {fr['id']:<20} {fr['name']:<30} {dims}")
    print()

# ── Node type distribution ────────────────────────────────────────────────────
print("NODE TYPE DISTRIBUTION")
print("-" * 60)
for ntype, count in type_counter.most_common():
    notes = ""
    if ntype == "CONNECTOR":
        notes = "  ← flow arrows  →  run get-flow.sh"
    elif ntype == "INSTANCE":
        notes = "  ← component instances  →  run get-components.sh"
    elif ntype == "TEXT":
        notes = "  ← all text layers"
    print(f"  {ntype:<25} {count:>5}{notes}")
print()

if connector_count or interaction_count:
    print("UI FLOW SIGNALS")
    print("-" * 60)
    if connector_count:
        print(f"  {connector_count} CONNECTOR node(s) — drawn flow arrows on canvas")
    if interaction_count:
        print(f"  {interaction_count} prototype interaction(s) — tap/click → navigate")
    print("  Run: bash get-flow.sh --file-key <key> to extract the full flow graph")
    print()

print("Next steps:")
print("  • Inspect a frame:  bash get-design-context.sh --file-key <key> --node-id <frameId>")
print("  • Extract UI flow:  bash get-flow.sh --file-key <key>")
print("  • Get components:   bash get-components.sh --file-key <key>")
PYEOF
