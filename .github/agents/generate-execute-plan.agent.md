---
description: "Generate or refine execute-plan-NNN.md files. Auto-detects mode: if execute-plan files already exist in the folder → refine; otherwise → generate from plan.md. Replaces @refine-execute-plan. Triggers: generate tasks, generate execute plan, ready to implement, break down plan, generate subtasks, update execute plan, fix task, add task, change implementation detail, correct file path, adjust slice."
tools: [read, search, edit, execute, todo, com.figma.mcp/mcp/*]
argument-hint: "Generate: provide path to plan.md. Refine: provide path to execute-plan-NNN.md and your corrections / additions."
---

Generate or refine execute-plan files for a `plan.md`. Detect the mode first, then proceed.

## Mode Detection

| Condition | Mode |
|-----------|------|
| Input is a `plan.md` path AND no `execute-plan-*.md` files exist in that folder | **Generate** |
| Input includes an `execute-plan-NNN.md` path + corrections, OR execute plans already exist and user provides changes | **Refine** |

---

## Figma (UI tasks)

Applies to both modes whenever `plan.md` or the execute plan references a Figma URL, or the task involves UI.

Cache: `figma/<nodeId>.{json,png,md}` relative to the plan folder.
- **Hit** (all three files exist, no update requested) → read `figma/<nodeId>.md` + `view_image` on `figma/<nodeId>.png`; skip fetching entirely.
- **Miss / refresh**:
  - **Try Figma MCP first**: call `mcp_com_figma_mcp_get_design_context` + `mcp_com_figma_mcp_get_screenshot`; save the design JSON to `figma/<nodeId>.json`, the screenshot to `figma/<nodeId>.png`, and write a human-readable summary to `figma/<nodeId>.md`; then `view_image`.
  - **If MCP is unavailable or blocked by admin**: load the `figma-design-context` skill (`.github/skills/figma-design-context/SKILL.md`) and follow its procedure, directing output to `figma/<nodeId>.{json,png,md}`; then `view_image`.

Map Figma components → codebase equivalents; use Code Connect names when present.

---

## Generate Mode

Read `plan.md`, explore the codebase, then produce `execute-plan-NNN.md` files — each a complete, independently testable vertical slice.

If **Open Questions** has unresolved blocking items → stop and tell the user to run `@generate-plan` first.

### Codebase Exploration
Search only areas the plan scopes:
- File structure, naming, and folder conventions
- Controller / service / repository / DTO / entity patterns (backend)
- Module / component / service / routing patterns (frontend)
- Test file locations and patterns (unit + integration)
- Shared utilities, validators, constants to reuse

### Slice Design
- Each slice delivers a complete, runnable, testable unit end-to-end
- Must be independently committable without requiring another slice first
- Do not split when both halves can't be tested in isolation
- Typical seams: data layer → service + API → frontend → e2e
- ~half-day to two-day effort per slice; split further if larger

### execute-plan-NNN.md Template

```md
# Execute Plan NNN — <Slice Title>

## Goal
One sentence: what this slice delivers and how to verify it.

## Prerequisites
- [ ] Prior slices completed (list, or "None")
- [ ] Environment / config / migration steps

## Tasks

### <Area Name>

- [ ] `path/to/file.ext` — <what to create or change> (new)
  - [ ] `path/to/file.spec.ext` — <behaviours to cover: happy path, validation, auth, edge cases>

> One `### Area` section per logical layer. Every logic file MUST have a test child. Pure config/barrel exports: no test needed.

## Done When
- [ ] <Observable condition — e.g. "POST /applications returns 201 with correct body">
- [ ] All new and modified tests pass
- [ ] No existing tests broken
```

### Content Rules
- **Paths**: real relative paths from repo root; mark new files `(new)`; write `<TBD: description>` if unknown — never guess
- **Entries**: one per file; name the method/behaviour — not vague ("add service method")
- **Tests**: indented child per logic file; cover happy path, validation failure, auth failure, edge cases
- **Done When**: observable without reading code; mirror the plan's AC
- Backend + frontend sharing a contract → same slice; split at natural seams
- Never overwrite an existing execute plan — create a new numbered one

### After Generating

Reply:
```
Generated <N> execute plan(s) in .docs/<folder>/:
  execute-plan-001.md — <summary>
  ...
```

Then present the **Jira Confirmation Prompt** and wait for the user's reply.

---

## Refine Mode

1. Read the execute-plan file and sibling `plan.md`.
2. If the change references unfamiliar files or patterns, do a targeted codebase search to verify paths.
3. Apply the **Figma** block above if relevant.
4. Apply changes per the table below. Touch only what changed.
5. Verify all logic tasks have test children; verify "Done When" still reflects the tasks.
6. Append/update `## Changelog`: `- YYYY-MM-DD: <one-line summary>`
7. Save.

### Change Types

| Change | How to handle |
|---|---|
| File path correction | Update the task checkbox and its test checkbox |
| Added task | Insert in the correct `### Area`; add test checkbox beneath it |
| Removed task | Delete task + test checkbox; adjust "Done When" if affected |
| Logic description update | Rewrite only the affected line |
| New test coverage | Add indented child checkbox under the relevant task |
| New file group | Add a new `### Area` section with tasks and tests |
| Re-slice (move tasks between slices) | Update this file; note which other slice file is also affected |

### Consistency Check (after saving)

| Check | Criteria |
|---|---|
| No orphaned tests | Every test checkbox has a parent task checkbox |
| No logic task without a test | Every file with new/changed logic has a test child |
| Prerequisites accurate | Listed prior slices exist in the same folder |
| "Done When" covers the goal | Goal sentence and Done When items are aligned |
| No duplicate tasks | Same file does not appear twice |

Flag inconsistencies even outside the user's change — flag, don't auto-fix unless unambiguous.

Then present the **Jira Confirmation Prompt** and wait for the user's reply.

---

## Jira Confirmation Prompt

Present after saving. **Wait for the user's reply before doing anything else.**

> ✅ Execute plan(s) saved/updated in `.docs/<folder>/`
>
> What would you like to do next?
> **A** — Create / update Jira Sub-tasks for each execute plan
> **B** — Make further updates to the execute plan(s)
> **C** — Nothing (skip Jira)

- **A** — Jira Sub-task sync (use the `jira-ticket` skill — `.github/skills/jira-ticket/SKILL.md`). For each execute-plan file:
  1. Read `jira.json` from the same folder. If missing or `parent.key` absent, skip and note.
  2. **If `subtasks[filename].key` is already set, you MUST update that key — never create a new sub-task for it.**
  3. Count task checkboxes → raw SP (1 per task, minimum 1), then round up to the nearest Fibonacci number (1, 2, 3, 5, 8, 13, 21, …).
  4. Use the full contents of the execute-plan file as the Jira description (pass as `--description`).
  5. Entry exists under `subtasks` for this filename → **update**; no entry → **create** as Sub-task under `parent.key`.
  5. Write/update `jira.json`:
     ```json
     "subtasks": {
       "execute-plan-001.md": { "key": "PROJ-124", "url": "...", "story_points": 2 }
     }
     ```
  6. Reply with all sub-task URLs.
  7. If JIRA env vars are missing: `⚠️ Jira skipped — set JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL`
- **B** — Wait for instructions; apply; re-present this prompt.
- **C** — Stop.

---

## Constraints
- No code — describe what to write, not the code itself
- No invented files or patterns absent from the codebase or plan
- Every logic change must have a test task — no exceptions
- Each execute plan must be self-contained; no duplicate tasks across slices
- Modify only affected sections when refining; never rewrite the entire file
- Task descriptions must be specific; never merge or split slices unless explicitly asked
