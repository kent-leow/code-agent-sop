---
description: "Refine an existing plan.md with answers to open questions, updated requirements, or any modifications. Updates the plan in place, marks resolved questions, performs a readiness check, and cascades impactful changes to any generated execute-plan-NNN.md files. Triggers: answer questions, update plan, modify requirements, refine plan, plan is ready."
tools: [execute/runNotebookCell, execute/testFailure, execute/getTerminalOutput, execute/awaitTerminal, execute/killTerminal, execute/createAndRunTask, execute/runInTerminal, read/getNotebookSummary, read/problems, read/readFile, read/viewImage, read/terminalSelection, read/terminalLastCommand, edit/createDirectory, edit/createFile, edit/createJupyterNotebook, edit/editFiles, edit/editNotebook, edit/rename, search/changes, search/codebase, search/fileSearch, search/listDirectory, search/textSearch, search/usages, com.figma.mcp/mcp/*, todo]
argument-hint: "Provide: (1) path to plan.md, and (2) your answers / changes / extra info"
---

Incorporate new information into an existing `plan.md`, assess whether it is ready for implementation, and cascade any impactful changes to generated execute plan files.

## Steps
1. Read the plan file.
2. **Figma** — UI plan + Figma URL present: load cached context or fetch if missing/updated.
   - **Cache path** (relative to plan folder): `figma/<nodeId>.png`, `figma/<nodeId>.json`, `figma/<nodeId>.md`
   - **Cache-first**: if `figma/<nodeId>.json` exists and no update signalled → read `figma/<nodeId>.md`; skip fetch.
   - **Fetch & save** (cache miss or force-refresh): **Tools**: MCP if available; else `.github/skills/figma-design-context/SKILL.md` + scripts. *MCP* `get_design_context`; *Skill* `get-design-context.sh` + `summarize-context.sh` → save to `figma/<nodeId>.json` + `figma/<nodeId>.md`.
   - Add/update AC where design differs; mark source `(from Figma)`. Re-fetch on new/updated URLs.
3. Apply the provided context:
   - Answered questions → remove rows from **Open Questions**; fold answers into **Scope**, **Summary**, or **Acceptance Criteria**
   - Partially answered → update the row with what is now known
   - New/changed requirements → add, remove, or revise **Acceptance Criteria** and **Scope**
   - Append/update `## Changelog`: `- YYYY-MM-DD: <one-line summary>`
4. Save the updated `plan.md` to the same path.
5. Run the readiness check below.
6. **Execute Plan Cascade** — if execute-plan-NNN.md files exist in the same folder, perform the steps below.
7. **Jira Update** — see section below.

## Jira Update

After saving `plan.md`, sync the Jira Story:

1. Look for `jira.json` in the same folder as `plan.md`.
2. **Exists** → read `parent.key`; re-estimate story points (same formula: `AC rows × 2 + Open Question rows`, min 1); run:
   ```bash
   bash .github/skills/jira-ticket/scripts/update-ticket.sh \
     --issue-key <KEY> \
     --title "<updated plan heading>" \
     --description "$(cat <path-to-plan.md>)" \
     --story-points <N>
   ```
   The script converts Markdown to Jira ADF automatically — headings, bold text, bullet lists, and tables will render correctly in Jira.
   Update `parent.story_points` (and title/description if changed) in `jira.json`.
3. **Does not exist** → create the Jira Story the same way as `generate-plan` step 6; save `jira.json`.
4. If JIRA env vars are missing, skip and note: `⚠️ Jira skipped — set JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL`

## Execute Plan Cascade

When execute plan files exist alongside the updated `plan.md`, determine which tasks are impacted by the changes:

1. **Discover** — search for all `execute-plan-NNN.md` files in the same folder as `plan.md`.
2. **Impact analysis** — for each file, read it and determine whether the changed/added/removed requirements affect:
   - Task objectives or description
   - Acceptance criteria or test requirements
   - File-level checklist items (added, removed, or modified work)
   - Ordering or dependencies between tasks
3. **Update impacted files** — for each affected execute plan:
   - Revise task description, objectives, or acceptance criteria to reflect the new requirements
   - Add, remove, or adjust checklist items accordingly
   - Mark any newly invalidated completed checkboxes as unchecked (`[ ]`) with a note `<!-- re-opened: <reason> -->`
   - Append to the file's changelog (if present): `- YYYY-MM-DD: <one-line summary of change>`
4. **Leave unaffected files untouched.**
5. **Report** — after all updates, output a cascade summary:

```
## Cascade Summary
| File | Status | Changes |
|------|--------|---------|
| execute-plan-001.md | Updated | <brief description> |
| execute-plan-002.md | No impact | — |
```

## Readiness Check

| Criterion | Pass if... |
|---|---|
| No blocking open questions | All rows resolved or explicitly non-blocking |
| Summary is clear | Non-technical stakeholder understands what will be built and why |
| Scope is defined | Both in-scope and out-of-scope items listed |
| Acceptance criteria complete | Every in-scope item has ≥1 testable Given/When/Then row |
| Acceptance criteria concrete | No vague statements ("works correctly", "is handled properly") |
| No external blockers | No criterion depends on an unanswered external decision |

**All pass →** `✅ Plan is ready. Path: <plan path>`

**Any fail →** `⚠️ Plan has gaps: [list each failing criterion with specific description]`

## Constraints
- Do not implement — refine the plan and cascade to execute plans only
- No invented requirements absent from original plan or new context
- Modify only affected sections; do not rewrite entire files
- Business/product language in plan.md; technical detail (file paths, code guidance) may be updated in execute-plan files
- One `plan.md` per folder — always update in place
- Only update execute-plan files that are genuinely impacted; do not touch unaffected files
