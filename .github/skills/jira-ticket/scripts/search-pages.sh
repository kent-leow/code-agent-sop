#!/usr/bin/env bash
# search-pages.sh — Search Confluence by CQL (read-only); one line per hit: page id | space | last modified | title, then excerpt
# Usage: bash search-pages.sh --cql 'type = page AND text ~ "APEX onboarding"' [--limit 10] [--json]
#        bash search-pages.sh --text "APEX onboarding" [--space MOLBLT]   (builds the CQL for you)

set -euo pipefail

CQL=""
TEXT=""
SPACE=""
LIMIT=10
JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cql)   CQL="$2"; shift 2 ;;
    --text)  TEXT="$2"; shift 2 ;;
    --space) SPACE="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --json)  JSON=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

source "$(dirname "${BASH_SOURCE[0]}")/_http.sh"
[[ "$LIMIT" =~ ^[0-9]+$ && "$LIMIT" -ge 1 && "$LIMIT" -le 50 ]] || { echo "Error: --limit must be 1-50" >&2; exit 1; }
if [[ -z "$CQL" ]]; then
  [[ -n "$TEXT" ]] || { echo "Error: --cql or --text is required" >&2; exit 1; }
  CQL="type = page AND text ~ \"${TEXT//\"/\\\"}\""
  [[ -z "$SPACE" ]] || CQL="${CQL} AND space = \"${SPACE}\""
  CQL="${CQL} ORDER BY lastmodified DESC"
fi

TMPFILE=$(mktemp "$TMPDIR/confluence_search_XXXXXX")
trap 'rm -f "$TMPFILE"' EXIT
jira_request GET 200 "/wiki/rest/api/search" -G \
  --data-urlencode "cql=${CQL}" --data-urlencode "limit=${LIMIT}" > "$TMPFILE"

if $JSON; then cat "$TMPFILE"; exit 0; fi
jq -r --arg base "$JIRA_BASE_URL" '
  .results[] |
  "\(.content.id // "-") | \(.resultGlobalContainer.title // "-") | \(.lastModified // "" | .[0:10]) | \(.title | gsub("@@@(end)?hl@@@"; ""))\n    \($base)/wiki\(.url)\n    \(.excerpt // "" | gsub("@@@(end)?hl@@@"; "") | gsub("\\s+"; " ") | .[0:200])"
' "$TMPFILE"
echo "(${LIMIT} max; total matches: $(jq -r '.totalSize // "?"' "$TMPFILE")) — read a hit with get-page.sh --page-id <id>"
