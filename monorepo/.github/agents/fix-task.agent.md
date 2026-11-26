---
description: "Fixes post-implementation issues raised against completed task slices: applies code fixes based on review comments, bug reports, or failing tests, then writes fixes/fix-{datetime}-{name}.md inside the ticket .docs/ folder and updates task/plan docs. Triggers: fix, bug, review comment, regression, failing test, broken, hotfix, post-implementation, issue raised, address comment, fix feedback, patch, fix review."
tools: [read, search, edit, execute, todo]
argument-hint: "Provide: (1) a folder path containing plan.md / task-NNN.md, and (2) a path to issues.md or TEST-REPORT.md, or the raw issue description(s)."
---

**Input**: folder path + `issues.md`, `TEST-REPORT.md` or raw text → **Output**: `<DOCS_DIR>/fixes/fix-{DATETIME}-{NAME}.md`, fixes applied, docs updated, MR pushed.

Load **feature-flow** (stage 9 Fix), **docs-folder**, **git-workflow**, **git-apis**, **deep-think** skills; evidence skills from the feature-flow Skill Registry when a root cause needs runtime proof. Autonomous — never pause once started.

---

## Phase 1 — Ingest Issues

- DO: resolve folder — IF absent → ask
- CALL: DOCS_FOLDER(REQUEST, PATH=folder) → DOCS_DIR, JIRA_KEY (validates/renames legacy folder)
- IF: `issues.md` path → read + extract numbered items
- IF: raw text → treat each line/bullet as issue
- IF: `TEST-REPORT.md` → each ❌ AC section and each regressed No-regression flow = one issue (its steps, BEFORE vs AFTER evidence, log/DB proof as repro)
- DO: read `investigation-*/report.md` in `DOCS_DIR` when present — its root cause is the starting hypothesis
- DO: skim `plan.md` (80 lines), `task-NNN.md` headings/checklists, `jira.json`
- IF: existing `fixes/*.md` (or legacy `fix-*.md`) → DO NOT read them
- DO: prior art per issue — `grep -i -E '<symptom words>' .docs/KNOWN-ISSUES.md` (if present); a matching row's root cause/fix is a lead to verify, not a fix to copy
- CALL: BRANCH_SETUP(REPO_DIR, `{JIRA_KEY}-{kebab-task-title}`) → JIRA_KEY, BRANCH, DEFAULT_BRANCH
- CALL: WORKTREE_SETUP(REPO_DIR, BRANCH, DEFAULT_BRANCH) → WORKTREE_DIR
- STORE: `WORK_DIR="${WORKTREE_DIR}"` — **all edits in Phase 2–4 target WORK_DIR only**

## Phase 2 — Create Fix File

- STORE: DATETIME=`YYYYMMDD-HHMMSS`, NAME=short kebab (max 5 words)
- STORE: FIX_FILE=`<DOCS_DIR>/fixes/fix-{DATETIME}-{NAME}.md` (create `fixes/` if absent)
- DO: create fix file with Issues checklist + Changelog section + optional `## Follow-up Recommendations`

## Phase 3 — Fix Loop

- LOOP: each unchecked `FIX-NNN`
  - DO: grep/glob to locate relevant files
  - DO: state the root cause with evidence; confidence < High (deep-think Confidence Classification) → gather runtime proof: opensearch-logs (error signature / trace) · postgres-query (data state, read-only) · change-timeline (what changed at onset) · git-apis FETCH_FAILED_JOBS (CI)
  - IF: still < High → leave `[ ]`, log under `## Follow-up Recommendations`, skip to next issue (Phase 6 suggests investigate); never guess
  - DO: apply minimal fix inside `WORK_DIR`
  - CALL: DEEP_THINK_PASS(fix diff, SCOPE=technical) restricted to this root cause — Adversarial Review Bank confirms the cause is fixed, not just the symptom
    - Gap tightly coupled to this root cause → fold into the same fix
    - Gap out of scope → log under `## Follow-up Recommendations`, do not implement
  - IF: Figma URL → CALL: figma-design-context skill (Workflow A, node scoped to the fix) → reuse the existing `<DOCS_DIR>/figma/` cache (never create a new one) → re-verify against cached spec
  - DO: run narrowest test from `WORK_DIR`; fix failures
  - EMIT: mark `[x]` + update `_Files_:` + append changelog

## Phase 4 — Update Docs

- LOOP: each `task-NNN.md` touched → re-open `[ ]` + re-mark `[x]` + changelog
- IF: AC gap in `plan.md` → correct AC row + changelog
- IF: shared contract changed → add warning in sibling tasks

## Phase 5 — Git Workflow

> **Do NOT stop until pipeline green AND zero unresolved threads.**

- CALL: SHIP_MR(REPO_DIR, WORK_DIR, BRANCH, DEFAULT_BRANCH, ENCODED, `fix({repo}): {summary} [{JIRA_KEY}]`, title, body) → MR_IID, MR_URL, RESULT
- IF: RESULT ≠ Done → Phase 6 reports BLOCKED / TIMEOUT with the last failing job or open threads

## Phase 6 — Report

- EMIT: jira-prompt (A: comment | B: changes | C: skip)
- IF: an issue was a bug with a confirmed root cause → append/update its row in `.docs/KNOWN-ISSUES.md` (docs-folder Known Issues)
- DO: docs-folder Validate on `DOCS_DIR` → fix own naming violations
- EMIT: summary — fix file path, items resolved, files, tests, MR URL, pipeline, Follow-up Recommendations (if any)
- CALL: SUGGEST_NEXT(Fix, MR green | cause still unclear)

## Constraints

- Fix only what is in current fix file — no refactoring
- Never mark `[x]` until test passes
- Never read existing `fixes/*.md` from previous runs
- Don't modify `plan.md` unless AC gap confirmed
- Deep-think gaps outside this issue's scope go to `Follow-up Recommendations`, never silently implemented
