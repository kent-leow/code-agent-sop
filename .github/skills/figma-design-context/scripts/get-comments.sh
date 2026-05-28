#!/usr/bin/env bash
# get-comments.sh — Fetch all design comments and annotations from a Figma file
# Usage: bash get-comments.sh --file-key <fileKey> [--output ./figma-comments.json]
#
# Covers: GET /v1/files/{fileKey}/comments
# Useful for reading designer annotations, handoff notes, and review threads
# attached to specific nodes on the canvas.
# Requires: FIGMA_TOKEN set in environment (see SKILL.md for setup)

set -euo pipefail

FILE_KEY=""
OUTPUT="./figma-comments.json"

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

TMPFILE=$(mktemp "$TMPDIR/figma_comments_XXXXXX.json")
trap 'rm -f "$TMPFILE"' EXIT

echo "Fetching comments..."

HTTP_STATUS=$(curl -s -w "%{http_code}" \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/${FILE_KEY}/comments" \
  -o "$TMPFILE")

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "Error: Figma API returned HTTP $HTTP_STATUS" >&2
  cat "$TMPFILE" >&2
  exit 1
fi

cp "$TMPFILE" "$OUTPUT"

python3 - "$OUTPUT" <<'PYEOF'
import json, sys
from collections import defaultdict

with open(sys.argv[1]) as f:
    data = json.load(f)

if "err" in data:
    print(f"Figma API error: {data['err']}", file=sys.stderr)
    sys.exit(1)

comments = data.get("comments", [])

if not comments:
    print("No comments found in this file.")
    sys.exit(0)

print(f"Total comments: {len(comments)}")
print()

def extract_text(msg):
    """Handle both plain string and block-list message formats."""
    if isinstance(msg, str):
        return msg
    if isinstance(msg, list):
        parts = []
        for block in msg:
            if isinstance(block, str):
                parts.append(block)
            elif isinstance(block, dict):
                parts.append(block.get("text", ""))
        return "".join(parts)
    return str(msg)

# ── Build thread map ──────────────────────────────────────────────────────────
top_level = [c for c in comments if not c.get("parent_id")]
replies   = defaultdict(list)
for c in comments:
    if c.get("parent_id"):
        replies[c["parent_id"]].append(c)

print(f"DESIGN COMMENTS ({len(top_level)} threads, {len(comments) - len(top_level)} replies)")
print("=" * 60)

for c in sorted(top_level, key=lambda x: x.get("created_at", "")):
    cid    = c.get("id", "?")
    author = c.get("user", {}).get("handle", "unknown")
    date   = (c.get("created_at") or "")[:10]
    text   = extract_text(c.get("message", ""))
    resolved = "  [resolved]" if c.get("resolved_at") else ""

    # Node anchor
    meta    = c.get("client_meta", {})
    node_id = meta.get("node_id", "")
    node_ref = f"  @node:{node_id}" if node_id else ""

    print(f"\n[{date}] @{author}{node_ref}{resolved}")
    print(f"  {text[:300]}")

    for reply in sorted(replies.get(cid, []), key=lambda x: x.get("created_at", "")):
        rauthor  = reply.get("user", {}).get("handle", "unknown")
        rdate    = (reply.get("created_at") or "")[:10]
        rtext    = extract_text(reply.get("message", ""))
        print(f"  ↳ [{rdate}] @{rauthor}: {rtext[:200]}")

print()
PYEOF
