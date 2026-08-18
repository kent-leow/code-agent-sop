---
description: "Generate or refine task-NNN.md files. Auto-detects mode: no task files exist → generate from plan.md; task files exist or task-NNN.md path provided → refine. Triggers: generate tasks, ready to implement, break down plan, generate subtasks, update task, add task, change implementation detail, correct file path, adjust slice."
tools: [read, search, edit, execute, todo]
argument-hint: "Generate: provide path to plan.md. Refine: provide path to task-NNN.md and your corrections."
---

**Input**: `plan.md` path (Generate) or `task-NNN.md` path + changes (Refine) → **Output**: self-contained vertical-slice task files.

## Mode Detection

| Condition | Mode |
|---|---|
| `plan.md` path AND no `task-*.md` in folder | **Generate** |
| `task-NNN.md` path or task files exist with changes | **Refine** |

---

## Generate Mode

- IF: unresolved blocking questions in `plan.md` → STOP
- DO: explore codebase (structure, patterns, test locations, shared utils)
- IF: Figma URL → CALL: figma-design-context skill (Workflow A step 5: `get-components.sh`) → cache under `<plan-folder>/figma/` per skill's Caching Convention — check cache before re-fetching → map INSTANCE nodes to codebase equivalents
- DO: design slices — each complete, runnable, independently testable
  - Seams: data layer → service+API → frontend → e2e
  - Target half-day to two-day per slice
- LOOP: each slice → write `task-NNN.md` per Template
- EMIT: `Generated <N> task(s)`

### Template

```md
# Task NNN — <Slice Title>

## Goal
One sentence: what this slice delivers and how to verify.

## Prerequisites
- [ ] task-NNN.md completed (or "None")

## Tasks

### <Layer Name>
- [ ] `path/to/file.ext` — <what to create/change> (new)
  - [ ] `path/to/file.spec.ext` — <test behaviours>

## Done When
- [ ] <Observable condition>
- [ ] All new/modified tests pass
- [ ] No existing tests broken
```

### Content Rules

- Paths: repo-root-relative; mark new `(new)`; use `<TBD: desc>` if unknown
- Tests: indented child per logic file; happy + edge cases
- Done When: observable without reading code; mirrors plan AC

## Refine Mode

- DO: read task file + sibling `plan.md`; search unfamiliar paths
- DO: apply changes:

| Change | Action |
|---|---|
| Path correction | Update task + test checkbox |
| Added task | Insert in correct layer; add test |
| Removed task | Delete + adjust Done When |
| Logic update | Rewrite affected line only |
| New test coverage | Add indented child |

- DO: verify all logic tasks have test children; Done When reflects tasks
- DO: append `## Changelog`
- DO: run Consistency Check (flag, don't auto-fix):
  - No orphaned tests · No logic without test · Prerequisites accurate · Done When aligned · No duplicates

## Constraints

- No code — describe what to write, not the code itself
- No invented files/patterns absent from codebase or plan
- Every logic change must have test task
- Each task file self-contained; no duplicates across files
- Never merge/split slices unless explicitly asked
