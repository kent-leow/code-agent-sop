#!/usr/bin/env bash
# update-story-points.sh — Update story points on an existing Jira issue
# Usage: bash update-story-points.sh --issue-key PROJ-123 --story-points 5

set -euo pipefail

ISSUE_KEY=""
STORY_POINTS=""
FIELD_ID="customfield_10274"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue-key)    ISSUE_KEY="$2";    shift 2 ;;
    --story-points) STORY_POINTS="$2"; shift 2 ;;
    --field-id)     FIELD_ID="$2";     shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

source "$(dirname "${BASH_SOURCE[0]}")/_http.sh"

require_issue_key "$ISSUE_KEY"
if [[ -z "$STORY_POINTS" ]]; then
  echo "Error: --story-points is required" >&2; exit 1
fi

PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({'fields': {sys.argv[1]: float(sys.argv[2])}}))
" "$FIELD_ID" "$STORY_POINTS")

jira_request PUT 204 "/rest/api/3/issue/${ISSUE_KEY}" \
  -H "Content-Type: application/json" --data "$PAYLOAD" >/dev/null

echo "Updated ${ISSUE_KEY}: story points set to ${STORY_POINTS}"
echo "URL: ${JIRA_BASE_URL}/browse/${ISSUE_KEY}"
