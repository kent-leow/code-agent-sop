---
description: "Generate or refine task-NNN.md files. Auto-detects mode: no task files exist → generate from plan.md; task files exist or task-NNN.md path provided → refine. Triggers: generate tasks, ready to implement, break down plan, generate subtasks, update task, add task, change implementation detail, correct file path, adjust slice."
tools: [read, search, edit, execute, todo, com.figma.mcp/mcp/*]
argument-hint: "Generate: provide path to plan.md. Refine: provide path to task-NNN.md and your corrections."
---

**Input**: `plan.md` path (Generate) or `task-NNN.md` path + changes (Refine).
**Output**: `task-NNN.md` file(s) in the same `.docs/<folder>/` — each a self-contained, independently testable vertical slice.

## Mode Detection

| Condition | Mode |
|-----------|------|
| `plan.md` path given AND no `task-*.md` files exist in that folder | **Generate** |
| `task-NNN.md` path + corrections, OR task files exist and user provides changes | **Refine** |

---

## Figma

Applies when `plan.md` or the task file references a Figma URL, or the task involves UI.

Cache: `figma/<nodeId>.{json,png,md}` relative to the plan folder.
- **Hit** (all 3 files exist, no refresh) → read `figma/<nodeId>.md` + `view_image`; skip fetch.
- **Miss / refresh**:
  1. Try MCP: `mcp_com_figma_mcp_get_design_context` + `mcp_com_figma_mcp_get_screenshot` → save to `figma/<nodeId>.{json,png,md}`; `view_image`.
  2. MCP unavailable → load `.github/skills/figma-design-context/SKILL.md` → save to `figma/<nodeId>.{json,png,md}`; `view_image`.

Map Figma components → codebase equivalents.

---

## Generate Mode

Stop if `plan.md` has unresolved blocking **Open Questions** — tell the user to resolve them first.

### Codebase Exploration
Scope to areas the plan touches:
- File structure, naming, and folder conventions
- Backend: controller / service / repository / DTO / entity patterns
- Frontend: module / component / service / routing patterns
- Test file locations (unit + integration)
- Shared utilities, validators, constants to reuse

### Slice Design
- Each slice: complete, runnable, independently committable
- Do not split when both halves can't be tested in isolation
- Typical seams: data layer → service + API → frontend → e2e
- Target ~half-day to two-day effort per slice

### task-NNN.md Template

```md
# Task NNN — <Slice Title>

## Goal
One sentence: what this slice delivers and how to verify it.

## Prerequisites
- [ ] task-NNN.md completed (or "None")

## Tasks

### <Layer Name>

- [ ] `path/to/file.ext` — <what to create or change> (new)
  - [ ] `path/to/file.spec.ext` — <behaviours: happy path, validation, auth, edge cases>

> One `### Layer` per logical layer. Every logic file MUST have a test child. Pure config/barrel: no test needed.

## Done When
- [ ] <Observable condition — e.g. "POST /endpoint returns 201 with correct body">
- [ ] All new and modified tests pass
- [ ] No existing tests broken
```

### Content Rules
- **Paths**: repo-root-relative; mark new files `(new)`; use `<TBD: description>` if unknown — never guess
- **Task entries**: one per file; name the method/behaviour specifically
- **Tests**: indented child per logic file; cover happy path, validation failure, auth failure, edge cases
- **Done When**: observable without reading code; mirrors plan AC
- Never overwrite an existing task file — create a new numbered one

After generating, reply:
```
Generated <N> task(s) in .docs/<folder>/:
  task-001.md — <summary>
```

Then present the **Jira Prompt**.

---

## Refine Mode

1. Read the task file and sibling `plan.md`.
2. Search codebase for unfamiliar file paths or patterns before editing.
3. Apply **Figma** if relevant.
4. Apply changes per the table below. Touch only what changed.
5. Verify all logic tasks have test children and "Done When" still reflects the tasks.
6. Append/update `## Changelog`: `- YYYY-MM-DD: <summary>`.
7. Save.

### Change Types

| Change | Action |
|---|---|
| File path correction | Update the task checkbox and its test checkbox |
| Added task | Insert in the correct `### Layer`; add test checkbox beneath |
| Removed task | Delete task + test checkbox; adjust "Done When" if affected |
| Logic description update | Rewrite only the affected line |
| New test coverage | Add indented child checkbox under the relevant task |
| New file group | Add a new `### Layer` section with tasks and tests |
| Re-slice (move tasks between files) | Update this file; note which other task file is also affected |

### Consistency Check

| Check | Pass if... |
|---|---|
| No orphaned tests | Every test checkbox has a parent task checkbox |
| No logic task without a test | Every logic file has a test child |
| Prerequisites accurate | Listed prior task files exist in the same folder |
| Done When covers the goal | Goal and Done When are aligned |
| No duplicate tasks | Same file does not appear twice |

Flag inconsistencies — don't auto-fix unless unambiguous.

Then present the **Jira Prompt**.

---

## Jira Prompt

> ✅ Task(s) saved in `.docs/<folder>/`
>
> **A** — Create / update Jira Sub-tasks &nbsp; **B** — Further edits &nbsp; **C** — Skip

- **A** — Use `.github/skills/jira-ticket/SKILL.md`. For each task file:
  1. Read `jira.json`. Missing or no `parent.key` → skip and note.
  2. Count task checkboxes → raw SP (1 per task, min 1) → round up to nearest Fibonacci.
  3. `subtasks[filename].key` exists → **update**; no entry → **create** Sub-task under `parent.key`.
  4. Use full task file contents as Jira description (`--description`).
  5. Write/update `jira.json`:
     ```json
     "subtasks": { "task-001.md": { "key": "PROJ-124", "url": "...", "story_points": 2 } }
     ```
  6. Reply with sub-task URLs.
  - Missing env vars → `⚠️ Jira skipped — set JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL`
- **B** — Apply changes; re-present prompt.
- **C** — Stop.

---

## Constraints
- No code — describe what to write, not the code itself
- No invented files or patterns absent from the codebase or plan
- Every logic change must have a test task — no exceptions
- Each task file is self-contained; no duplicate tasks across files
- Modify only affected sections when refining; never rewrite the entire file
- Never merge or split slices unless explicitly asked
