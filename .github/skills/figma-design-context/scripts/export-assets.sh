#!/usr/bin/env bash
# export-assets.sh — Export images from Figma nodes in various formats
# Usage: bash export-assets.sh --file-key <fileKey> --node-ids "1:2,3:4" [options]
#        bash export-assets.sh --file-key <fileKey> --node-id <frameId> --all-images [options]
#
# Options:
#   --format png|jpg|svg|pdf  (default: png)
#   --scale 0.01-4            (default: 1)
#   --output <dir>            (default: ./figma-assets)
#   --all-images              Export all image fills from frame subtree
#
# Requires: FIGMA_TOKEN set in environment

set -euo pipefail

FILE_KEY=""
NODE_IDS=""
NODE_ID=""
FORMAT="png"
SCALE="1"
OUTPUT="./figma-assets"
ALL_IMAGES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file-key)   FILE_KEY="$2"; shift 2 ;;
    --node-ids)   NODE_IDS="$2"; shift 2 ;;
    --node-id)    NODE_ID="$2"; shift 2 ;;
    --format)     FORMAT="$2"; shift 2 ;;
    --scale)      SCALE="$2"; shift 2 ;;
    --output)     OUTPUT="$2"; shift 2 ;;
    --all-images) ALL_IMAGES=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required}"
[[ -z "$FILE_KEY" ]] && { echo "Error: --file-key is required" >&2; exit 1; }
[[ -z "$NODE_IDS" && -z "$NODE_ID" ]] && { echo "Error: --node-ids or --node-id is required" >&2; exit 1; }

# Validate format
case "$FORMAT" in
  png|jpg|svg|pdf) ;;
  *) echo "Error: --format must be png, jpg, svg, or pdf" >&2; exit 1 ;;
esac

mkdir -p "$OUTPUT"

# ── If --all-images, find all image fills in subtree ─────────────────────────
if [[ "$ALL_IMAGES" == true && -n "$NODE_ID" ]]; then
  echo "Finding all image fills in node subtree..."
  
  # Normalize node ID
  NODE_ID="${NODE_ID//-/:}"
  
  # Fetch node subtree
  TMPFILE=$(mktemp "$TMPDIR/figma_nodes_XXXXXX.json")
  trap 'rm -f "$TMPFILE"' EXIT
  
  curl -s -f \
    -H "X-Figma-Token: $FIGMA_TOKEN" \
    "https://api.figma.com/v1/files/${FILE_KEY}/nodes?ids=${NODE_ID}" \
    -o "$TMPFILE"
  
  # Extract node IDs with image fills
  NODE_IDS=$(python3 - "$TMPFILE" <<'PYEOF'
import json, sys

def find_image_nodes(node, results):
    """Recursively find nodes with image fills"""
    node_id = node.get('id', '')
    fills = node.get('fills', [])
    
    for fill in fills:
        if fill.get('type') == 'IMAGE':
            results.append(node_id)
            break
    
    for child in node.get('children', []):
        find_image_nodes(child, results)

with open(sys.argv[1]) as f:
    data = json.load(f)

results = []
for node_id, node_data in data.get('nodes', {}).items():
    doc = node_data.get('document', {})
    find_image_nodes(doc, results)

print(','.join(results))
PYEOF
)
  
  if [[ -z "$NODE_IDS" ]]; then
    echo "No image fills found in subtree"
    exit 0
  fi
  
  echo "Found image nodes: $NODE_IDS"
fi

# ── Normalize node IDs ───────────────────────────────────────────────────────
NODE_IDS="${NODE_IDS//-/:}"

# ── Fetch image URLs ─────────────────────────────────────────────────────────
echo "Requesting ${FORMAT} exports at scale ${SCALE}..."

RESPONSE=$(curl -s -f \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/images/${FILE_KEY}?ids=${NODE_IDS}&format=${FORMAT}&scale=${SCALE}")

# ── Download images ──────────────────────────────────────────────────────────
python3 - "$RESPONSE" "$OUTPUT" "$FORMAT" <<'PYEOF'
import json, sys, urllib.request, os

response = json.loads(sys.argv[1])
output_dir = sys.argv[2]
fmt = sys.argv[3]

images = response.get('images', {})
if not images:
    print("No images returned")
    sys.exit(0)

for node_id, url in images.items():
    if url is None:
        print(f"  ✗ {node_id}: No image available")
        continue
    
    # Sanitize filename
    safe_id = node_id.replace(':', '-')
    filename = f"{safe_id}.{fmt}"
    filepath = os.path.join(output_dir, filename)
    
    try:
        urllib.request.urlretrieve(url, filepath)
        print(f"  ✓ {filepath}")
    except Exception as e:
        print(f"  ✗ {node_id}: {e}")

print(f"\nExported to {output_dir}/")
PYEOF
