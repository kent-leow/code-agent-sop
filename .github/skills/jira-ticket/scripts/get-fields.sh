#!/usr/bin/env bash
# get-fields.sh — Discover custom field IDs in your Jira instance
# Useful to find the correct story points field ID before creating tickets.

set -euo pipefail

: "${JIRA_TOKEN:?JIRA_TOKEN environment variable is required}"
: "${JIRA_BASE_URL:?JIRA_BASE_URL environment variable is required}"
: "${JIRA_EMAIL:?JIRA_EMAIL environment variable is required}"

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Accept: application/json" \
  -u "${JIRA_EMAIL}:${JIRA_TOKEN}" \
  "${JIRA_BASE_URL}/rest/api/3/field")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Error: Jira API returned HTTP $HTTP_CODE" >&2
  echo "$BODY" >&2
  exit 1
fi

echo "=== Fields matching 'story', 'point', or 'sp' ==="
echo "$BODY" | python3 -c "
import json, sys
fields = json.load(sys.stdin)
matches = [f for f in fields if any(
    kw in (f.get('name','') + f.get('id','')).lower()
    for kw in ['story', 'point', ' sp']
)]
if not matches:
    print('No matching fields found. Listing all custom fields:')
    matches = [f for f in fields if f.get('custom', False)]
for f in matches:
    print(f\"{f['id']:30s}  {f['name']}\")
"
