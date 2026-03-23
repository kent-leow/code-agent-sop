#!/usr/bin/env bash
# update-ticket.sh — Update title, description, and/or story points on an existing Jira issue
# Usage: bash update-ticket.sh --issue-key PROJ-123 [--title "..."] [--description "..."] [--story-points N]

set -euo pipefail

ISSUE_KEY=""
TITLE=""
DESCRIPTION=""
STORY_POINTS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue-key)    ISSUE_KEY="$2";    shift 2 ;;
    --title)        TITLE="$2";        shift 2 ;;
    --description)  DESCRIPTION="$2";  shift 2 ;;
    --story-points) STORY_POINTS="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

: "${JIRA_TOKEN:?JIRA_TOKEN environment variable is required}"
: "${JIRA_BASE_URL:?JIRA_BASE_URL environment variable is required}"
: "${JIRA_EMAIL:?JIRA_EMAIL environment variable is required}"

if [[ -z "$ISSUE_KEY" ]]; then
  echo "Error: --issue-key is required" >&2; exit 1
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
  DESCRIPTION_JSON=""
fi

# ── Build JSON payload ────────────────────────────────────────────────────────
PAYLOAD=$(python3 -c "
import json, sys
title         = sys.argv[1]
story_points  = sys.argv[2]
description   = sys.argv[3]

fields = {}

if title:
    fields['summary'] = title

if story_points:
    fields['customfield_10016'] = float(story_points)

if description:
    fields['description'] = json.loads(description)

print(json.dumps({'fields': fields}))
" "$TITLE" "$STORY_POINTS" "$DESCRIPTION_JSON")

# ── Call Jira API ─────────────────────────────────────────────────────────────
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

echo "Updated: $ISSUE_KEY"
echo "URL: ${JIRA_BASE_URL}/browse/${ISSUE_KEY}"
