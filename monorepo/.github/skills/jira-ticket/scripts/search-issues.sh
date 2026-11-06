#!/usr/bin/env bash
# search-issues.sh — Search Jira issues by JQL (read-only); one line per issue: KEY | type | status | updated | summary
# Usage: bash search-issues.sh --jql 'project = MOLBLT AND text ~ "status push" ORDER BY updated DESC' [--max-results 20] [--json]

set -euo pipefail

JQL=""
MAX=20
JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --jql)         JQL="$2"; shift 2 ;;
    --max-results) MAX="$2"; shift 2 ;;
    --json)        JSON=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

source "$(dirname "${BASH_SOURCE[0]}")/_http.sh"
[[ -n "$JQL" ]] || { echo "Error: --jql is required" >&2; exit 1; }
[[ "$MAX" =~ ^[0-9]+$ && "$MAX" -ge 1 && "$MAX" -le 100 ]] || { echo "Error: --max-results must be 1-100" >&2; exit 1; }

TMPFILE=$(mktemp "$TMPDIR/jira_search_XXXXXX")
trap 'rm -f "$TMPFILE"' EXIT
jira_request GET 200 "/rest/api/3/search/jql" -G \
  --data-urlencode "jql=${JQL}" \
  --data-urlencode "fields=summary,status,issuetype,updated,labels" \
  --data-urlencode "maxResults=${MAX}" > "$TMPFILE"

if $JSON; then cat "$TMPFILE"; exit 0; fi
jq -r --arg base "$JIRA_BASE_URL" '
  .issues[] | [ .key, .fields.issuetype.name, .fields.status.name, (.fields.updated // "" | .[0:10]), .fields.summary ] | join(" | ")
' "$TMPFILE"
[[ "$(jq -r '.isLast // true' "$TMPFILE")" == "true" ]] || echo "(more results — narrow the JQL or raise --max-results)"
