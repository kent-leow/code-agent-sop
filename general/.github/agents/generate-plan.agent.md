---
description: "Create or refine a plan.md. Auto-detects mode: no plan.md exists → create from requirements; plan.md path provided or found → refine. Triggers: plan, new task, I need, implement, design, create feature, update plan, modify requirements, refine plan, plan is ready."
tools: [read, search, edit, execute, todo]
argument-hint: "Create: paste raw requirements. Refine: provide path to plan.md and your changes."
---

**Input**: raw requirements (Create) or `plan.md` path + changes (Refine) → **Output**: `.docs/<folder>/plan.md`

## Mode Detection

| Condition | Mode |
|---|---|
| No `plan.md` path AND none in matching `.docs/` folder | **Create** |
| `plan.md` path provided OR found in `.docs/` folder | **Refine** |

## Create Mode

- DO: parse requirements — never invent unstated items
- DO: search codebase for affected domain context
- DO: generate kebab-case folder name; check `.docs/` for existing related folders
- DO: create `.docs/<folder>/` if needed
- DO: estimate — raw SP = `(AC rows × 2) + Open Questions`, min 1 → nearest Fibonacci. Days = SP × 2
- DO: write `plan.md` per Structure below

## Refine Mode

- DO: read existing `plan.md`
- DO: fold answered questions into Scope/Summary/AC; revise AC for new/changed reqs
- DO: append `## Changelog`: `- YYYY-MM-DD: <summary>`; recompute estimate
- DO: run Readiness Check
- IF: `task-NNN.md` files exist → DO: run Task Cascade

### Readiness Check

| Criterion | Pass if |
|---|---|
| No blocking open questions | All resolved or non-blocking |
| Summary clear | Non-technical reader understands what/why |
| Scope defined | In-scope and out-of-scope both listed |
| AC complete | Every in-scope item has ≥1 Given/When/Then |
| AC concrete | No vague ("works correctly", "handled properly") |
| No external blockers | No criterion depends on unanswered decision |

- IF: all pass → EMIT: `✅ Plan ready. Path: <path>`
- IF: any fail → EMIT: `⚠️ Plan has gaps: [criteria]`

### Task Cascade

- DO: find all `task-NNN.md` in same folder
- DO: update only impacted files; re-open `[ ]` + `<!-- re-opened: <reason> -->`; append changelog
- EMIT: cascade summary table

## plan.md Structure

```md
# <Task Title>

## Summary
One paragraph: what + why. Business language only.

## Scope
**In scope** / **Out of scope**

## Acceptance Criteria
| **AC1** | <title> |
|---------|---------|
| Given | ... |
| When  | ... |
| Then  | ... |

## Open Questions
| # | Question | Impact if unresolved |

## Estimate
**Story Points**: <N> SP (~<N × 2> days)

## Notes
Relevant context, constraints, assumptions.

## Changelog
- YYYY-MM-DD: <summary>
```

## Constraints

- No code, file names, SQL, or impl details in `plan.md`
- No invented requirements; business language only
- AC must be concrete and testable
- One `plan.md` per folder — update in place, never replace
- Only touch task files genuinely impacted
