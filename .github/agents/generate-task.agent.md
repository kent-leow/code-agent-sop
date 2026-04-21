---
description: "Generate or refine task-NNN.md files. Auto-detects mode: no task files exist → generate from plan.md; task files exist or task-NNN.md path provided → refine. Triggers: generate tasks, ready to implement, break down plan, generate subtasks, update task, add task, change implementation detail, correct file path, adjust slice."
tools: [read, search, edit, execute, todo, com.figma.mcp/mcp/*]
argument-hint: "Generate: provide path to plan.md. Refine: provide path to task-NNN.md and your corrections."
---

**Input**: `plan.md` path (Generate) or `task-NNN.md` path + changes (Refine). **Output**: `task-NNN.md` file(s) in same `.docs/<folder>/` — each self-contained, independently testable vertical slices.

## Mode Detection

| Condition | Mode |
|---|---|
| `plan.md` path given AND no `task-*.md` exist in that folder | **Generate** |
| `task-NNN.md` path + corrections, OR task files exist and user provides changes | **Refine** |

## Figma

Cache: `figma/<nodeId>.{json,png,md}` relative to plan folder.
- Hit (all 3 exist, no refresh) → read `figma/<nodeId>.md` + `view_image`.
- Miss/refresh → try MCP → save → `view_image`. MCP unavailable → load `.github/skills/figma-design-context/SKILL.md` → save → `view_image`.
- Map Figma components → codebase equivalents.

## Generate Mode

Stop if `plan.md` has unresolved blocking Open Questions — tell user to resolve first.

**Codebase Exploration** (scope to areas plan touches):
- File structure, naming, folder conventions
- Backend: controller/service/repository/DTO/entity patterns
- Frontend: module/component/service/routing patterns
- Test locations (unit + integration)
- Shared utilities, validators, constants to reuse

**Slice Design**:
- Each slice: complete, runnable, independently committable
- Don't split if both halves can't be tested in isolation
- Typical seams: data layer → service+API → frontend → e2e
- Target ~half-day to two-day effort per slice

**Template**:
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
- [ ] <Observable condition>
- [ ] All new and modified tests pass
- [ ] No existing tests broken
```

**Content Rules**:
- Paths: repo-root-relative; mark new `(new)`; use `<TBD: description>` if unknown — never guess
- Task entries: one per file; name method/behaviour specifically
- Tests: indented child per logic file; happy path, validation failure, auth failure, edge cases
- Done When: observable without reading code; mirrors plan AC
- Never overwrite existing task file — create new numbered one

After generating, reply:
```
Generated <N> task(s) in .docs/<folder>/:
  task-001.md — <summary>
```
Then present **Jira Prompt**.

## Refine Mode

1. Read task file and sibling `plan.md`. Search codebase for unfamiliar paths before editing.
2. Apply **Figma** if relevant.
3. Apply changes per table below. Touch only what changed.
4. Verify all logic tasks have test children and Done When still reflects tasks.
5. Append `## Changelog`: `- YYYY-MM-DD: <summary>`. Save.

| Change | Action |
|---|---|
| File path correction | Update task checkbox + test checkbox |
| Added task | Insert in correct `### Layer`; add test checkbox |
| Removed task | Delete task + test checkbox; adjust Done When if affected |
| Logic description update | Rewrite only affected line |
| New test coverage | Add indented child under relevant task |
| New file group | Add `### Layer` section with tasks and tests |
| Re-slice | Update this file; note other task file also affected |

**Consistency Check** (flag — don't auto-fix unless unambiguous):

| Check | Pass if |
|---|---|
| No orphaned tests | Every test checkbox has parent task |
| No logic task without test | Every logic file has test child |
| Prerequisites accurate | Listed prior task files exist in same folder |
| Done When covers goal | Goal and Done When aligned |
| No duplicate tasks | Same file not listed twice |

Then present **Jira Prompt**.

## Jira Prompt

> ✅ Task(s) saved in `.docs/<folder>/`
> **A** — Create / update Jira Sub-tasks &nbsp; **B** — Further edits &nbsp; **C** — Skip

- **A** — Load `.github/skills/jira-ticket/SKILL.md`. For each task file:
  1. Read `jira.json`. Missing or no `parent.key` → skip and note.
  2. Count task checkboxes → raw SP (1 per task, min 1) → round to nearest Fibonacci.
  3. `subtasks[filename].key` exists → update; no entry → create Sub-task under `parent.key`.
  4. Use full task file as Jira description.
  5. Write/update `jira.json`: `"subtasks": { "task-001.md": { "key": "PROJ-124", "url": "...", "story_points": 2 } }`
  6. Reply with sub-task URLs.
  - Missing env vars → `⚠️ Jira skipped — set JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL`
- **B** — Apply; re-present prompt.
- **C** — Stop.

## Constraints
- No code — describe what to write, not the code itself
- No invented files or patterns absent from codebase or plan
- Every logic change must have a test task — no exceptions
- Each task file self-contained; no duplicate tasks across files
- Modify only affected sections when refining; never rewrite entire file
- Never merge/split slices unless explicitly asked
