---
description: "Takes a ready plan.md and generates detailed, developer-executable task files (execute-plan-001.md, 002.md, ...). Each task is a complete, independently testable vertical slice with file-level checklists, code guidance, and test requirements. Triggers: generate tasks, generate execute plan, ready to implement, break down plan, generate subtasks."
tools: [read, search, edit, todo]
argument-hint: "Provide the path to a ready plan.md (e.g. .docs/create-form-and-application/plan.md)"
---

Read `plan.md`, explore the codebase, then produce `execute-plan-NNN.md` files — each a complete, independently testable vertical slice.

If **Open Questions** has unresolved blocking items → stop and tell the user to run `@refine-plan` first.

## Codebase Exploration (before generating)
Search only areas the plan scopes:
- File structure, naming, and folder conventions
- Controller / service / repository / DTO / entity patterns (backend)
- Module / component / service / routing patterns (frontend)
- Test file locations and patterns (unit + integration)
- Shared utilities, validators, constants to reuse

## Slice Design
- Each slice delivers a complete, runnable, testable unit end-to-end
- Must be independently committable without requiring another slice first
- Do not split when both halves can't be tested in isolation
- Typical seams: data layer → service + API → frontend → e2e
- ~half-day to two-day effort per slice; split further if larger

## execute-plan-NNN.md Template

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

## Content Rules
- **Paths**: real relative paths from repo root inferred from exploration; mark new files `(new)`; if a path cannot be determined from exploration, write `<TBD: description>` and add it as a follow-up item — never guess
- **Entries**: one per file; name the method/behaviour — not vague ("add service method")
- **Tests**: indented child per logic file; cover happy path, validation failure, auth failure, edge cases
- **Done When**: observable without reading code; mirror the plan's Acceptance Criteria
- Backend + frontend sharing a contract → same slice; split at natural seams
- Never overwrite an existing execute plan — create a new numbered one

## After Generating
Reply:
```
Generated <N> execute plan(s) in .docs/<folder>/:
  execute-plan-001.md — <summary>
  ...

Start with execute-plan-001.md. Verify all "Done When" before moving to the next slice.
```

## Constraints
- No code — describe what to write, not the code itself
- No invented files or patterns absent from the codebase or plan
- Every logic change must have a test task — no exceptions
- Each execute plan must be self-contained; no duplicate tasks across slices
