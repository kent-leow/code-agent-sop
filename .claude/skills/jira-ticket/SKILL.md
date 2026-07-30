---
name: jira-ticket
description: "Create/retrieve Jira issues via REST API: tickets, sub-tasks, story points, comments. Requires JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL."
argument-hint: '<title> [description] [story_points] [parent_key]'
---

# jira-ticket

## Prerequisites

Check vars: `echo $JIRA_TOKEN $JIRA_BASE_URL $JIRA_PROJECT_KEY $JIRA_EMAIL`
IF: any missing → STOP.

| Variable | Description |
|---|---|
| `JIRA_TOKEN` | API token (Atlassian account settings) |
| `JIRA_BASE_URL` | e.g. `https://your-org.atlassian.net` |
| `JIRA_PROJECT_KEY` | e.g. `PROJ` |
| `JIRA_EMAIL` | Atlassian account email |

---

## Operations

### Create ticket
```bash
bash .github/skills/jira-ticket/scripts/create-ticket.sh \
  --title "Title" --description "..." --issue-type "Story" --story-points 3
```
Sub-task: add `--parent "PROJ-123" --issue-type "Sub-task"`

### Update story points
```bash
bash .github/skills/jira-ticket/scripts/update-story-points.sh --issue-key "PROJ-123" --story-points 5
```

### Get comments
```bash
bash .github/skills/jira-ticket/scripts/get-comments.sh --issue-key "GOBIZWKST2-324" [--max-results N]
```

### Resolve SP field
```bash
bash .github/skills/jira-ticket/scripts/get-fields.sh
```
Default: `customfield_10274` (verified).

---

## Persist State

Write to `.docs/<task>/jira.json`:
```json
{
  "parent": { "key": "GOBIZWKST2-123", "url": "...", "story_points": N },
  "subtasks": { "task-001.md": { "key": "GOBIZWKST2-124", "url": "...", "story_points": 2 } }
}
```

## Errors

| Error | Fix |
|---|---|
| 401 | Verify `JIRA_TOKEN` + `JIRA_EMAIL` |
| 400 | Issue type is case-sensitive; run field discovery |
| 404 | Verify `JIRA_BASE_URL` + `JIRA_PROJECT_KEY` |
| Sub-task fails | Some projects use `Child Issue` instead of `Sub-task` |
