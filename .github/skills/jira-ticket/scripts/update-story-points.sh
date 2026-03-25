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

: "${JIRA_TOKEN:?JIRA_TOKEN environment variable is required}"
: "${JIRA_BASE_URL:?JIRA_BASE_URL environment variable is required}"
: "${JIRA_EMAIL:?JIRA_EMAIL environment variable is required}"

if [[ -z "$ISSUE_KEY" ]]; then
  echo "Error: --issue-key is required" >&2; exit 1
fi
if [[ -z "$STORY_POINTS" ]]; then
  echo "Error: --story-points is required" >&2; exit 1
fi

PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({'fields': {sys.argv[1]: float(sys.argv[2])}}))
" "$FIELD_ID" "$STORY_POINTS")

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X PUT \
  -H "Content-Type: application/json" \
  -u "${JIRA_EMAIL}:${JIRA_TOKEN}" \
  --data "$PAYLOAD" \
  "${JIRA_BASE_URL}/rest/api/3/issue/${ISSUE_KEY}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | awk 'NR>1{print prev} {prev=$0}')

if [[ "$HTTP_CODE" != "204" ]]; then
  echo "Error: Jira API returned HTTP $HTTP_CODE" >&2
  echo "$BODY" >&2
  exit 1
fi

echo "Updated ${ISSUE_KEY}: story points set to ${STORY_POINTS}"
echo "URL: ${JIRA_BASE_URL}/browse/${ISSUE_KEY}"
