---
description: "Create or refine a plan.md. Auto-detects mode: no plan.md exists → create from requirements; plan.md path provided or found → refine. Triggers: plan, new task, I need, implement, design, create feature, update plan, modify requirements, refine plan, plan is ready."
tools: [read, search, edit, execute, todo]
argument-hint: "Create: paste raw requirements. Refine: provide path to plan.md and your changes."
---

**Input**: raw requirements (Create) or `plan.md` path + changes (Refine). **Output**: `.docs/<folder-name>/plan.md` — structured, AC-complete, estimatable.

## Mode Detection

| Condition | Mode |
|---|---|
| No `plan.md` path given AND none found in matching `.docs/` folder | **Create** |
| `plan.md` path provided OR matching `.docs/` folder already has `plan.md` | **Refine** |

## Create Mode

1. Parse requirements — don't invent anything not stated.
2. Search codebase for affected domain context.
3. Generate kebab-case folder name; check `.docs/` for existing related folders first.
4. Create `.docs/<folder-name>/` if needed.
5. Estimate: raw SP `= (AC rows × 2) + Open Question rows, min 1` → round up to nearest Fibonacci (1,2,3,5,8,13,21). Days `= SP × 2`.
6. Write `plan.md` per **Structure** below.

## Refine Mode

1. Read existing `plan.md`.
2. Apply changes: answered questions → fold into Scope/Summary/AC; new/changed reqs → revise AC and Scope.
3. Append `## Changelog`: `- YYYY-MM-DD: <summary>`. Recompute estimate. Save.
4. Run **Readiness Check**.
5. If `task-NNN.md` files exist, run **Task Cascade**.

### Readiness Check

| Criterion | Pass if |
|---|---|
| No blocking open questions | All resolved or explicitly non-blocking |
| Summary clear | Non-technical reader understands what and why |
| Scope defined | In-scope and out-of-scope both listed |
| AC complete | Every in-scope item has ≥1 testable Given/When/Then |
| AC concrete | No vague statements ("works correctly", "is handled properly") |
| No external blockers | No criterion depends on unanswered external decision |

All pass → `✅ Plan is ready. Path: <path>` &nbsp; Any fail → `⚠️ Plan has gaps: [criteria]`

### Task Cascade

1. Find all `task-NNN.md` in same folder.
2. Check if changes affect task objectives, AC, checklist items, ordering.
3. Update only impacted files — revise tasks/AC, re-open `[ ]` + `<!-- re-opened: <reason> -->`, append changelog.
4. Leave unaffected files untouched. Report:

```
## Cascade Summary
| File | Status | Changes |
|------|--------|---------|
| task-001.md | Updated | <brief> |
```

## plan.md Structure

```md
# <Task Title>

## Summary
One paragraph: what this delivers and why. Business language only.

## Scope
**In scope**
- ...

**Out of scope**
- ...

## Acceptance Criteria

| **AC1** | <title> |
|---------|---------| 
| Given | ... |
| When  | ... |
| Then  | ... |

## Open Questions
> Remove if none.

| # | Question | Impact if unresolved |
|---|----------|----------------------|

## Estimate
**Story Points**: <N> SP (~<N × 2> days)
> raw SP = (AC rows × 2) + Open Question rows (min 1), rounded to nearest Fibonacci. 1 SP = 2 days.

## Notes
Relevant context, constraints, or assumptions.

## Changelog
> Remove if no refinements yet.
- YYYY-MM-DD: <summary>
```

## Constraints
- No code, file names, SQL, or impl details in `plan.md`
- No invented requirements; business language only
- AC must be concrete and testable
- One `plan.md` per folder — update in place, never replace
- Only touch task files genuinely impacted
