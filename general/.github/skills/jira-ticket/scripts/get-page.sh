#!/usr/bin/env bash
# get-page.sh — Read a Confluence page (same Atlassian credentials) as text with version metadata
# Usage: bash get-page.sh --page-id 283475666 | --url "<confluence page URL>" [--json]

set -euo pipefail

PAGE_ID=""
JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --page-id) PAGE_ID="$2"; shift 2 ;;
    --url)     [[ "$2" =~ /pages/([0-9]+) || "$2" =~ pageId=([0-9]+) ]] && PAGE_ID="${BASH_REMATCH[1]}"; shift 2 ;;
    --json)    JSON=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

source "$(dirname "${BASH_SOURCE[0]}")/_http.sh"
[[ "$PAGE_ID" =~ ^[0-9]+$ ]] || { echo "Error: --page-id (numeric) or a --url containing /pages/<id> is required" >&2; exit 1; }

TMPFILE=$(mktemp "$TMPDIR/confluence_page_XXXXXX")
trap 'rm -f "$TMPFILE"' EXIT
jira_request GET 200 "/wiki/rest/api/content/${PAGE_ID}?expand=body.storage,version,space" > "$TMPFILE"

if $JSON; then cat "$TMPFILE"; else python3 "$SCRIPTS_DIR/_render.py" page "$TMPFILE"; fi
