---
name: jira-ticket
description: "Create/retrieve Jira issues via REST API: tickets, sub-tasks, story points, comments. Requires JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL."
argument-hint: '<title> [description] [story_points] [parent_key]'
---

# jira-ticket

## Prerequisites

- DO: Check vars: `echo $JIRA_TOKEN $JIRA_BASE_URL $JIRA_PROJECT_KEY $JIRA_EMAIL`
- IF: any missing → STOP: prompt user

| Variable | Description |
|---|---|
| `JIRA_TOKEN` | Jira API token (Atlassian account settings) |
| `JIRA_BASE_URL` | e.g. `https://your-org.atlassian.net` |
| `JIRA_PROJECT_KEY` | e.g. `PROJ` |
| `JIRA_EMAIL` | Atlassian account email |

---

## Steps

- DO: Gather inputs — Title (required), Description (recommended), Issue type (default: `Story`), Story points (optional), Parent key (for sub-tasks), Labels/components (optional)

- DO: Resolve story points field
```bash
bash .github/skills/jira-ticket/scripts/get-fields.sh
```
Use `customfield_10274` (verified) unless script shows otherwise.

- DO: Create main ticket
```bash
bash .github/skills/jira-ticket/scripts/create-ticket.sh \
  --title "Your ticket title" \
  --description "Detailed description" \
  --issue-type "Story" \
  --story-points 3
```
- STORE: output issue key (e.g. `PROJ-123`)

- IF: sub-tasks needed →
```bash
bash .github/skills/jira-ticket/scripts/create-ticket.sh \
  --title "Sub-task title" --description "..." \
  --issue-type "Sub-task" --parent "PROJ-123" --story-points 1
```

- IF: update story points →
```bash
bash .github/skills/jira-ticket/scripts/update-story-points.sh \
  --issue-key "PROJ-123" --story-points 5
```

- IF: get comments →
```bash
bash .github/skills/jira-ticket/scripts/get-comments.sh \
  --issue-key "GOBIZWKST2-324" [--max-results N] [--order-by created]
```

- DO: Persist state to `.docs/<task>/jira.json`
```json
{
  "parent": { "key": "GOBIZWKST2-123", "url": "...", "story_points": N },
  "subtasks": { "task-001.md": { "key": "GOBIZWKST2-124", "url": "...", "story_points": 2 } }
}
```

- EMIT: Report — issue key + URL (`$JIRA_BASE_URL/browse/$ISSUE_KEY`), sub-task keys/URLs, final story points

---

## Errors

| Error | Fix |
|---|---|
| `401 Unauthorized` | Verify `JIRA_TOKEN` and `JIRA_EMAIL` |
| `400 Bad Request` | Issue type is case-sensitive; run field discovery |
| `404 Not Found` | Verify `JIRA_BASE_URL` and `JIRA_PROJECT_KEY` |
| Sub-task fails | Some next-gen projects use `Child Issue` instead of `Sub-task` |
