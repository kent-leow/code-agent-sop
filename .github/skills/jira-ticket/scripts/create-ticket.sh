#!/usr/bin/env bash
# create-ticket.sh — Create a Jira issue via REST API v3
# Usage: bash create-ticket.sh --title "..." [--description "..."] [--issue-type Story] [--story-points N] [--parent PROJ-42]

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
TITLE=""
DESCRIPTION=""
ISSUE_TYPE="Story"
STORY_POINTS=""
PARENT_KEY=""

# ── Arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)        TITLE="$2";         shift 2 ;;
    --description)  DESCRIPTION="$2";   shift 2 ;;
    --issue-type)   ISSUE_TYPE="$2";    shift 2 ;;
    --story-points) STORY_POINTS="$2";  shift 2 ;;
    --parent)       PARENT_KEY="$2";    shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate required env vars ────────────────────────────────────────────────
: "${JIRA_TOKEN:?JIRA_TOKEN environment variable is required}"
: "${JIRA_BASE_URL:?JIRA_BASE_URL environment variable is required (e.g. https://your-org.atlassian.net)}"
: "${JIRA_PROJECT_KEY:?JIRA_PROJECT_KEY environment variable is required (e.g. PROJ)}"
: "${JIRA_EMAIL:?JIRA_EMAIL environment variable is required}"

if [[ -z "$TITLE" ]]; then
  echo "Error: --title is required" >&2
  exit 1
fi

# ── Build description ADF block ───────────────────────────────────────────────
if [[ -n "$DESCRIPTION" ]]; then
  DESCRIPTION_JSON=$(python3 -c "
import json, sys
text = sys.argv[1]
adf = {
  'type': 'doc',
  'version': 1,
  'content': [{'type': 'paragraph', 'content': [{'type': 'text', 'text': text}]}]
}
print(json.dumps(adf))
" "$DESCRIPTION")
else
  DESCRIPTION_JSON='{"type":"doc","version":1,"content":[]}'
fi

# ── Build JSON payload ────────────────────────────────────────────────────────
FIELDS=$(python3 -c "
import json, sys
project_key   = sys.argv[1]
title         = sys.argv[2]
issue_type    = sys.argv[3]
story_points  = sys.argv[4]
parent_key    = sys.argv[5]
description   = json.loads(sys.argv[6])

fields = {
    'project':     {'key': project_key},
    'summary':     title,
    'issuetype':   {'name': issue_type},
    'description': description,
}

if story_points:
    fields['customfield_10016'] = float(story_points)

if parent_key:
    fields['parent'] = {'key': parent_key}

print(json.dumps({'fields': fields}))
" "$JIRA_PROJECT_KEY" "$TITLE" "$ISSUE_TYPE" "$STORY_POINTS" "$PARENT_KEY" "$DESCRIPTION_JSON")

# ── Call Jira API ─────────────────────────────────────────────────────────────
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -u "${JIRA_EMAIL}:${JIRA_TOKEN}" \
  --data "$FIELDS" \
  "${JIRA_BASE_URL}/rest/api/3/issue")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [[ "$HTTP_CODE" != "201" ]]; then
  echo "Error: Jira API returned HTTP $HTTP_CODE" >&2
  echo "$BODY" >&2
  exit 1
fi

ISSUE_KEY=$(echo "$BODY" | python3 -c "import json,sys; print(json.load(sys.stdin)['key'])")
echo "Created: $ISSUE_KEY"
echo "URL: ${JIRA_BASE_URL}/browse/${ISSUE_KEY}"
