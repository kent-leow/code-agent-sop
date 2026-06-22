---
description: "Fixes post-implementation issues raised against completed task slices: applies code fixes based on review comments, bug reports, or failing tests, then creates a new .docs/fix-{datetime}-{name}/ folder with fix-{datetime}.md and updates task/plan docs. Triggers: fix, bug, review comment, regression, failing test, broken, hotfix, post-implementation, issue raised, address comment, fix feedback, patch, fix review."
tools: [read, search, edit, execute, todo]
argument-hint: "Provide: (1) folder path containing plan.md / task-NNN.md, and (2) issues.md path or raw issue text."
---

**Input**: folder path + `issues.md` path OR raw text → **Output**: new fix folder + file, fixes applied, docs updated.

---

## Phase 1 — Ingest Issues

- DO: resolve folder — IF absent → ask before proceeding
- IF: `issues.md` path → DO: read only that file; extract each issue as numbered item
- IF: raw text → DO: treat each line/bullet as separate issue
- DO: skim context — `plan.md` (first 80 lines), each `task-NNN.md` (headings + checklists)
- IF: existing `fix-*.md` files → DO NOT read them

## Phase 2 — Create Fix Folder & File

- STORE: DATETIME = `YYYYMMDD-HHMMSS`
- STORE: NAME = short kebab-case from primary issue (max 5 words, no generic names)
- STORE: FIX_FOLDER = `.docs/fix-{DATETIME}-{NAME}/` at workspace root
- STORE: FIX_FILE = `FIX_FOLDER/fix-{DATETIME}.md`
- IF: existing folder matches AND has no `fix-*.md` → reuse; else create new
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
  - DO: apply minimal fix
  - DO: run narrowest covering test
  - IF: test fails → DO: fix before continuing
  - EMIT: mark `[x]` + update `_Files_:` + append changelog

## Phase 4 — Update Docs

- LOOP: each `task-NNN.md` whose code was touched
  - DO: re-open `[ ]` + `<!-- re-opened: FIX-NNN YYYY-MM-DD -->`
  - DO: re-mark `[x]` once verified + `<!-- fixed: YYYY-MM-DD -->`
  - DO: append changelog
- IF: fix reveals AC gap in `plan.md` → DO: add/correct AC row + changelog
- IF: fix changes shared contract → DO: add `> ⚠️ Contract changed` in sibling tasks

## Phase 5 — Report

- EMIT: summary

```
✅ All fixes applied.
Fix folder: <FIX_FOLDER> — N items resolved
Fix file:   <FIX_FILE>
Files:      <list>
Tests:      ✅ / ⚠️
```

## Constraints

- Read source files only as needed — no speculative reads
- Fix only what is in current `fix-{datetime}.md` — no refactoring
- Never mark `[x]` until test passes
- Never read existing `fix-*.md` from previous runs
- Don't modify `plan.md` unless AC gap confirmed
- Don't renumber/restructure task files
