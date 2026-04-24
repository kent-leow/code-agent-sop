---
description: "Fixes post-implementation issues raised against completed task slices: applies code fixes based on review comments, bug reports, or failing tests, then creates a new fix-{datetime}.md and updates task/plan docs. Triggers: fix, bug, review comment, regression, failing test, broken, hotfix, post-implementation, issue raised, address comment, fix feedback, patch, fix review."
tools: [read, search, edit, execute, todo, com.figma.mcp/mcp/*]
argument-hint: "Provide: (1) a folder path containing plan.md / task-NNN.md, and (2) either a path to an issues.md file or the raw issue description(s). Example: '.docs/my-feature issues.md' or '.docs/my-feature null check on userId'"
---

**Input**: folder path + `issues.md` path OR raw issue text. **Output**: new `fix-{datetime}.md` created; all fixes applied; docs updated. Each invocation produces an isolated fix file — never appended to previous ones.

## Phase 1 — Ingest Issues

1. Resolve folder — if absent, ask before proceeding.
2. **If `issues.md` path provided** → read only that file; extract each issue as a numbered item. Do not read any other fix files.
3. **If raw text provided** → treat each line / bullet / numbered point as a separate issue item.
4. Skim context: `plan.md` (first 80 lines or until `## Tasks`), each `task-NNN.md` (headings + checklist lines only), `jira.json` (note sub-task keys). **Do not read any existing `fix-*.md` files.**

## Phase 2 — Create `fix-{datetime}.md`

Determine current datetime in `YYYYMMDD-HHMMSS` format. Always create a **new** file — never open or append to any existing `fix-*.md`.

Create `<folder>/fix-{datetime}.md`:

```markdown
# Fix Log

> Generated: YYYY-MM-DD HH:MM:SS

## Issues

- [ ] **FIX-001** — <one-line description>
  _Source_: <issues.md | raw input | inferred>
  _Files_: unknown (resolve in Phase 3)

## Changelog
```

Number items `FIX-001`, `FIX-002`, … in input order.

## Phase 3 — Fix Loop

For each unchecked item in the newly created `fix-{datetime}.md`:
1. **Locate** — `todo` in-progress. Targeted grep/glob to find relevant files; read only needed sections.
2. **Fix** — minimal, targeted changes only. **Figma** (UI): cache at `figma/<nodeId>.{json,png,md}` relative to folder. Hit → read md + `view_image`. Miss → try MCP → save; unavailable → load `.github/skills/figma-design-context/SKILL.md` → save.
3. **Verify** — run narrowest test covering the change. Fix failures before continuing.
4. **Mark done**:
```markdown
- [x] **FIX-001** — <description> <!-- fixed: YYYY-MM-DD -->
  _Files_: path/to/changed/file.kt
```
Append to `## Changelog`: `- YYYY-MM-DD: FIX-001 — <summary>`. Mark `todo` completed.

## Phase 4 — Update Task/Plan Docs

**task-NNN.md** (each task whose code was touched):
- Re-open: `- [ ]` + `<!-- re-opened: FIX-NNN YYYY-MM-DD -->`
- Re-mark once verified: `- [x]` + `<!-- fixed: YYYY-MM-DD -->`
- Append Changelog: `- YYYY-MM-DD: Fixed (FIX-NNN) — <summary>`

**plan.md** — only if fix reveals an AC gap:
- Add/correct violated AC row. Append Changelog. Don't change scope or unrelated rows.

**Sibling task files** — if fix changes shared contract:
- Add `> ⚠️ Contract changed — verify task-NNN.md` beneath affected task rows. Touch only those lines.

## Phase 5 — Report

> ✅ All fixes applied.
> **fix file**: `<folder>/fix-{datetime}.md` — N items resolved
> **Files changed**: <list>
> **Tests**: ✅ all pass / ⚠️ <caveats>
>
> **A** — Update Jira Sub-task &nbsp; **B** — Further changes &nbsp; **C** — Skip

- **A** — Load `.github/skills/jira-ticket/SKILL.md`. Read `jira.json`; add comment to existing sub-task. Don't create new ticket. Missing config → `⚠️ Jira skipped — set JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL`
- **B** — Apply; re-present report.
- **C** — Stop.

## Constraints
- Read source files only as needed per fix — no speculative reads
- Fix only what is in the current `fix-{datetime}.md` — no refactoring
- Never mark `[x]` until test passes
- Never read or open any existing `fix-*.md` files from previous runs
- Don't create files other than `fix-{datetime}.md` unless fix requires a new test/config entry
- Don't modify `plan.md` unless AC gap confirmed
- Don't renumber/restructure task files
