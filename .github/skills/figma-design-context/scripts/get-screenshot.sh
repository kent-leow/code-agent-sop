#!/usr/bin/env bash
# get-screenshot.sh — Download a rendered PNG screenshot of a Figma node
# Usage: bash get-screenshot.sh --file-key <fileKey> --node-id <nodeId> [--scale 2] [--output ./figma-screenshot.png] [--max-dimension 7900]
#
# Accepts node IDs in both API format (2313:102848) and URL format (2313-102848)
# Requires: FIGMA_TOKEN set in environment (see SKILL.md for setup)
#
# Large frames: automatically resizes to --max-dimension (default 7900) using sips
# to stay within Claude's 8000px per-side image limit.

set -euo pipefail

FILE_KEY=""
NODE_ID=""
SCALE="2"
OUTPUT="./figma-screenshot.png"
MAX_DIM="7900"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file-key)       FILE_KEY="$2";  shift 2 ;;
    --node-id)        NODE_ID="$2";   shift 2 ;;
    --scale)          SCALE="$2";     shift 2 ;;
    --output)         OUTPUT="$2";    shift 2 ;;
    --max-dimension)  MAX_DIM="$2";   shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ────────────────────────────────────────────────────────────────
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required. See SKILL.md#credential-setup}"
[[ -z "$FILE_KEY" ]] && { echo "Error: --file-key is required" >&2; exit 1; }
[[ -z "$NODE_ID" ]]  && { echo "Error: --node-id is required" >&2; exit 1; }

# ── Normalise node ID: accept URL-style dashes (2313-102848) or colons ───────
# URL format: 2313-102848  →  API format: 2313:102848
# Only replace the separator hyphen (between two integer segments)
NORMALISED_NODE_ID=$(echo "$NODE_ID" | python3 -c "
import sys, re
raw = sys.stdin.read().strip()
# Convert URL separator format to API colon format if not already colon-separated
# Pattern: digits-digits (not already containing a colon)
if ':' not in raw:
    raw = re.sub(r'^(\d+)-(\d+)$', r'\1:\2', raw)
print(raw)
")

# URL-encode colon → %3A for query parameter
ENCODED_NODE_ID="${NORMALISED_NODE_ID//:/%3A}"

echo "Requesting screenshot for node: $NORMALISED_NODE_ID (scale: ${SCALE}x)"

# ── Fetch the pre-signed image URL from Figma ────────────────────────────────
RESPONSE=$(curl -s -f \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/images/${FILE_KEY}?ids=${ENCODED_NODE_ID}&format=png&scale=${SCALE}")

# ── Extract the download URL and download image ───────────────────────────────
IMAGE_URL=$(echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data.get('err'):
    print(f\"Figma API error: {data['err']}\", file=sys.stderr)
    sys.exit(1)
images = data.get('images', {})
if not images:
    print('Error: No images returned. Check --node-id is correct.', file=sys.stderr)
    sys.exit(1)
url = list(images.values())[0]
if url is None:
    print('Error: Figma returned null for the image URL. Node may be invisible or off-canvas.', file=sys.stderr)
    sys.exit(1)
print(url)
")

echo "Downloading image..."
curl -s -L -o "$OUTPUT" "$IMAGE_URL"
echo "Screenshot saved to: $OUTPUT"

# ── Auto-resize if image exceeds Claude's 8000px-per-side limit ──────────────
if command -v sips &>/dev/null; then
  DIMS=$(sips -g pixelWidth -g pixelHeight "$OUTPUT" 2>/dev/null | awk '/pixel(Width|Height)/{print $2}')
  IMG_W=$(echo "$DIMS" | head -1)
  IMG_H=$(echo "$DIMS" | tail -1)
  if [[ -n "$IMG_W" && -n "$IMG_H" ]]; then
    echo "Image dimensions: ${IMG_W}x${IMG_H}"
    if [[ "$IMG_W" -gt "$MAX_DIM" || "$IMG_H" -gt "$MAX_DIM" ]]; then
      echo "Exceeds ${MAX_DIM}px limit — resizing proportionally..."
      sips -Z "$MAX_DIM" "$OUTPUT" --out "$OUTPUT" >/dev/null 2>&1
      AFTER=$(sips -g pixelWidth -g pixelHeight "$OUTPUT" 2>/dev/null | awk '/pixel(Width|Height)/{print $2}')
      NEW_W=$(echo "$AFTER" | head -1)
      NEW_H=$(echo "$AFTER" | tail -1)
      echo "Resized to ${NEW_W}x${NEW_H}"
    fi
  fi
else
  echo "Note: sips not found — skipping dimension check. If view_image fails with an 8000px error, re-run with --scale 1 or --max-dimension."
fi

echo "Use the view_image tool to view it: view_image $OUTPUT"
