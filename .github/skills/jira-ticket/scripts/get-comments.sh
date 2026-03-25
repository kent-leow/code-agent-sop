#!/usr/bin/env bash
# get-comments.sh — Retrieve comments for a Jira issue via REST API v3
# Usage: bash get-comments.sh --issue-key PROJ-123 [--max-results 50] [--order-by created]

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
ISSUE_KEY=""
MAX_RESULTS=50
ORDER_BY="created"

# ── Arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue-key)    ISSUE_KEY="$2";    shift 2 ;;
    --max-results)  MAX_RESULTS="$2";  shift 2 ;;
    --order-by)     ORDER_BY="$2";    shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate required env vars ────────────────────────────────────────────────
: "${JIRA_TOKEN:?JIRA_TOKEN environment variable is required}"
: "${JIRA_BASE_URL:?JIRA_BASE_URL environment variable is required (e.g. https://your-org.atlassian.net)}"
: "${JIRA_EMAIL:?JIRA_EMAIL environment variable is required}"

if [[ -z "$ISSUE_KEY" ]]; then
  echo "Error: --issue-key is required (e.g. GOBIZWKST2-324)" >&2
  exit 1
fi

# ── Validate ORDER_BY ─────────────────────────────────────────────────────────
if [[ "$ORDER_BY" != "created" && "$ORDER_BY" != "-created" ]]; then
  echo "Error: --order-by must be 'created' (ascending) or '-created' (descending)" >&2
  exit 1
fi

# ── Fetch comments ────────────────────────────────────────────────────────────
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Accept: application/json" \
  -u "${JIRA_EMAIL}:${JIRA_TOKEN}" \
  "${JIRA_BASE_URL}/rest/api/3/issue/${ISSUE_KEY}/comment?maxResults=${MAX_RESULTS}&orderBy=${ORDER_BY}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | awk 'NR>1{print prev} {prev=$0}')

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Error: Jira API returned HTTP $HTTP_CODE" >&2
  echo "$BODY" >&2
  exit 1
fi

# ── Fetch issue attachments (for inline image resolution) ─────────────────────
ATTACH_RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Accept: application/json" \
  -u "${JIRA_EMAIL}:${JIRA_TOKEN}" \
  "${JIRA_BASE_URL}/rest/api/3/issue/${ISSUE_KEY}?fields=attachment")

ATTACH_HTTP=$(echo "$ATTACH_RESPONSE" | tail -n1)
ATTACH_BODY=$(echo "$ATTACH_RESPONSE" | awk 'NR>1{print prev} {prev=$0}')

# ── Download inline images to temp dir ───────────────────────────────────────
IMG_DIR="/tmp/jira-images/${ISSUE_KEY}"
mkdir -p "$IMG_DIR"

IMAGE_PATHS=$(python3 -c "
import json, sys, os, re, subprocess

attach_data = json.loads('''${ATTACH_BODY}''')
attachments = attach_data.get('fields', {}).get('attachment', [])

# Build filename -> content URL map
filename_to_url = {}
for a in attachments:
    if a.get('mimeType', '').startswith('image/'):
        filename_to_url[a['filename']] = a['content']

comment_data = json.loads(sys.stdin.read())
comments = comment_data.get('comments', [])

downloaded = []

def collect_media(node):
    results = []
    if node.get('type') in ('media', 'mediaInline') and node.get('attrs', {}).get('type') == 'file':
        results.append(node['attrs'])
    for child in node.get('content', []):
        results.extend(collect_media(child))
    return results

seen_ids = set()
for comment in comments:
    body = comment.get('body', {})
    if not isinstance(body, dict):
        continue
    for media_attrs in collect_media(body):
        media_id = media_attrs.get('id', '')
        alt = media_attrs.get('alt', '')
        if media_id in seen_ids:
            continue
        seen_ids.add(media_id)
        url = filename_to_url.get(alt)
        if not url:
            continue
        safe_name = re.sub(r'[^\w.\- ]', '_', alt)
        dest = os.path.join('${IMG_DIR}', safe_name)
        result = subprocess.run(
            ['curl', '-s', '-L', '-o', dest,
             '-u', os.environ['JIRA_EMAIL'] + ':' + os.environ['JIRA_TOKEN'],
             url],
            capture_output=True
        )
        if result.returncode == 0:
            downloaded.append(dest)

print('\n'.join(downloaded))
" <<< "$BODY")

# ── Pretty-print comments ─────────────────────────────────────────────────────
echo "$BODY" | python3 -c "
import json, sys

def extract_text(node, depth=0):
    '''Recursively extract plain text from an ADF node, noting image placeholders.'''
    ntype = node.get('type', '')
    if ntype == 'text':
        return node.get('text', '')
    if ntype in ('media', 'mediaInline') and node.get('attrs', {}).get('type') == 'file':
        alt = node.get('attrs', {}).get('alt', 'image')
        return f'[image: {alt}]'
    children = node.get('content', [])
    parts = [extract_text(c, depth+1) for c in children]
    block_types = {'paragraph', 'heading', 'bulletList', 'orderedList', 'listItem', 'codeBlock', 'blockquote', 'mediaSingle', 'panel'}
    sep = '\n' if ntype in block_types else ''
    return sep.join(parts) + sep

data = json.load(sys.stdin)
comments = data.get('comments', [])
total = data.get('total', 0)

print(f'=== Comments for issue ({total} total, showing {len(comments)}) ===\n')

for i, comment in enumerate(comments, 1):
    author = comment.get('author', {}).get('displayName', 'Unknown')
    created = comment.get('created', '')[:10]
    updated = comment.get('updated', '')[:10]
    comment_id = comment.get('id', '')

    body = comment.get('body', {})
    if isinstance(body, dict):
        text = extract_text(body).strip()
    else:
        text = str(body).strip()

    edited = ' (edited)' if created != updated else ''
    print(f'[{i}] {author} — {created}{edited}  (id: {comment_id})')
    print('-' * 60)
    print(text)
    print()
"

# ── Report downloaded images ──────────────────────────────────────────────────
if [[ -n "$IMAGE_PATHS" ]]; then
  IMG_COUNT=$(echo "$IMAGE_PATHS" | wc -l | tr -d ' ')
  echo "=== Downloaded ${IMG_COUNT} inline image(s) to ${IMG_DIR} ==="
  echo "$IMAGE_PATHS"
fi
