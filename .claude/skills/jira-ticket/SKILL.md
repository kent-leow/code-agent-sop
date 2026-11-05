---
name: jira-ticket
description: "Read/create/update Jira issues (summary, description, comments, story points, sub-tasks) and read Confluence pages via Atlassian REST. Requires JIRA_EMAIL, JIRA_TOKEN, JIRA_BASE_URL (+ JIRA_PROJECT_KEY to create)."
argument-hint: '<issue key | page id/url | title> [description] [story_points] [parent_key]'
---

# jira-ticket

`S=.github/skills/jira-ticket/scripts` — all scripts source `_http.sh`: env guard, credentials via curl config (never argv/logs), 10s connect / 60s total timeout, GET/PUT retry 429/5xx with backoff, POST never retried, non-expected HTTP → `Error: METHOD PATH -> HTTP n` + body excerpt on stderr, exit 1.

## Prerequisites

- `source ~/.zshenv`; IF any of `JIRA_EMAIL`, `JIRA_TOKEN`, `JIRA_BASE_URL` (`https://<org>.atlassian.net`) unset → STOP, name it. Never print values.
- Network → request access up front.

## Operations

| Need | Command | Writes? |
|---|---|---|
| Read issue (fields, links, description, comments as text) | `bash $S/get-issue.sh --issue-key PROJ-1 [--no-comments] [--json]` | no |
| Read comments (+ inline images → `/tmp/jira-images/<KEY>/`) | `bash $S/get-comments.sh --issue-key PROJ-1 [--max-results N] [--order-by -created]` | no |
| Read Confluence page (text + version) | `bash $S/get-page.sh --page-id N \| --url <page URL> [--json]` | no |
| Find story-points field | `bash $S/get-fields.sh` (default `customfield_10274`) | no |
| Create issue / sub-task | `bash $S/create-ticket.sh --title T [--description MD] [--issue-type Story] [--story-points N] [--parent PROJ-1] [--assignee <accountId>]` | **yes** |
| Update title/description/SP | `bash $S/update-ticket.sh --issue-key PROJ-1 [--title T] [--description MD] [--story-points N]` | **yes** |
| Update SP only | `bash $S/update-story-points.sh --issue-key PROJ-1 --story-points N [--field-id F]` | **yes** |

- `--description` is Markdown → ADF. Pipe-tables become native Jira tables: always pass Acceptance Criteria as pipe-tables (same shape as `plan.md` `| **AC1** | <title> |` + Given/When/Then rows), never bullets. Headings, emphasis, code, lists, blockquotes preserved.
- Issue type names are case-sensitive and per-project (`Story`, `Task`, `Bug`, `Sub-task`; team-managed projects use `Child Issue`).
- `create-ticket` is not retried: on network error/5xx, search Jira for the title before re-running (avoid duplicates).

## Persist State

`<DOCS_DIR>/jira.json` (`DOCS_DIR` from docs-folder skill DOCS_FOLDER):
```json
{ "parent": { "key": "PROJ-123", "url": "...", "story_points": 5 },
  "subtasks": { "task-001.md": { "key": "PROJ-124", "url": "...", "story_points": 2 } } }
```

## Errors

| HTTP | Fix |
|---|---|
| 401 | Check `JIRA_EMAIL` + `JIRA_TOKEN` pair |
| 400 | Issue type / field id wrong → `get-fields.sh` |
| 403 | No permission on project/space |
| 404 | Key/page id or `JIRA_BASE_URL` wrong |
| 429 / 5xx | Already retried; wait and retry once, don't loop |
| `self signed certificate` | `export CURL_CA_BUNDLE=<corporate CA bundle>`; never `-k` |
