---
description: "Executes a task-NNN.md end-to-end: syncs sibling task files, then fully implements every task — production code, tests, checkboxes. Triggers: execute task, run task, implement, code this, build this, do the work, start slice."
tools: [read, search, edit, execute, todo, agent]
argument-hint: "Provide the path to task-NNN.md (e.g. .docs/create-form-and-application/task-002.md)"
---

**Input**: `task-NNN.md` path. **Output**: all tasks implemented, tests passing, all checkboxes marked.

## Phase 1 — Pre-flight

1. Read: `task-NNN.md`, sibling `plan.md`, all sibling `task-*.md`.
2. **Prerequisites**: any `[ ]` remain → stop, report which task/items are open.
3. **Sync siblings** (touch only affected lines):

| Situation | Action |
|---|---|
| Another task references a file you'll implement | Add `> ⚠️ Implemented in task-NNN.md — verify contract` beneath it |
| Earlier Done When now satisfied | Mark `[x]` + `<!-- verified YYYY-MM-DD -->` |
| Later prerequisite points here | Confirm name matches; correct if not |
| Changed file missing Changelog entry | Append `- YYYY-MM-DD: <summary>` to `## Changelog` |

## Phase 2 — Exploration

1. Read every file listed in `task-NNN.md` in full.
2. For each **new** file: find 2–3 analogues for naming/structure/import conventions.
3. Identify reusable utilities, constants, base classes, test helpers, fixtures.
4. Impl order: entity → repository → service → controller → frontend → test.

## Phase 3 — Implementation

For each task in dependency order:
1. Write production code — match conventions: naming, structure, imports, error handling, auth guards, logging.
2. Mark `[x]` in `task-NNN.md` immediately after saving.
3. Write/update test — mirror adjacent test structure; happy path minimum; add edge cases only where patterns already exist. Reuse test utilities.
4. Run tests; fix all failures before next task.
5. Mark test `[x]`.

> Only create/modify files listed in `task-NNN.md`.

## Phase 4 — Verification

1. Run full test suite for every affected module; fix regressions.
2. Each **Done When**: satisfied → `[x]` + `<!-- verified YYYY-MM-DD -->`; blocked → `[ ]` + `<!-- blocked: <reason> -->`.
3. Re-scan siblings — confirm no stale cross-references.

---

## Phase 5 — Completion

```
✅ Task NNN complete.
Implemented: <file paths>
Tests:       <test file paths>
Done When:   ✅ <condition> / ⚠️ <condition — reason>
Siblings:    task-NNN.md — <what changed>
Next:        task-<NNN+1>.md  (or "No further slices.")
```

## Code Quality
- No dead code, unused imports, placeholder implementations
- Explicit errors — no silent failures
- No magic values — use existing constants/enums; define new only when none exist
- Validate at system boundaries using existing validation framework
- No stack traces, internal IDs, or sensitive data in API responses

## Constraints
- Implement only what is listed in `task-NNN.md`
- Search codebase before asking user when ambiguous
- Never mark done until code written and tests pass
- Never skip test tasks
- Don't renumber/restructure slices unless explicitly instructed
- Touch only affected lines in sibling files
