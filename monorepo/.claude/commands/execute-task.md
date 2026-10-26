---
description: "Executes a task-NNN.md end-to-end: syncs sibling task files, then fully implements every task — production code, tests, checkboxes. Triggers: execute task, run task, implement, code this, build this, do the work, start slice."
tools: [read, search, edit, execute, todo, agent]
argument-hint: "Provide the path to task-NNN.md (e.g. .docs/GOBIZWKST2-324-create-form-and-application/task-002.md)"
---

**Input**: `task-NNN.md` path → **Output**: all tasks implemented, tests pass, checkboxes marked.

Load **docs-folder**, **git-workflow**, **deep-think** and **app-blueprint** skills. Autonomous — never pause once started.

---

## Phase 1 — Pre-flight

- CALL: DOCS_FOLDER(REQUEST, PATH=task-NNN.md) → DOCS_DIR, JIRA_KEY (validates/renames legacy folder — the only permitted pause)
- DO: read `task-NNN.md`, sibling `plan.md`, `blueprint.md` (if present), all `task-*.md`, `jira.json`
- IF: `blueprint.md` present AND `Status` ≠ `Approved` → STOP: blueprint not approved
- IF: any `[ ]` in prerequisites → STOP: report open items
- DO: sync siblings — add warnings for shared files, mark satisfied Done-Whens, fix stale refs, append changelogs
- IF: greenfield AND (REPO_DIR has no git repo, no commits, or no `origin` remote) → **Local Bootstrap**: `git init` if needed (default branch `main`) → STORE `WORK_DIR="${REPO_DIR}"`, `LOCAL_ONLY=true` → skip BRANCH_SETUP/WORKTREE_SETUP → continue to Phase 2
- CALL: BRANCH_SETUP(REPO_DIR, `GOBIZWKST2-{TICKET}-{kebab-task-title}`) → TICKET_NUM, BRANCH, DEFAULT_BRANCH
- CALL: WORKTREE_SETUP(REPO_DIR, BRANCH, DEFAULT_BRANCH) → WORKTREE_DIR
- STORE: `WORK_DIR="${WORKTREE_DIR}"` — **all edits in Phase 2–4 target WORK_DIR only**

## Phase 2 — Exploration

- DO: read every file listed in `task-NNN.md`
- DO: for each new file → find 2–3 analogues for conventions; IF: none exist (greenfield early phases) → conventions come from blueprint `Repository Layout`, `Cross-cutting Conventions`, `API Conventions` — never improvise
- DO: identify reusable utilities, base classes, test helpers
- STORE: impl order = entity → repo → service → controller → frontend → test (greenfield P0–P4: follow task order as written — toolchain → generator → config → wiring → tests)
- IF: Figma URL → CALL: figma-design-context skill (Workflow A: metadata → targeted design context → summarize) → cache under `<DOCS_DIR>/figma/` per skill's Caching Convention — check cache before re-fetching; implement strictly from the cached spec, never from memory

## Phase 3 — Implementation

- LOOP: each task in dependency order
  - IF: generator/scaffold task → run the exact listed command non-interactively inside `WORK_DIR` (pinned version; never `@latest` unless blueprint pins it) → review generated files → delete only demo boilerplate the task names
  - IF: dependency install → exact version from blueprint Stack → update lockfile → run ecosystem audit; HIGH/CRITICAL finding → STOP and report
  - DO: write production code inside `WORK_DIR` — match conventions
  - IF: UI task → verify node-by-node against the cached `context.summary.md` NODE TREE (dimensions, fills, padding, gap, corner-radius, font, text) — 0 discrepancy, no invented/"improved" values; screenshot is a sanity check only, tree/JSON is ground truth
  - DO: mark `[x]` in `task-NNN.md`
  - DO: write/update tests; run from `WORK_DIR`; fix failures before next
  - DO: mark test `[x]`
- IF: file not listed in `task-NNN.md` → STOP: do not create/modify (exception: files emitted by a generator/install command listed in the task, and lockfiles)
- LOOP: each item in `Edge Cases & Failure Modes` (skip `N/A`) → implement + test alongside the owning layer → mark `[x]`
- DO: apply each `Non-Functional Notes` item (skip `N/A`) — security/perf/observability/rollback — as part of the same code, not an afterthought

## Phase 3.5 — Requirements Trace

- CALL: DEEP_THINK_PASS(implemented diff, SCOPE=technical) against plan.md AC + task Done When + Edge Cases/Non-Functional Notes + Adversarial Review Bank
- LOOP: any gap found → patch in `WORK_DIR` (back to Phase 3 pattern) → re-run trace → stop when `GAPS[]` empty or pass cap reached
- IF: blocking gap remains unresolved after cap → STOP: report gap (do not fabricate a pass)

## Phase 4 — Verification

- DO: run full test suite from `WORK_DIR`; fix regressions
- DO: run every command in the task's `Verify` section; greenfield → also run blueprint `install` (clean), `lint`, `typecheck`, `build`, `test` (and `e2e` once P1 created it) — all must pass
- IF: greenfield P1+ OR task has `Routes & Navigation` rows → start `dev` from `WORK_DIR` → hit health endpoint + every route in the task (and nav links) → confirm expected status/content → stop the server
- IF: local service verification needed → start from `WORK_DIR`
- LOOP: each Done When → mark `[x]` + `<!-- verified YYYY-MM-DD -->` or `[ ]` + `<!-- blocked: reason -->`
- DO: re-scan siblings for stale cross-references

## Phase 5 — Git Workflow

> **Do NOT stop until pipeline green AND zero unresolved threads.**

> IF: `LOCAL_ONLY=true` → stage task files + commit in `WORK_DIR` with the 5a message format (ticket suffix omitted if none) → skip push/MR/polling → Phase 6 reports "local commit only — no remote configured". Once a remote exists, later tasks follow the normal flow.

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
- EMIT: evidence-based summary — no claim without an executed check behind it:
  - **Implemented**: paths touched, per layer
  - **Verified**: test suite result (pass/fail counts, not "looks good"), Done When status
  - **Reviewed**: Edge Cases/Non-Functional coverage, Requirements Trace pass count
  - **Assumptions**: any `ASSUMPTIONS[]` from deep-think passes, with Confidence
  - **Risks / Follow-ups**: anything deferred or out of scope
  - MR URL, pipeline status, next task

## Constraints

- Implement only what `task-NNN.md` lists
- Search codebase before asking user
- Never mark done until code written + tests pass
- Never skip test tasks
- No dead code, unused imports, placeholder implementations (exception: P4 route shells listed in blueprint Route Map with a named owning task)
- Explicit errors — no silent failures
- No magic values — use existing constants/enums
- Validate at system boundaries
- No secrets/stack traces in API responses
- Never proceed to Phase 5 until Requirements Trace has zero unresolved gaps (or explicitly reported as blocked)
- Never claim a check (test/build/lint) passed unless it was actually executed in this session
