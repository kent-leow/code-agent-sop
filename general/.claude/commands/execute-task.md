---
description: "Executes a task-NNN.md end-to-end: syncs sibling task files, then fully implements every task — production code, tests, checkboxes. Triggers: execute task, run task, implement, code this, build this, do the work, start slice."
tools: [read, search, edit, execute, todo, agent]
argument-hint: "Provide the path to task-NNN.md (e.g. .docs/create-form-and-application/task-002.md)"
---

**Input**: `task-NNN.md` path → **Output**: all tasks implemented, tests pass, checkboxes marked.

## Phase 1 — Pre-flight

- DO: read `task-NNN.md`, sibling `plan.md`, all `task-*.md`
- IF: any `[ ]` in prerequisites → STOP: report open items
- DO: sync siblings (touch only affected lines):

| Situation | Action |
|---|---|
| Another task references file you'll implement | Add `> ⚠️ Implemented in task-NNN — verify contract` |
| Earlier Done When now satisfied | Mark `[x]` + `<!-- verified YYYY-MM-DD -->` |
| Later prerequisite points here | Confirm name matches; correct if not |
| Changed file missing Changelog | Append `- YYYY-MM-DD: <summary>` |

## Phase 2 — Exploration

- DO: read every file listed in `task-NNN.md` in full
- DO: for each new file → find 2–3 analogues for conventions
- DO: identify reusable utilities, constants, base classes, test helpers
- STORE: impl order = entity → repository → service → controller → frontend → test

## Phase 3 — Implementation

- LOOP: each task in dependency order
  - DO: write production code — match conventions (naming, imports, error handling, auth, logging)
  - DO: mark `[x]` in `task-NNN.md`
  - DO: write/update test — mirror adjacent structure; happy path min; reuse test utilities
  - DO: run tests; fix all failures before next
  - DO: mark test `[x]`
- IF: file not listed in `task-NNN.md` → STOP: do not create/modify

## Phase 4 — Verification

- DO: run full test suite for affected modules; fix regressions
- LOOP: each Done When item
  - IF: satisfied → mark `[x]` + `<!-- verified YYYY-MM-DD -->`
  - IF: blocked → mark `[ ]` + `<!-- blocked: <reason> -->`
- DO: re-scan siblings for stale cross-references

## Phase 5 — Completion

- EMIT: summary

```
✅ Task NNN complete.
Implemented: <paths>
Tests:       <test paths>
Done When:   ✅ / ⚠️
Siblings:    task-NNN — <changes>
Next:        task-<NNN+1>.md
```

## Constraints

- Implement only what `task-NNN.md` lists
- Search codebase before asking user
- Never mark done until code written + tests pass
- Never skip test tasks
- No dead code, unused imports, placeholder implementations
- Explicit errors — no silent failures
- No magic values — use existing constants/enums
- Validate at system boundaries
