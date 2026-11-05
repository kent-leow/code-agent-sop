#!/usr/bin/env bash
# get-fields.sh — Discover custom field IDs in your Jira instance
# Useful to find the correct story points field ID before creating tickets.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/_http.sh"

BODY=$(jira_request GET 200 "/rest/api/3/field")

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
