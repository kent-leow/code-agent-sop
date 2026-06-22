#!/usr/bin/env bash
# post-comment.sh — Post a comment to a Figma file
# Usage: bash post-comment.sh --file-key <fileKey> --message "Your comment" [options]
#
# Options:
#   --node-id <nodeId>    Attach comment to specific node
#   --x <number>          X coordinate for positioned comment
#   --y <number>          Y coordinate for positioned comment
#   --frame-offset        Use frame-relative coordinates (with --node-id)
#
# Examples:
#   # General file comment
#   bash post-comment.sh --file-key ABC123 --message "Please review"
#   
#   # Comment on specific node
#   bash post-comment.sh --file-key ABC123 --node-id 1:2 --message "Update this button"
#   
#   # Positioned comment
#   bash post-comment.sh --file-key ABC123 --message "Here" --x 100 --y 200
#
# Requires: FIGMA_TOKEN set in environment (with file_write scope)

set -euo pipefail

FILE_KEY=""
MESSAGE=""
NODE_ID=""
X_POS=""
Y_POS=""
FRAME_OFFSET=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file-key)     FILE_KEY="$2"; shift 2 ;;
    --message)      MESSAGE="$2"; shift 2 ;;
    --node-id)      NODE_ID="$2"; shift 2 ;;
    --x)            X_POS="$2"; shift 2 ;;
    --y)            Y_POS="$2"; shift 2 ;;
    --frame-offset) FRAME_OFFSET=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required}"
[[ -z "$FILE_KEY" ]] && { echo "Error: --file-key is required" >&2; exit 1; }
[[ -z "$MESSAGE" ]] && { echo "Error: --message is required" >&2; exit 1; }

# ── Build request body ───────────────────────────────────────────────────────
BODY=$(python3 - "$MESSAGE" "$NODE_ID" "$X_POS" "$Y_POS" "$FRAME_OFFSET" <<'PYEOF'
import json, sys

message = sys.argv[1]
node_id = sys.argv[2] if sys.argv[2] else None
x = float(sys.argv[3]) if sys.argv[3] else None
y = float(sys.argv[4]) if sys.argv[4] else None
frame_offset = sys.argv[5] == 'true'

body = {"message": message}

# Client meta for positioning
if node_id or (x is not None and y is not None):
    client_meta = {}
    
    if node_id:
        # Convert hyphen to colon format
        client_meta["node_id"] = node_id.replace('-', ':')
        if frame_offset:
            client_meta["node_offset"] = {"x": x or 0, "y": y or 0}
    
    if x is not None and y is not None and not node_id:
        # Absolute canvas position
        client_meta["x"] = x
        client_meta["y"] = y
    
    body["client_meta"] = client_meta

print(json.dumps(body))
PYEOF
)

# ── Post comment ─────────────────────────────────────────────────────────────
RESPONSE=$(curl -s -f \
  -X POST \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$BODY" \
  "https://api.figma.com/v1/files/${FILE_KEY}/comments")

# ── Output ───────────────────────────────────────────────────────────────────
echo "$RESPONSE" | python3 -c "
import json, sys
data = json.load(sys.stdin)

if 'id' in data:
    print(f'✓ Comment posted successfully')
    print(f'  ID: {data.get(\"id\")}')
    print(f'  Message: {data.get(\"message\", \"\")[:50]}')
elif 'err' in data:
    print(f'✗ Error: {data.get(\"err\")}')
else:
    print(json.dumps(data, indent=2))
"
