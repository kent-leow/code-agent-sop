---
description: "Fixes post-implementation issues raised against completed task slices: applies code fixes based on review comments, bug reports, or failing tests, then updates fix.md and task/plan docs. Triggers: fix, bug, review comment, regression, failing test, broken, hotfix, post-implementation, issue raised, address comment, fix feedback, patch, fix review."
tools: [read, search, edit, execute, todo, com.figma.mcp/mcp/*]
argument-hint: "Provide: (1) a folder path containing plan.md / task-NNN.md (and optionally fix.md), and (2) the issue description or list of issues. Example: '.docs/my-feature fix.md' or '.docs/my-feature null check on userId'"
---

**Input**: folder path containing `plan.md` + `task-NNN.md` (and `fix.md` if already created) + issue description(s).
**Output**: `fix.md` created/updated with checkboxes; all fixes applied; docs updated.

---

## Phase 1 — Ingest

1. **Resolve folder**: the input must include a folder path. If absent, ask for it before proceeding.
2. **Check for `fix.md`** in that folder:
   - **Exists** → read it; use its unchecked items (`- [ ]`) as the work queue. Skip re-generation.
   - **Missing** → proceed to Phase 2.
3. **Skim context** (do not deep-read source files yet):
   - Read `plan.md` — headings, AC table, Changelog only (first 80 lines or until `## Tasks`).
   - Read each `task-NNN.md` — headings + checklist lines only (grep for `- [ ]` / `- [x]`).
   - Read `jira.json` if present — note sub-task keys.

---

## Phase 2 — Generate `fix.md`

> Skip if `fix.md` already exists.

Synthesise all issues from the user input + any gaps inferred from the skimmed plan/task context.
Create `<folder>/fix.md` with the structure below — one checkbox per discrete issue:

```markdown
# Fix Log

> Generated: YYYY-MM-DD

## Issues

- [ ] **FIX-001** — <one-line description>  
  _Source_: <review comment | bug report | inferred from task-NNN.md>  
  _Files_: unknown (resolve in Phase 3)

- [ ] **FIX-002** — <one-line description>
  ...

## Changelog
```

Number items `FIX-001`, `FIX-002`, … in order of input.

---

## Phase 3 — Fix Loop

Work through every unchecked item in `fix.md` sequentially. For each item:

### 3a — Locate
- Add the item to the `todo` list (in-progress).
- Do a **targeted search** (grep/glob on the folder or repo) to find the relevant file(s). Read only the sections needed — do not load entire files unless the fix clearly requires full context.
- If context from `plan.md` or a `task-NNN.md` is required, re-read only the relevant section.

### 3b — Fix
- Apply minimal, targeted changes. No refactoring or unrelated edits.
- **Figma** (UI fixes — layout, component, or styling):
  - Cache: `figma/<nodeId>.{json,png,md}` relative to the folder.
  - **Hit** → read `figma/<nodeId>.md` + `view_image`; skip fetch.
  - **Miss**: Try MCP (`mcp_com_figma_mcp_get_design_context` + `mcp_com_figma_mcp_get_screenshot`) → save; `view_image`. MCP unavailable → load `.github/skills/figma-design-context/SKILL.md` → save; `view_image`.

### 3c — Verify
- Run the narrowest test that covers the change (unit > integration > full suite). Fix failures before continuing.

### 3d — Mark done in `fix.md`
Update the item:
```markdown
- [x] **FIX-001** — <description> <!-- fixed: YYYY-MM-DD -->
  _Files_: path/to/changed/file.kt, path/to/other.kt
```
Append to `## Changelog`:
```markdown
- YYYY-MM-DD: FIX-001 — <summary>
```

Mark the `todo` item completed, then move to the next unchecked item.

---

## Phase 4 — Update Task / Plan Docs

After all `fix.md` items are checked:

### task-NNN.md
For each task whose code was touched:
- Re-open affected checkbox: `- [ ]` + `<!-- re-opened: FIX-NNN YYYY-MM-DD -->`
- Re-mark once verified: `- [x]` + `<!-- fixed: YYYY-MM-DD -->`
- Append to `## Changelog`: `- YYYY-MM-DD: Fixed (FIX-NNN) — <summary>`

### plan.md
Update **only** if an issue reveals a gap in AC (missing edge case, incorrect Given/When/Then):
- Add or correct the violated AC row.
- Append to `## Changelog`: `- YYYY-MM-DD: AC updated — <summary>`
- Do not change scope, estimates, or unrelated AC rows.

### Sibling task files
If a fix changes a shared contract (API shape, DTO field, util signature):
- Add `> ⚠️ Contract changed — verify task-NNN.md` beneath each affected task row in siblings.
- Touch only those lines.

---

## Phase 5 — Report

> ✅ All fixes applied.
>
> **fix.md**: `<folder>/fix.md` — N items resolved  
> **Files changed**: <list>  
> **Tests**: ✅ all pass / ⚠️ <caveats>
>
> **A** — Update Jira Sub-task &nbsp; **B** — Further changes &nbsp; **C** — Skip

- **A** — Use `.github/skills/jira-ticket/SKILL.md`. Read `jira.json`; add a comment to the existing sub-task describing the fixes. Do not create a new ticket.
  - Missing `jira.json`, entry, or env vars → `⚠️ Jira skipped — set JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL`
- **B** — Apply changes; re-present report.
- **C** — Stop.

---

## Constraints
- Never deep-read source files speculatively — read only what a specific fix requires
- Fix only what is described in `fix.md` — no refactoring
- Never mark an item `[x]` until the test passes
- Do not create files other than `fix.md` unless the fix explicitly requires a new test or config entry
- Do not modify `plan.md` unless an AC gap is confirmed
- Do not renumber or restructure task files
