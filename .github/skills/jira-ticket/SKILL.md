---
name: jira-ticket
description: 'Create and retrieve Jira issues via the Jira REST API. Use for: filing new tickets, creating sub-tasks, updating story points, retrieving issue comments. Requires JIRA_TOKEN (API token), JIRA_BASE_URL, JIRA_PROJECT_KEY, and JIRA_EMAIL. Handles: main ticket creation, sub-task creation, story point updates, comment retrieval, input validation.'
argument-hint: '<title> [description] [story_points] [parent_key]'
---

# Jira Ticket Creation

## When to Use
- Create a new Jira issue (story, task, bug) with title and description
- Create sub-tasks under an existing parent ticket
- Update story points on a ticket
- Batch-create a parent ticket + sub-tasks in one step
- Retrieve and display all comments on an existing ticket

## Prerequisites

Ensure the following environment variables are set before proceeding. If any are missing, prompt the user to provide them:

| Variable | Description |
|---|---|
| `JIRA_TOKEN` | Jira API token (from [Atlassian account settings](https://id.atlassian.com/manage-profile/security/api-tokens)) |
| `JIRA_BASE_URL` | Your Jira instance URL, e.g. `https://your-org.atlassian.net` |
| `JIRA_PROJECT_KEY` | Project key, e.g. `PROJ` |
| `JIRA_EMAIL` | Your Atlassian account email (used for Basic Auth with the token) |

Check by running: `echo $JIRA_TOKEN $JIRA_BASE_URL $JIRA_PROJECT_KEY $JIRA_EMAIL`

## Procedure

### 1. Gather Inputs

Collect from the user (or infer from context):
- **Title** (required): Summary/title of the ticket
- **Description** (recommended): Detailed description in plain text or Atlassian Document Format (ADF)
- **Issue type** (default: `Story`): Story, Task, Bug, Sub-task
- **Story points** (optional): Numeric value for `story_points` / `customfield_10274`
- **Parent key** (optional): If creating a sub-task, the parent ticket key (e.g. `PROJ-42`)
- **Labels / components** (optional)

### 2. Resolve Story Points Field Name

Different Jira instances use different custom field IDs for story points. Run the [field discovery script](./scripts/get-fields.sh) to find the correct ID:

```bash
bash .github/skills/jira-ticket/scripts/get-fields.sh
```

Common field IDs:
- `story_points` (Jira Software next-gen)
- `customfield_10274` (Story Points — verified for this instance)
- `customfield_10028` (some enterprise instances)

### 3. Create the Main Ticket

Run the [create-ticket script](./scripts/create-ticket.sh):

```bash
bash .github/skills/jira-ticket/scripts/create-ticket.sh \
  --title "Your ticket title" \
  --description "Detailed description" \
  --issue-type "Story" \
  --story-points 3
```

The script outputs the created issue key (e.g. `PROJ-123`). Save it for sub-task creation.

### 4. Create Sub-tasks (Optional)

If sub-tasks were requested, repeat for each sub-task using `--issue-type Sub-task --parent PROJ-123`:

```bash
bash .github/skills/jira-ticket/scripts/create-ticket.sh \
  --title "Sub-task title" \
  --description "Sub-task description" \
  --issue-type "Sub-task" \
  --parent "PROJ-123" \
  --story-points 1
```

### 5. Update Story Points on Parent / Epic (Optional)

After creating sub-tasks, update the parent's story points to reflect the total:

```bash
bash .github/skills/jira-ticket/scripts/update-story-points.sh \
  --issue-key "PROJ-123" \
  --story-points 5
```

### 6. Retrieve Comments on a Ticket (Optional)

To fetch and display comments for an existing ticket:

```bash
bash .github/skills/jira-ticket/scripts/get-comments.sh \
  --issue-key "GOBIZWKST2-324"
```

Optional flags:
- `--max-results N` — number of comments to return (default: `50`)
- `--order-by created` — oldest first (default); use `-created` for newest first

Output is formatted as numbered entries showing author, date, comment ID, and plain-text body extracted from ADF.

### 7. Persist Ticket State

Save created ticket keys to `.docs/<task>/jira.json` (create the file if it doesn't exist), where `<task>` matches the plan folder name. Format:

```json
{
  "parent": "GOBIZWKST2-123",
  "subtasks": ["GOBIZWKST2-124", "GOBIZWKST2-125"]
}
```

This file is used by other agents to reference ticket keys without re-querying Jira.

### 8. Confirm & Report

After all API calls succeed, output a summary:
- Created issue key and URL: `$JIRA_BASE_URL/browse/$JIRA_PROJECT_KEY-123`
- Sub-task keys and URLs (if any)
- Final story point values

## Reference

See [Jira REST API reference](./references/jira-api.md) for full payload schemas and field descriptions.

## Error Handling

| Error | Resolution |
|---|---|
| `401 Unauthorized` | Verify `JIRA_TOKEN` and `JIRA_EMAIL` are correct |
| `400 Bad Request` | Check issue type name — it is case-sensitive. Run field discovery to confirm field IDs |
| `404 Not Found` | Verify `JIRA_BASE_URL` and `JIRA_PROJECT_KEY` |
| Sub-task creation fails | Ensure the project supports sub-tasks; some next-gen projects use `Child Issue` instead |
