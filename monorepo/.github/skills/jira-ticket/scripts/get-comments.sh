#!/usr/bin/env bash
# get-comments.sh — Retrieve comments for a Jira issue (inline images downloaded to /tmp/jira-images/<KEY>/)
# Usage: bash get-comments.sh --issue-key PROJ-123 [--max-results 50] [--order-by created|-created]

set -euo pipefail

ISSUE_KEY=""
MAX_RESULTS=50
ORDER_BY="created"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue-key)    ISSUE_KEY="$2";    shift 2 ;;
    --max-results)  MAX_RESULTS="$2";  shift 2 ;;
    --order-by)     ORDER_BY="$2";     shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

source "$(dirname "${BASH_SOURCE[0]}")/_http.sh"
require_issue_key "$ISSUE_KEY"
[[ "$MAX_RESULTS" =~ ^[0-9]+$ ]] || { echo "Error: --max-results must be a number" >&2; exit 1; }
[[ "$ORDER_BY" == "created" || "$ORDER_BY" == "-created" ]] || { echo "Error: --order-by must be 'created' or '-created'" >&2; exit 1; }

WORK=$(mktemp -d "$TMPDIR/jira_comments_XXXXXX")
trap 'rm -rf "$WORK"' EXIT

jira_request GET 200 "/rest/api/3/issue/${ISSUE_KEY}/comment?maxResults=${MAX_RESULTS}&orderBy=${ORDER_BY}" > "$WORK/comments.json"
jira_request GET 200 "/rest/api/3/issue/${ISSUE_KEY}?fields=attachment" > "$WORK/attach.json"

python3 "$SCRIPTS_DIR/_render.py" comments "$WORK/comments.json"

IMG_DIR="/tmp/jira-images/${ISSUE_KEY}"
DOWNLOADED=()
while IFS=$'\t' read -r name url; do
  [[ -z "$name" ]] && continue
  mkdir -p "$IMG_DIR"
  if jira_download "$url" "$IMG_DIR/$name"; then DOWNLOADED+=("$IMG_DIR/$name"); else echo "Warning: failed to download $name" >&2; fi
done < <(python3 "$SCRIPTS_DIR/_render.py" media "$WORK/comments.json" "$WORK/attach.json")

if [[ ${#DOWNLOADED[@]} -gt 0 ]]; then
  echo "=== Downloaded ${#DOWNLOADED[@]} inline image(s) to ${IMG_DIR} ==="
  printf '%s\n' "${DOWNLOADED[@]}"
fi
