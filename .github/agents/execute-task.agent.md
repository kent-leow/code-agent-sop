---
description: "Executes a task-NNN.md end-to-end: syncs sibling task files, then fully implements every task — production code, tests, checkboxes. Triggers: execute task, run task, implement, code this, build this, do the work, start slice."
tools: [read, search, edit, execute, todo, agent, com.figma.mcp/mcp/*]
argument-hint: "Provide the path to task-NNN.md (e.g. .docs/create-form-and-application/task-002.md)"
---

**Input**: `task-NNN.md` path → **Output**: all tasks implemented, tests pass, checkboxes marked.

Load **git-workflow skill** for branch/commit/push/MR/pipeline/thread ops.
Autonomous — never pause to ask user once started.

## Prefix Legend

| Prefix | Meaning |
|--------|---------|
| `DO:` | Execute action |
| `IF:` | Conditional (→ action) |
| `LOOP:` | Iterate collection |
| `CALL:` | Invoke skill(params) → outputs |
| `EMIT:` | Output to user/file |
| `STORE:` | Save value |
| `STOP:` | Halt with reason |

---

## Phase 1 — Pre-flight

- DO: read `task-NNN.md`, sibling `plan.md`, all `task-*.md`, `jira.json`
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
- IF: Figma URL → CALL: figma-cache(nodeId, plan-folder) → read md + view_image

## Phase 3 — Implementation

- LOOP: each task in dependency order
  - DO: write production code — match conventions (naming, imports, error handling, auth, logging)
  - IF: UI task → verify layout/spacing/colour vs Figma before marking
  - DO: mark `[x]` in `task-NNN.md`
  - DO: write/update test — mirror adjacent test structure; happy path min; reuse test utilities
  - DO: run tests; fix all failures before next
  - DO: mark test `[x]`
- IF: file not listed in `task-NNN.md` → STOP: do not create/modify

## Phase 4 — Verification

- DO: run full test suite for affected modules; fix regressions
- LOOP: each Done When item
  - IF: satisfied → mark `[x]` + `<!-- verified YYYY-MM-DD -->`
  - IF: blocked → mark `[ ]` + `<!-- blocked: <reason> -->`
- DO: re-scan siblings for stale cross-references

## Phase 5 — Git Workflow

- CALL: BRANCH_SETUP(REPO_DIR, `GOBIZWKST2-{TICKET}-{kebab-task-title}`) → TICKET_NUM, BRANCH, DEFAULT_BRANCH
- CALL: COMMIT(REPO_DIR, `feat({repo}): {title} [GOBIZWKST2-{TICKET_NUM}]\n\nImplemented:\n- {files}`) → COMMITTED
- CALL: PUSH(REPO_DIR, BRANCH)
- CALL: ENSURE_MR(ENCODED, BRANCH, DEFAULT_BRANCH, `[GOBIZWKST2-{TICKET_NUM}] {title}`, body) → MR_IID, MR_URL
- CALL: POLL_PIPELINE(ENCODED, MR_IID, COMMITTED)
  - ON_SUCCESS: CALL: FETCH_OPEN_THREADS → evaluate (FIX/REJECT) → apply → COMMIT → PUSH → POST_THREAD_REPLIES → RESOLVE_THREADS
  - ON_FAILURE: inspect CI logs → fix → COMMIT → PUSH → reset POLL=0 → continue

## Phase 6 — Completion

- EMIT: jira-prompt (A: update sub-task SP | B: further changes | C: skip)
  - IF: A → CALL: jira-ticket skill; count checkboxes as SP; update if differs
- EMIT: summary

```
✅ Task NNN complete.
Implemented: <paths>
Tests:       <test paths>
Done When:   ✅ / ⚠️
Siblings:    task-NNN — <changes>
MR:          <MR_URL>
Pipeline:    <status>
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
- No secrets/stack traces in API responses
