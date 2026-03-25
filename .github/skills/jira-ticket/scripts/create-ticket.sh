#!/usr/bin/env bash
# create-ticket.sh — Create a Jira issue via REST API v3
# Usage: bash create-ticket.sh --title "..." [--description "..."] [--issue-type Story] [--story-points N] [--parent PROJ-42] [--assignee <accountId>]

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
TITLE=""
DESCRIPTION=""
ISSUE_TYPE="Story"
STORY_POINTS=""
PARENT_KEY=""
ASSIGNEE_ID="${JIRA_ASSIGNEE_ACCOUNT_ID:-}"

# ── Arg parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)        TITLE="$2";         shift 2 ;;
    --description)  DESCRIPTION="$2";   shift 2 ;;
    --issue-type)   ISSUE_TYPE="$2";    shift 2 ;;
    --story-points) STORY_POINTS="$2";  shift 2 ;;
    --parent)       PARENT_KEY="$2";    shift 2 ;;
    --assignee)     ASSIGNEE_ID="$2";   shift 2 ;;
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

# ── Build description ADF block (converts Markdown → ADF) ────────────────────
if [[ -n "$DESCRIPTION" ]]; then
  DESCRIPTION_JSON=$(python3 -c "
import json, sys, re

def inline_nodes(text):
    nodes = []
    pattern = re.compile(r'\*\*(.+?)\*\*|\*(.+?)\*|\`(.+?)\`')
    pos = 0
    for m in pattern.finditer(text):
        if m.start() > pos:
            nodes.append({'type': 'text', 'text': text[pos:m.start()]})
        if m.group(1) is not None:
            nodes.append({'type': 'text', 'text': m.group(1), 'marks': [{'type': 'strong'}]})
        elif m.group(2) is not None:
            nodes.append({'type': 'text', 'text': m.group(2), 'marks': [{'type': 'em'}]})
        elif m.group(3) is not None:
            nodes.append({'type': 'text', 'text': m.group(3), 'marks': [{'type': 'code'}]})
        pos = m.end()
    if pos < len(text):
        nodes.append({'type': 'text', 'text': text[pos:]})
    return nodes if nodes else [{'type': 'text', 'text': text}]

def md_to_adf(text):
    lines = text.splitlines()
    content = []
    i = 0
    while i < len(lines):
        line = lines[i]
        # Fenced code block
        code_match = re.match(r'^\`\`\`(\w*)', line)
        if code_match:
            lang = code_match.group(1) or 'text'
            code_lines = []
            i += 1
            while i < len(lines) and not lines[i].startswith('\`\`\`'):
                code_lines.append(lines[i])
                i += 1
            i += 1
            content.append({'type': 'codeBlock', 'attrs': {'language': lang}, 'content': [{'type': 'text', 'text': '\n'.join(code_lines)}]})
            continue
        # Heading
        hm = re.match(r'^(#{1,6})\s+(.*)', line)
        if hm:
            content.append({'type': 'heading', 'attrs': {'level': len(hm.group(1))}, 'content': inline_nodes(hm.group(2))})
            i += 1
            continue
        # Table
        if re.match(r'^\|', line.strip()):
            rows = []
            is_header = True
            while i < len(lines) and re.match(r'^\|', lines[i].strip()):
                row = lines[i].strip()
                if re.match(r'^\|[-| :]+\|$', row):
                    i += 1
                    continue
                cells = [c.strip() for c in row.strip('|').split('|')]
                row_nodes = [{'type': 'tableHeader' if is_header else 'tableCell', 'attrs': {}, 'content': [{'type': 'paragraph', 'content': inline_nodes(c)}]} for c in cells]
                rows.append({'type': 'tableRow', 'content': row_nodes})
                is_header = False
                i += 1
            if rows:
                content.append({'type': 'table', 'attrs': {'isNumberColumnEnabled': False, 'layout': 'default'}, 'content': rows})
            continue
        # Bullet list
        if re.match(r'^[-*]\s+', line):
            items = []
            while i < len(lines) and re.match(r'^[-*]\s+', lines[i]):
                items.append({'type': 'listItem', 'content': [{'type': 'paragraph', 'content': inline_nodes(re.sub(r'^[-*]\s+', '', lines[i]))}]})
                i += 1
            content.append({'type': 'bulletList', 'content': items})
            continue
        # Ordered list
        if re.match(r'^\d+\.\s+', line):
            items = []
            while i < len(lines) and re.match(r'^\d+\.\s+', lines[i]):
                items.append({'type': 'listItem', 'content': [{'type': 'paragraph', 'content': inline_nodes(re.sub(r'^\d+\.\s+', '', lines[i]))}]})
                i += 1
            content.append({'type': 'orderedList', 'content': items})
            continue
        # Blockquote
        if re.match(r'^>\s?', line):
            quote_lines = []
            while i < len(lines) and re.match(r'^>\s?', lines[i]):
                quote_lines.append(re.sub(r'^>\s?', '', lines[i]))
                i += 1
            content.append({'type': 'blockquote', 'content': [{'type': 'paragraph', 'content': inline_nodes(' '.join(quote_lines))}]})
            continue
        # Empty line
        if not line.strip():
            i += 1
            continue
        # Paragraph
        content.append({'type': 'paragraph', 'content': inline_nodes(line)})
        i += 1
    return {'type': 'doc', 'version': 1, 'content': content}

print(json.dumps(md_to_adf(sys.argv[1])))
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
assignee_id   = sys.argv[7]

fields = {
    'project':     {'key': project_key},
    'summary':     title,
    'issuetype':   {'name': issue_type},
    'description': description,
}

if story_points:
    fields['customfield_10274'] = float(story_points)

if parent_key:
    fields['parent'] = {'key': parent_key}

if assignee_id:
    fields['assignee'] = {'accountId': assignee_id}

print(json.dumps({'fields': fields}))
" "$JIRA_PROJECT_KEY" "$TITLE" "$ISSUE_TYPE" "$STORY_POINTS" "$PARENT_KEY" "$DESCRIPTION_JSON" "$ASSIGNEE_ID")

# ── Call Jira API ─────────────────────────────────────────────────────────────
RESPONSE=$(curl -s -w "\n%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -u "${JIRA_EMAIL}:${JIRA_TOKEN}" \
  --data "$FIELDS" \
  "${JIRA_BASE_URL}/rest/api/3/issue")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | awk 'NR>1{print prev} {prev=$0}')

if [[ "$HTTP_CODE" != "201" ]]; then
  echo "Error: Jira API returned HTTP $HTTP_CODE" >&2
  echo "$BODY" >&2
  exit 1
fi

ISSUE_KEY=$(echo "$BODY" | python3 -c "import json,sys; print(json.load(sys.stdin)['key'])")
echo "Created: $ISSUE_KEY"
echo "URL: ${JIRA_BASE_URL}/browse/${ISSUE_KEY}"
