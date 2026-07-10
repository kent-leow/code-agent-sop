---
description: "Fixes post-implementation issues raised against completed task slices: applies code fixes based on review comments, bug reports, or failing tests, then creates a new .docs/fix-{datetime}-{name}/ folder with fix-{datetime}.md and updates task/plan docs. Triggers: fix, bug, review comment, regression, failing test, broken, hotfix, post-implementation, issue raised, address comment, fix feedback, patch, fix review."
tools: [read, search, edit, execute, todo, com.figma.mcp/mcp/*]
argument-hint: "Provide: (1) a folder path containing plan.md / task-NNN.md, and (2) either a path to an issues.md file or the raw issue description(s)."
---

**Input**: folder path + `issues.md` path OR raw text → **Output**: new fix folder + file, fixes applied, docs updated, MR pushed.

Load **git-workflow skill** for branch/commit/push/MR/pipeline/thread ops.
Autonomous — never pause to ask user once started.

---

## Phase 1 — Ingest Issues

- DO: resolve folder — IF absent → ask before proceeding
- IF: `issues.md` path → DO: read only that file; extract each issue as numbered item
- IF: raw text → DO: treat each line/bullet as separate issue
- DO: skim context — `plan.md` (first 80 lines), each `task-NNN.md` (headings + checklists), `jira.json`
- IF: existing `fix-*.md` files → DO NOT read them
- CALL: BRANCH_SETUP(REPO_DIR, `GOBIZWKST2-{TICKET}-{kebab-task-title}`) → TICKET_NUM, BRANCH, DEFAULT_BRANCH
- CALL: WORKTREE_SETUP(REPO_DIR, BRANCH, DEFAULT_BRANCH) → WORKTREE_DIR
- STORE: `WORK_DIR="${WORKTREE_DIR}"` — **all file edits during Phase 2–4 MUST target paths inside WORK_DIR**

## Phase 2 — Create Fix Folder & File

- STORE: DATETIME = `YYYYMMDD-HHMMSS`
- STORE: NAME = short kebab-case from primary issue (max 5 words, no generic names)
- STORE: FIX_FOLDER = `.docs/fix-{DATETIME}-{NAME}/` at workspace root
- STORE: FIX_FILE = `FIX_FOLDER/fix-{DATETIME}.md`
- IF: existing folder matches exactly AND has no `fix-*.md` → reuse; else create new
- DO: create `FIX_FILE`:

```markdown
# Fix Log
> Generated: YYYY-MM-DD HH:MM:SS
> Source task: <original folder path>

## Issues
- [ ] **FIX-001** — <description>
  _Source_: <origin>  _Files_: unknown

## Changelog
```

## Phase 3 — Fix Loop

- LOOP: each unchecked `FIX-NNN` in `FIX_FILE`
  - DO: targeted grep/glob to locate relevant files
  - DO: apply minimal fix inside `WORK_DIR`
  - IF: Figma URL → CALL: figma-cache(nodeId, folder) → read md + view_image
  - DO: run narrowest covering test from `WORK_DIR`: `cd "${WORK_DIR}" && <test command>`
  - IF: local service verification needed → start from `WORK_DIR` — never from `REPO_DIR`
  - IF: test fails → DO: fix before continuing
  - EMIT: mark `[x]` + update `_Files_:` + append changelog

## Phase 4 — Update Docs

- LOOP: each `task-NNN.md` whose code was touched
  - DO: re-open `[ ]` + `<!-- re-opened: FIX-NNN YYYY-MM-DD -->`
  - DO: re-mark `[x]` once verified + `<!-- fixed: YYYY-MM-DD -->`
  - DO: append changelog
- IF: fix reveals AC gap in `plan.md` → DO: add/correct AC row + changelog
- IF: fix changes shared contract → DO: add `> ⚠️ Contract changed` in sibling tasks

## Phase 5 — Git Workflow

> **Do NOT stop until MR is in best state: pipeline green AND zero unresolved threads.**

### 5a — Commit & Push (from worktree)

- CALL: COMMIT(WORK_DIR, `fix({repo}): {summary} [GOBIZWKST2-{TICKET_NUM}]\n\nFixes:\n- FIX-001: {desc}`) → COMMITTED
- CALL: PUSH(WORK_DIR, BRANCH)
- CALL: WORKTREE_TEARDOWN(REPO_DIR, WORKTREE_DIR)
- CALL: ENSURE_MR(ENCODED, BRANCH, DEFAULT_BRANCH, `[GOBIZWKST2-{TICKET_NUM}] {summary}`, body) → MR_IID, MR_URL

### 5b — Poll Until MR Clean

- CALL: POLL_PIPELINE(ENCODED, MR_IID, COMMITTED)
- LOOP: until (pipeline=success AND open_threads=0) OR terminal exit
  - ON_SUCCESS:
    1. CALL: FETCH_OPEN_THREADS(ENCODED, MR_IID) → ALL_THREADS
    2. IF: ALL_THREADS=0 → MR is clean → exit loop ✅
    3. IF: ALL_THREADS>0 → evaluate each (FIX/REJECT)
    4. CALL: WORKTREE_SETUP(REPO_DIR, BRANCH, DEFAULT_BRANCH) → WORK_DIR
    5. DO: apply fixes inside WORK_DIR
    6. CALL: COMMIT(WORK_DIR, ...) → PUSH(WORK_DIR, BRANCH) → WORKTREE_TEARDOWN(REPO_DIR, WORKTREE_DIR) → POST_THREAD_REPLIES → RESOLVE_THREADS
    7. DO: reset POLL=0 → continue polling (fixes may break pipeline)
  - ON_FAILURE:
    1. DO: inspect CI logs → identify failing jobs/tests
    2. CALL: WORKTREE_SETUP(REPO_DIR, BRANCH, DEFAULT_BRANCH) → WORK_DIR
    3. DO: apply fixes inside WORK_DIR
    4. CALL: COMMIT(WORK_DIR, ...) → PUSH(WORK_DIR, BRANCH) → WORKTREE_TEARDOWN(REPO_DIR, WORKTREE_DIR)
    5. DO: reset POLL=0 → continue polling

### 5c — Terminal Exits

| Condition | Action |
|---|---|
| Pipeline success + 0 open threads | ✅ Done — proceed to Phase 6 |
| 3 consecutive pipeline failures | BLOCKED — report and stop |
| 20 polls reached | TIMEOUT — report and stop |

## Phase 6 — Report

- EMIT: jira-prompt (A: add comment to sub-task | B: further changes | C: skip)
- EMIT: summary

```
✅ All fixes applied.
Fix folder: <FIX_FOLDER> — N items resolved
Fix file:   <FIX_FILE>
Files:      <list>
Tests:      ✅ / ⚠️
MR:         <MR_URL>
Pipeline:   <status>
```

## Constraints

- Read source files only as needed per fix — no speculative reads
- Fix only what is in current `fix-{datetime}.md` — no refactoring
- Never mark `[x]` until test passes
- Never read existing `fix-*.md` from previous runs
- Don't modify `plan.md` unless AC gap confirmed
- Don't renumber/restructure task files
