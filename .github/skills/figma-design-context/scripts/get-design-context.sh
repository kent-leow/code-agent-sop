#!/usr/bin/env bash
# get-design-context.sh — Fetch complete design spec for a Figma node (layout, typography, colours, spacing)
# Usage: bash get-design-context.sh --file-key <fileKey> --node-id <nodeId> [--output ./figma-context.json]
#
# Accepts node IDs in both API format (2313:102848) and URL format (2313-102848)
# Requires: FIGMA_TOKEN set in environment (see SKILL.md for setup)
# Output:   JSON file with full node document tree + component + styles metadata

set -euo pipefail

FILE_KEY=""
NODE_ID=""
OUTPUT="./figma-context.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file-key) FILE_KEY="$2"; shift 2 ;;
    --node-id)  NODE_ID="$2";  shift 2 ;;
    --output)   OUTPUT="$2";   shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ────────────────────────────────────────────────────────────────
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required. See SKILL.md#credential-setup}"
[[ -z "$FILE_KEY" ]] && { echo "Error: --file-key is required" >&2; exit 1; }
[[ -z "$NODE_ID" ]]  && { echo "Error: --node-id is required" >&2; exit 1; }

# ── Normalise node ID ────────────────────────────────────────────────────────
NORMALISED_NODE_ID=$(echo "$NODE_ID" | python3 -c "
import sys, re
raw = sys.stdin.read().strip()
if ':' not in raw:
    raw = re.sub(r'^(\d+)-(\d+)$', r'\1:\2', raw)
print(raw)
")

ENCODED_NODE_ID="${NORMALISED_NODE_ID//:/%3A}"

echo "Fetching design context for node: $NORMALISED_NODE_ID"

# ── Fetch node spec ──────────────────────────────────────────────────────────
HTTP_STATUS=$(curl -s -w "%{http_code}" \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/${FILE_KEY}/nodes?ids=${ENCODED_NODE_ID}" \
  -o "$OUTPUT")

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "Error: Figma API returned HTTP $HTTP_STATUS" >&2
  cat "$OUTPUT" >&2
  exit 1
fi

# ── Validate response and print summary ─────────────────────────────────────
python3 - "$OUTPUT" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    data = json.load(f)

if "err" in data:
    print(f"Figma API error: {data['err']}", file=sys.stderr)
    sys.exit(1)

nodes = data.get("nodes", {})
if not nodes:
    print("Warning: No nodes returned. Check --node-id is correct.", file=sys.stderr)
    sys.exit(1)

file_bytes = len(json.dumps(data).encode("utf-8"))
print(f"Design context saved  ({file_bytes / 1024:.0f} KB)")
print(f"Node IDs returned: {list(nodes.keys())}")
print()

for node_id, node_data in nodes.items():
    doc = node_data.get("document", {})
    components = node_data.get("components", {})
    styles = node_data.get("styles", {})
    print(f"  Name       : {doc.get('name', 'unknown')}")
    print(f"  Type       : {doc.get('type', 'unknown')}")
    bounds = doc.get("absoluteBoundingBox", doc.get("absoluteRenderBounds"))
    if bounds:
        print(f"  Dimensions : {bounds.get('width', '?')} × {bounds.get('height', '?')} px")
    print(f"  Components : {len(components)}")
    print(f"  Styles     : {len(styles)}")
    print()

print("Next step: run summarize-context.sh --input <output> for a readable breakdown.")
PYEOF
