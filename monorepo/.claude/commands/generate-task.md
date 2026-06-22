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
| `task-NNN.md` path + corrections, OR task files exist with changes | **Refine** |

## Generate Mode

- IF: `plan.md` has unresolved blocking questions → STOP: tell user to resolve first
- DO: explore codebase (file structure, naming, backend/frontend patterns, test locations, shared utilities)
- DO: design slices — each complete, runnable, independently testable
  - Typical seams: data layer → service+API → frontend → e2e
  - Target ~half-day to two-day effort per slice
- LOOP: each slice → DO: write `task-NNN.md` per Template
- EMIT: `Generated <N> task(s) in .docs/<folder>/: task-001 — <summary>`

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
  - [ ] `path/to/file.spec.ext` — <behaviours: happy path, validation, auth, edge>

## Done When
- [ ] <Observable condition>
- [ ] All new/modified tests pass
- [ ] No existing tests broken
```

### Content Rules

- Paths: repo-root-relative; mark new `(new)`; use `<TBD: desc>` if unknown
- Tests: indented child per logic file; happy path + edge cases
- Done When: observable without reading code; mirrors plan AC
- Never overwrite existing task file

## Refine Mode

- DO: read task file + sibling `plan.md`; search codebase for unfamiliar paths
- DO: apply changes per type:

| Change | Action |
|---|---|
| Path correction | Update task + test checkbox |
| Added task | Insert in correct `### Layer`; add test |
| Removed task | Delete task + test; adjust Done When |
| Logic update | Rewrite only affected line |
| New test coverage | Add indented child |
| New file group | Add `### Layer` with tasks + tests |

- DO: verify all logic tasks have test children; Done When reflects tasks
- DO: append `## Changelog`: `- YYYY-MM-DD: <summary>`
- DO: run Consistency Check (flag, don't auto-fix):

| Check | Pass if |
|---|---|
| No orphaned tests | Every test has parent task |
| No logic without test | Every logic file has test child |
| Prerequisites accurate | Listed prior tasks exist |
| Done When covers goal | Aligned |
| No duplicates | Same file not listed twice |

## Constraints

- No code — describe what to write, not the code
- No invented files/patterns absent from codebase or plan
- Every logic change must have test task
- Each task file self-contained; no duplicates across files
- Modify only affected sections when refining
- Never merge/split slices unless explicitly asked
