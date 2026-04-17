---
description: "Executes a task-NNN.md end-to-end: syncs sibling task files, then fully implements every task — production code, tests, checkboxes. Triggers: execute task, run task, implement, code this, build this, do the work, start slice."
tools: [read, search, edit, execute, todo, agent, com.figma.mcp/mcp/*]
argument-hint: "Provide the path to task-NNN.md (e.g. .docs/create-form-and-application/task-002.md)"
---

**Input**: path to `task-NNN.md`.
**Output**: all tasks implemented, tests passing, all checkboxes marked.

---

## Phase 1 — Pre-flight

### 1.1 Read
- Target `task-NNN.md` — tasks, Done When, Prerequisites
- Sibling `plan.md` — AC, business context
- All sibling `task-*.md` files
- `jira.json` (if present) — note sub-task key for this file under `subtasks`

### 1.2 Prerequisites
For each slice listed in **Prerequisites**:
- All Done When `[x]` → satisfied, proceed.
- Any `[ ]` remain → **stop**. Report which task file and which items are open.

### 1.3 Sync Siblings
Scan every sibling `task-*.md`:

| Situation | Action |
|---|---|
| Another task references a file you will implement | Add `> ⚠️ Implemented in task-NNN.md — verify contract` beneath that task |
| A Done When in an earlier slice is now satisfied | Mark `[x]` + `<!-- verified YYYY-MM-DD -->` |
| A later slice's prerequisite points to this slice | Confirm name matches; correct if not |
| Any changed file is missing a Changelog entry | Append `- YYYY-MM-DD: <summary>` to `## Changelog` |

Touch only affected lines.

---

## Phase 2 — Exploration

1. Read every file listed in `task-NNN.md` in full.
2. For each **new** file: find 2–3 analogous files to derive naming, structure, and import conventions.
3. Identify reusable utilities, constants, base classes, test helpers, and fixtures.
4. Determine implementation order: entity → repository → service → controller → frontend → test.
5. **Figma** (UI tasks):
   - Cache: `figma/<nodeId>.{json,png,md}` relative to the plan folder.
   - **Hit** → read `figma/<nodeId>.md` + `view_image`; skip fetch.
   - **Miss**: Try MCP (`mcp_com_figma_mcp_get_design_context` + `mcp_com_figma_mcp_get_screenshot`) → save; `view_image`. MCP unavailable → load `.github/skills/figma-design-context/SKILL.md` → save; `view_image`.
   - Translate design → project style system; reuse existing primitives.

---

## Phase 3 — Implementation

For each task **in dependency order**:

1. Write production code — match codebase conventions: naming, structure, imports, error handling, auth guards, logging. For UI: verify layout/spacing/colour against Figma before marking done.
2. Mark task checkbox `[x]` in `task-NNN.md` immediately after saving the file.
3. Write/update test — mirror adjacent test structure; cover happy path minimum; add validation, auth, edge cases only where those patterns already exist. Reuse existing test utilities.
4. Run tests; fix all failures before moving to the next task.
5. Mark test checkbox `[x]`.

> Only create or modify files listed in `task-NNN.md`. No extra helpers, abstractions, or utilities.

---

## Phase 4 — Verification

1. Run full test suite for every affected module. Fix all regressions.
2. For each **Done When** item:
   - Satisfied → `[x]` + `<!-- verified YYYY-MM-DD -->`
   - Blocked → `[ ]` + `<!-- blocked: <reason> -->`
3. Re-scan siblings — confirm no stale cross-references.

---

## Completion Prompt

> ✅ Task NNN complete.
>
> **A** — Update Jira Sub-task SP &nbsp; **B** — Further changes &nbsp; **C** — Skip

- **A** — Use `.github/skills/jira-ticket/SKILL.md`. Read `jira.json`; find `subtasks` entry for this file. Re-count task checkboxes (1 SP each, min 1). Update only if count differs from stored `story_points`. Update `jira.json`.
  - Missing `jira.json`, entry, or env vars → `⚠️ Jira skipped — set JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL`
- **B** — Apply changes; re-present prompt.
- **C** — Stop.

### Final Report

```
✅ Task NNN complete.

Implemented: <file paths>
Tests:       <test file paths>
Done When:   ✅ <condition> / ⚠️ <condition — reason>
Siblings:    task-NNN.md — <what changed>
Next:        task-<NNN+1>.md  (or "No further slices.")
```

---

## Code Quality
- No dead code, unused imports, or placeholder implementations
- No silent failures — propagate or handle errors explicitly
- No magic values — use existing constants/enums; define new only when none exist
- Validate at system boundaries using the existing validation framework
- No stack traces, internal IDs, or sensitive data in API responses

## Constraints
- Implement only what is listed in `task-NNN.md`
- Search codebase before asking the user when something is ambiguous
- Never mark done until code is written and tests pass
- Never skip test tasks
- Do not renumber or restructure slices unless explicitly instructed
- Touch only affected lines in sibling files
