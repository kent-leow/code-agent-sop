---
description: "Executes a task-NNN.md end-to-end: syncs sibling task files, then fully implements every task — production code, tests, checkboxes. Triggers: execute task, run task, implement, code this, build this, do the work, start slice."
tools: [read, search, edit, execute, todo, agent]
argument-hint: "Provide the path to task-NNN.md (e.g. .docs/create-form-and-application/task-002.md)"
---

**Input**: `task-NNN.md` path → **Output**: all tasks implemented, tests pass, checkboxes marked.

Load **git-workflow skill**. Autonomous — never pause once started.

---

## Phase 1 — Pre-flight

- DO: read `task-NNN.md`, sibling `plan.md`, all `task-*.md`, `jira.json`
- IF: any `[ ]` in prerequisites → STOP: report open items
- DO: sync siblings — add warnings for shared files, mark satisfied Done-Whens, fix stale refs, append changelogs
- CALL: BRANCH_SETUP(REPO_DIR, `GOBIZWKST2-{TICKET}-{kebab-task-title}`) → TICKET_NUM, BRANCH, DEFAULT_BRANCH
- CALL: WORKTREE_SETUP(REPO_DIR, BRANCH, DEFAULT_BRANCH) → WORKTREE_DIR
- STORE: `WORK_DIR="${WORKTREE_DIR}"` — **all edits in Phase 2–4 target WORK_DIR only**

## Phase 2 — Exploration

- DO: read every file listed in `task-NNN.md`
- DO: for each new file → find 2–3 analogues for conventions
- DO: identify reusable utilities, base classes, test helpers
- STORE: impl order = entity → repo → service → controller → frontend → test
- IF: Figma URL → CALL: figma-design-context skill (Workflow A: metadata → targeted design context → summarize) → cache under `<plan-folder>/figma/` per skill's Caching Convention — check cache before re-fetching; implement strictly from the cached spec, never from memory

## Phase 3 — Implementation

- LOOP: each task in dependency order
  - DO: write production code inside `WORK_DIR` — match conventions
  - IF: UI task → verify node-by-node against the cached `context.summary.md` NODE TREE (dimensions, fills, padding, gap, corner-radius, font, text) — 0 discrepancy, no invented/"improved" values; screenshot is a sanity check only, tree/JSON is ground truth
  - DO: mark `[x]` in `task-NNN.md`
  - DO: write/update tests; run from `WORK_DIR`; fix failures before next
  - DO: mark test `[x]`
- IF: file not listed in `task-NNN.md` → STOP: do not create/modify

## Phase 4 — Verification

- DO: run full test suite from `WORK_DIR`; fix regressions
- IF: local service verification needed → start from `WORK_DIR`
- LOOP: each Done When → mark `[x]` + `<!-- verified YYYY-MM-DD -->` or `[ ]` + `<!-- blocked: reason -->`
- DO: re-scan siblings for stale cross-references

## Phase 5 — Git Workflow

> **Do NOT stop until pipeline green AND zero unresolved threads.**

### 5a — Commit & Push

- CALL: COMMIT(WORK_DIR, `feat({repo}): {title} [GOBIZWKST2-{TICKET_NUM}]`) → COMMITTED
- CALL: PUSH(WORK_DIR, BRANCH)
- CALL: WORKTREE_TEARDOWN(REPO_DIR, WORKTREE_DIR)
- CALL: ENSURE_MR(ENCODED, BRANCH, DEFAULT_BRANCH, title, body) → MR_IID, MR_URL

### 5b — Poll Until Clean

- CALL: POLL_PIPELINE(ENCODED, MR_IID, COMMITTED)
- LOOP: until (pipeline=success AND open_threads=0) OR terminal exit
  - ON_SUCCESS + threads>0: evaluate → WORKTREE_SETUP → fix → COMMIT → PUSH → TEARDOWN → RESOLVE → reset poll
  - ON_FAILURE: inspect logs → WORKTREE_SETUP → fix → COMMIT → PUSH → TEARDOWN → reset poll

### 5c — Terminal Exits

| Condition | Action |
|---|---|
| Pipeline success + 0 threads | ✅ Proceed to Phase 6 |
| 3 consecutive failures | BLOCKED — stop |
| 20 polls | TIMEOUT — stop |

## Phase 6 — Completion

- EMIT: jira-prompt (A: update SP | B: changes | C: skip)
- EMIT: summary — paths, tests, Done When status, MR URL, pipeline, next task

## Constraints

- Implement only what `task-NNN.md` lists
- Search codebase before asking user
- Never mark done until code written + tests pass
- Never skip test tasks
- No dead code, unused imports, placeholder implementations
- Explicit errors — no silent failures
- No magic values — use existing constants/enums
- Validate at system boundaries
- No secrets/stack traces in API responses
