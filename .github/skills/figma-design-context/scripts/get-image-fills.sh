#!/usr/bin/env bash
# get-image-fills.sh — Get URLs to original uploaded images in a file
# Usage: bash get-image-fills.sh --file-key <fileKey> [--output <file.json>]
#
# Returns the original uploaded images (not rendered), useful for:
# - Transferring images between files
# - Getting full-resolution source images
# - Identifying which images are used in a design
#
# Requires: FIGMA_TOKEN set in environment

set -euo pipefail

FILE_KEY=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file-key) FILE_KEY="$2"; shift 2 ;;
    --output)   OUTPUT="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required}"
[[ -z "$FILE_KEY" ]] && { echo "Error: --file-key is required" >&2; exit 1; }

# ── Fetch image fills ────────────────────────────────────────────────────────
RESPONSE=$(curl -s -f \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/${FILE_KEY}/images")

# ── Output ───────────────────────────────────────────────────────────────────
if [[ -n "$OUTPUT" ]]; then
  echo "$RESPONSE" > "$OUTPUT"
  echo "Saved to $OUTPUT"
else
  echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
meta = data.get('meta', {})
images = meta.get('images', {})

if not images:
    print('No image fills found in file')
else:
    print(f'Found {len(images)} image(s):\n')
    for ref, url in images.items():
        print(f'  {ref}:')
        print(f'    {url}\n')
"
fi
