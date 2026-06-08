---
description: "Executes a task-NNN.md end-to-end: syncs sibling task files, then fully implements every task — production code, tests, checkboxes. Triggers: execute task, run task, implement, code this, build this, do the work, start slice."
tools: [read, search, edit, execute, todo, agent, com.figma.mcp/mcp/*]
argument-hint: "Provide the path to task-NNN.md (e.g. .docs/create-form-and-application/task-002.md)"
---

**Input**: `task-NNN.md` path. **Output**: all tasks implemented, tests passing, all checkboxes marked.

Load **git-workflow skill** for all branch/commit/push/MR/pipeline/thread operations.
---

**Input**: `task-NNN.md` path. **Output**: all tasks implemented, tests passing, all checkboxes marked.

## Phase 1 — Pre-flight

1. Read: `task-NNN.md`, sibling `plan.md`, all sibling `task-*.md`, `jira.json` (note sub-task key).
2. **Prerequisites**: any `[ ]` remain → stop, report which task/items are open.
3. **Sync siblings** (touch only affected lines):

| Situation | Action |
|---|---|
| Another task references a file you'll implement | Add `> ⚠️ Implemented in task-NNN.md — verify contract` beneath it |
| Earlier Done When now satisfied | Mark `[x]` + `<!-- verified YYYY-MM-DD -->` |
| Later prerequisite points here | Confirm name matches; correct if not |
| Changed file missing Changelog entry | Append `- YYYY-MM-DD: <summary>` to `## Changelog` |

## Phase 2 — Exploration

1. Read every file listed in `task-NNN.md` in full.
2. For each **new** file: find 2–3 analogues for naming/structure/import conventions.
3. Identify reusable utilities, constants, base classes, test helpers, fixtures.
4. Impl order: entity → repository → service → controller → frontend → test.
5. **Figma** (UI): cache at `figma/<nodeId>.{json,png,md}` relative to plan folder.
   - Hit → read `figma/<nodeId>.md` + `view_image`.
   - Miss → try MCP (`get_design_context` + `get_screenshot`) → save → `view_image`. MCP unavailable → load `.github/skills/figma-design-context/SKILL.md` → save → `view_image`.

## Phase 3 — Implementation

For each task in dependency order:
1. Write production code — match conventions: naming, structure, imports, error handling, auth guards, logging. UI: verify layout/spacing/colour vs Figma before marking done.
2. Mark `[x]` in `task-NNN.md` immediately after saving.
3. Write/update test — mirror adjacent test structure; happy path minimum; add edge cases only where patterns already exist. Reuse test utilities.
4. Run tests; fix all failures before next task.
5. Mark test `[x]`.

> Only create/modify files listed in `task-NNN.md`.

## Phase 4 — Verification

1. Run full test suite for every affected module; fix regressions.
2. Each **Done When**: satisfied → `[x]` + `<!-- verified YYYY-MM-DD -->`; blocked → `[ ]` + `<!-- blocked: <reason> -->`.
3. Re-scan siblings — confirm no stale cross-references.

---

## Phase 5 — Git Workflow

1. **Branch** — pattern: `GOBIZWKST2-{TICKET}-{kebab-task-title}` (slug = kebab-case of `task-NNN.md` title).  
   → skill: BRANCH_SETUP (`REPO_DIR`, `BRANCH_PATTERN`)  
   Skill resolves `TICKET_NUM` from `jira.json` → current branch → **asks user if not found**. Outputs `TICKET_NUM`, `BRANCH`, `DEFAULT_BRANCH`.
2. **Commit** — `feat({repo-name}): {task title} [GOBIZWKST2-{TICKET_NUM}]\n\nImplemented:\n- {file1}\n- {file2}`  
   → skill: COMMIT (`REPO_DIR`, `COMMIT_MSG`)  
   Store `COMMITTED`.
3. **Push** — → skill: PUSH (`REPO_DIR`, `BRANCH`)
4. **MR** — Title: `[GOBIZWKST2-{TICKET_NUM}] {task title}`. Body: list of implemented files + Done When checklist.  
   → skill: ENSURE_MR (`ENCODED`, `BRANCH`, `DEFAULT_BRANCH`, `MR_TITLE`, `MR_BODY`)  
   Store `MR_IID`, `MR_URL`.
5. **Poll pipeline** → skill: POLL_PIPELINE (`ENCODED`, `MR_IID`, `COMMITTED`)  
   **Run to completion autonomously — do not pause or ask the user at any point.**

   **ON_SUCCESS hook (execute inline, immediately):**  
   → skill: FETCH_OPEN_THREADS → evaluate each thread (FIX/REJECT using same rules as `git-fix-review`) → apply fixes → skill: COMMIT → skill: PUSH → skill: POST_THREAD_REPLIES → skill: RESOLVE_THREADS → done.

   **ON_FAILURE hook (execute inline, immediately):**  
   Inspect CI logs → fix compilation/test failures → skill: COMMIT → skill: PUSH → reset `POLL=0; CONSECUTIVE_FAILURES=0` → continue loop.

---

## Phase 6 — Completion Prompt

> ✅ Task NNN complete.
> **A** — Update Jira Sub-task SP &nbsp; **B** — Further changes &nbsp; **C** — Skip

- **A** — Load `.github/skills/jira-ticket/SKILL.md`. Read `jira.json`; find entry for this file. Count task checkboxes (1 SP each, min 1). Update only if differs from stored `story_points`. Save `jira.json`. Missing config → `⚠️ Jira skipped — set JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL`
- **B** — Apply; re-present prompt.
- **C** — Stop.

```
✅ Task NNN complete.
Implemented: <file paths>
Tests:       <test file paths>
Done When:   ✅ <condition> / ⚠️ <condition — reason>
Siblings:    task-NNN.md — <what changed>
MR:          <MR_URL>  [created|existing]
Pipeline:    <success|failed|timeout>
Next:        task-<NNN+1>.md  (or "No further slices.")
```

## Code Quality
- No dead code, unused imports, placeholder implementations
- Explicit errors — no silent failures
- No magic values — use existing constants/enums; define new only when none exist
- Validate at system boundaries using existing validation framework
- No stack traces, internal IDs, or sensitive data in API responses

## Constraints
- Implement only what is listed in `task-NNN.md`
- Search codebase before asking user when ambiguous
- Never mark done until code written and tests pass
- Never skip test tasks
- Don't renumber/restructure slices unless explicitly instructed
- Touch only affected lines in sibling files
- **Once Phase 5 starts, run the full git workflow (commit → push → MR → poll → hooks) to completion without pausing to ask the user. Only stop at a terminal exit condition.**
