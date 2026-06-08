#!/usr/bin/env bash
# get-metadata.sh — List all pages and top-level frames in a Figma file
# Usage: bash get-metadata.sh --file-key <fileKey> [--depth 3]
#
# Default depth=3 returns pages + frames + their first-level children.
# Increase to detect flow signals (CONNECTOR nodes, prototype interactions).
# Requires: FIGMA_TOKEN set in environment (see SKILL.md for setup)

set -euo pipefail

FILE_KEY=""
DEPTH="3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file-key) FILE_KEY="$2"; shift 2 ;;
    --depth)    DEPTH="$2";    shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required. See SKILL.md#credential-setup}"
[[ -z "$FILE_KEY" ]] && { echo "Error: --file-key is required" >&2; exit 1; }

# ── Fetch file ────────────────────────────────────────────────────────────────
TMPFILE=$(mktemp "$TMPDIR/figma_metadata_XXXXXX.json")
trap 'rm -f "$TMPFILE"' EXIT

curl -s -f \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/${FILE_KEY}?depth=${DEPTH}" \
  -o "$TMPFILE"

# ── Parse and display ─────────────────────────────────────────────────────────
python3 - "$TMPFILE" <<'PYEOF'
import json, sys
from collections import Counter

with open(sys.argv[1]) as f:
    data = json.load(f)

if "err" in data:
    print(f"Figma API error: {data['err']}", file=sys.stderr)
    sys.exit(1)

doc        = data.get("document", {})
file_name  = data.get("name", "unknown")
last_mod   = data.get("lastModified", "")[:10]
version    = data.get("version", "")

print(f"File     : {file_name}")
print(f"Modified : {last_mod}   Version: {version}")
print("=" * 60)

def count_flow_signals(nodes):
    """Count CONNECTOR nodes and prototype interactions in a subtree."""
    connector_count   = 0
    interaction_count = 0
    def walk(node):
        nonlocal connector_count, interaction_count
        if node.get("type") == "CONNECTOR":
            connector_count += 1
        if node.get("interactions"):
            interaction_count += len(node["interactions"])
        for child in node.get("children", []):
            walk(child)
    for n in nodes:
        walk(n)
    return connector_count, interaction_count

for page in doc.get("children", []):
    children     = page.get("children", [])
    conn, ixns   = count_flow_signals(children)
    flow_tag     = ""
    if conn or ixns:
        parts = []
        if conn:  parts.append(f"{conn} connector(s)")
        if ixns:  parts.append(f"{ixns} interaction(s)")
        flow_tag = f"  ← {', '.join(parts)}"

    print(f"\nPage: {page['name']}  (id: {page['id']}){flow_tag}")
    if not children:
        print("  (no top-level frames)")
        continue
    for frame in children:
        ftype  = frame.get("type", "?")
        bounds = frame.get("absoluteBoundingBox", {})
        dims   = ""
        if bounds:
            dims = f"  {int(bounds.get('width',0))}×{int(bounds.get('height',0))}"
        print(f"  {ftype:<16} id: {frame['id']:<20} {frame['name']}{dims}")

print()
print("Next steps:")
print("  • Full page tree:    bash get-page-full.sh --file-key <key> --page-id <pageId>")
print("  • UI flow/arrows:    bash get-flow.sh --file-key <key>")
print("  • Frame spec:        bash get-design-context.sh --file-key <key> --node-id <frameId>")
PYEOF
