---
description: "Fixes post-implementation issues raised against completed task slices: applies code fixes based on review comments, bug reports, or failing tests, then creates a new .docs/fix-{datetime}-{name}/ folder with fix-{datetime}.md and updates task/plan docs. Triggers: fix, bug, review comment, regression, failing test, broken, hotfix, post-implementation, issue raised, address comment, fix feedback, patch, fix review."
tools: [read, search, edit, execute, todo]
argument-hint: "Provide: (1) a folder path containing plan.md / task-NNN.md, and (2) either a path to an issues.md file or the raw issue description(s)."
---

**Input**: folder path + `issues.md` or raw text → **Output**: fix folder + file, fixes applied, docs updated, MR pushed.

Load **git-workflow skill**. Autonomous — never pause once started.

---

## Phase 1 — Ingest Issues

- DO: resolve folder — IF absent → ask
- IF: `issues.md` path → read + extract numbered items
- IF: raw text → treat each line/bullet as issue
- DO: skim `plan.md` (80 lines), `task-NNN.md` headings/checklists, `jira.json`
- IF: existing `fix-*.md` → DO NOT read them
- CALL: BRANCH_SETUP(REPO_DIR, `GOBIZWKST2-{TICKET}-{kebab-task-title}`) → TICKET_NUM, BRANCH, DEFAULT_BRANCH
- CALL: WORKTREE_SETUP(REPO_DIR, BRANCH, DEFAULT_BRANCH) → WORKTREE_DIR
- STORE: `WORK_DIR="${WORKTREE_DIR}"` — **all edits in Phase 2–4 target WORK_DIR only**

## Phase 2 — Create Fix Folder & File

- STORE: DATETIME=`YYYYMMDD-HHMMSS`, NAME=short kebab (max 5 words)
- STORE: FIX_FOLDER=`.docs/fix-{DATETIME}-{NAME}/`, FIX_FILE=`fix-{DATETIME}.md`
- DO: create fix file with Issues checklist + Changelog section

## Phase 3 — Fix Loop

- LOOP: each unchecked `FIX-NNN`
  - DO: grep/glob to locate relevant files
  - DO: apply minimal fix inside `WORK_DIR`
  - IF: Figma URL → CALL: figma-design-context skill (Workflow A, node scoped to the fix) → reuse the existing `<plan-folder>/figma/` cache (never create a new one) → re-verify against cached spec
  - DO: run narrowest test from `WORK_DIR`; fix failures
  - EMIT: mark `[x]` + update `_Files_:` + append changelog

## Phase 4 — Update Docs

- LOOP: each `task-NNN.md` touched → re-open `[ ]` + re-mark `[x]` + changelog
- IF: AC gap in `plan.md` → correct AC row + changelog
- IF: shared contract changed → add warning in sibling tasks

## Phase 5 — Git Workflow

> **Do NOT stop until pipeline green AND zero unresolved threads.**

### 5a — Commit & Push

- CALL: COMMIT(WORK_DIR, `fix({repo}): {summary} [GOBIZWKST2-{TICKET_NUM}]`) → COMMITTED
- CALL: PUSH(WORK_DIR, BRANCH) → WORKTREE_TEARDOWN → ENSURE_MR → MR_IID, MR_URL

### 5b — Poll Until Clean

- CALL: POLL_PIPELINE(ENCODED, MR_IID, COMMITTED)
- LOOP: until (pipeline=success AND threads=0) OR terminal exit
  - ON_SUCCESS + threads>0: evaluate → WORKTREE_SETUP → fix → COMMIT → PUSH → TEARDOWN → RESOLVE → reset poll
  - ON_FAILURE: inspect logs → WORKTREE_SETUP → fix → COMMIT → PUSH → TEARDOWN → reset poll

### 5c — Terminal Exits

| Condition | Action |
|---|---|
| Pipeline success + 0 threads | ✅ Proceed to Phase 6 |
| 3 consecutive failures | BLOCKED — stop |
| 20 polls | TIMEOUT — stop |

## Phase 6 — Report

- EMIT: jira-prompt (A: comment | B: changes | C: skip)
- EMIT: summary — fix folder, items resolved, files, tests, MR URL, pipeline

## Constraints

- Fix only what is in current fix file — no refactoring
- Never mark `[x]` until test passes
- Never read existing `fix-*.md` from previous runs
- Don't modify `plan.md` unless AC gap confirmed
