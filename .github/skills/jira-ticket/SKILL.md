---
name: jira-ticket
description: 'Create and retrieve Jira issues via the Jira REST API. Use for: filing new tickets, creating sub-tasks, updating story points, retrieving issue comments. Requires JIRA_TOKEN (API token), JIRA_BASE_URL, JIRA_PROJECT_KEY, and JIRA_EMAIL. Handles: main ticket creation, sub-task creation, story point updates, comment retrieval, input validation.'
argument-hint: '<title> [description] [story_points] [parent_key]'
---

# Jira Ticket Creation

## Prerequisites

Check: `echo $JIRA_TOKEN $JIRA_BASE_URL $JIRA_PROJECT_KEY $JIRA_EMAIL`

| Variable | Description |
|---|---|
| `JIRA_TOKEN` | Jira API token (from Atlassian account settings) |
| `JIRA_BASE_URL` | e.g. `https://your-org.atlassian.net` |
| `JIRA_PROJECT_KEY` | e.g. `PROJ` |
| `JIRA_EMAIL` | Atlassian account email |

Missing vars → prompt user before proceeding.

## Procedure

### 1. Gather Inputs
- **Title** (required), **Description** (recommended), **Issue type** (default: `Story`), **Story points** (optional), **Parent key** (for sub-tasks), Labels/components (optional)

### 2. Resolve Story Points Field
```bash
bash .github/skills/jira-ticket/scripts/get-fields.sh
```
Use `customfield_10274` (verified for this instance) unless script shows otherwise.

### 3. Create Main Ticket
```bash
bash .github/skills/jira-ticket/scripts/create-ticket.sh \
  --title "Your ticket title" \
  --description "Detailed description" \
  --issue-type "Story" \
  --story-points 3
```
Save the output issue key (e.g. `PROJ-123`).

### 4. Create Sub-tasks (optional)
```bash
bash .github/skills/jira-ticket/scripts/create-ticket.sh \
  --title "Sub-task title" --description "..." \
  --issue-type "Sub-task" --parent "PROJ-123" --story-points 1
```

### 5. Update Story Points (optional)
```bash
bash .github/skills/jira-ticket/scripts/update-story-points.sh \
  --issue-key "PROJ-123" --story-points 5
```

### 6. Get Comments (optional)
```bash
bash .github/skills/jira-ticket/scripts/get-comments.sh \
  --issue-key "GOBIZWKST2-324" [--max-results N] [--order-by created]
```

### 7. Persist State
Save to `.docs/<task>/jira.json`:
```json
{
  "parent": { "key": "GOBIZWKST2-123", "url": "...", "story_points": N },
  "subtasks": { "task-001.md": { "key": "GOBIZWKST2-124", "url": "...", "story_points": 2 } }
}
```

### 8. Report
- Issue key + URL: `$JIRA_BASE_URL/browse/$ISSUE_KEY`
- Sub-task keys/URLs (if any)
- Final story point values

## Errors

| Error | Fix |
|---|---|
| `401 Unauthorized` | Verify `JIRA_TOKEN` and `JIRA_EMAIL` |
| `400 Bad Request` | Issue type is case-sensitive; run field discovery |
| `404 Not Found` | Verify `JIRA_BASE_URL` and `JIRA_PROJECT_KEY` |
| Sub-task fails | Some next-gen projects use `Child Issue` instead of `Sub-task` |
