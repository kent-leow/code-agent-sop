#!/usr/bin/env bash
# get-issue.sh — Read a Jira issue as text: summary, type, status, labels, links, description (ADF → text), comments
# Usage: bash get-issue.sh --issue-key PROJ-123 [--no-comments] [--json]

set -euo pipefail

ISSUE_KEY=""
FIELDS="summary,issuetype,status,assignee,labels,parent,subtasks,issuelinks,attachment,description,comment"
JSON=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue-key)   ISSUE_KEY="$2"; shift 2 ;;
    --no-comments) FIELDS="${FIELDS%,comment}"; shift ;;
    --json)        JSON=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

source "$(dirname "${BASH_SOURCE[0]}")/_http.sh"
require_issue_key "$ISSUE_KEY"

TMPFILE=$(mktemp "$TMPDIR/jira_issue_XXXXXX")
trap 'rm -f "$TMPFILE"' EXIT
jira_request GET 200 "/rest/api/3/issue/${ISSUE_KEY}?fields=${FIELDS}" > "$TMPFILE"

if $JSON; then cat "$TMPFILE"; else python3 "$SCRIPTS_DIR/_render.py" issue "$TMPFILE"; fi
echo
echo "URL: ${JIRA_BASE_URL}/browse/${ISSUE_KEY}"
