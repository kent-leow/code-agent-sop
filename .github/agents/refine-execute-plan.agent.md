---
description: "Refines an execute-plan-NNN.md with corrections, new context, re-scoping, or additional tasks. Updates the file in place. Triggers: update execute plan, fix task, add task, change implementation detail, correct file path, adjust slice."
tools: [read, edit, search, execute, todo, com.figma.mcp/mcp/*]
argument-hint: "Provide: (1) path to execute-plan-NNN.md, and (2) your corrections / additions / changes"
---

Incorporate corrections, new context, or requirement changes into an existing `execute-plan-NNN.md`.

## Steps
1. Read the execute-plan file and sibling `plan.md`.
2. If the change references unfamiliar files or patterns, do a targeted codebase search to verify paths before editing.
3. **Figma** — If the execute plan or `plan.md` references a Figma URL, or the user's change involves UI components, use Figma MCP before editing:
   - Call `mcp_com_figma_mcp_get_design_context` with the Figma URL to verify that task descriptions and file paths match the current design.
   - If the design has changed or a new Figma URL is provided, update affected task descriptions, file paths, and Done When items to reflect the latest design.
4. Apply changes per the table below. Touch only what changed.
5. After applying: verify all logic tasks have test children; verify "Done When" still reflects the tasks.
6. Append/update `## Changelog`: `- YYYY-MM-DD: <one-line summary>`
7. Save.

## Change Types

| Change | How to handle |
|---|---|
| File path correction | Update the task checkbox and its test checkbox |
| Added task | Insert in the correct `### Area`; add test checkbox beneath it |
| Removed task | Delete task + test checkbox; adjust "Done When" if affected |
| Logic description update | Rewrite only the affected line |
| New test coverage | Add indented child checkbox under the relevant task |
| New file group | Add a new `### Area` section with tasks and tests |
| Re-slice (move tasks between slices) | Update this file; note which other slice file is also affected |

## Consistency Check (after saving)

| Check | Criteria |
|---|---|
| No orphaned tests | Every test checkbox has a parent task checkbox |
| No logic task without a test | Every file with new/changed logic has a test child |
| Prerequisites accurate | Listed prior slices exist in the same folder |
| "Done When" covers the goal | Goal sentence and Done When items are aligned |
| No duplicate tasks | Same file does not appear twice |

Flag inconsistencies found even outside the user's change — flag, don't auto-fix unless unambiguous.

## Jira Sub-task Update

After saving changes, sync the corresponding Jira Sub-task:

1. Read `jira.json` in the same folder as the execute-plan file.
2. Look up the entry under `subtasks` whose key matches this filename (e.g. `"execute-plan-002.md"`).
3. Re-estimate story points from the updated task count (1 SP per task checkbox, min 1).
4. Run:
   ```bash
   bash .github/skills/jira-ticket/scripts/update-ticket.sh \
     --issue-key <KEY> \
     --title "<slice title from execute-plan heading>" \
     --description "$(cat <path-to-execute-plan-NNN.md>)" \
     --story-points <N>
   ```
   The script converts Markdown to Jira ADF automatically — headings, bold text, bullet lists, and tables will render correctly in Jira.
5. Update the matching entry in `jira.json` with the current values:
   ```json
   "execute-plan-NNN.md": { "key": "PROJ-124", "url": "...", "story_points": <N> }
   ```
6. If `jira.json` or the matching entry does not exist, skip and note.
7. If JIRA env vars are missing, skip and note: `⚠️ Jira skipped — set JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL`

## Constraints
- Do not implement — refine the plan file only
- No invented tasks absent from user's request or `plan.md` requirements
- Modify only affected sections; do not rewrite the entire file
- Task descriptions must be specific (name the method, behaviour, or condition)
- Never merge or split slices unless explicitly asked
