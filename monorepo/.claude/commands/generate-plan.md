---
description: "Create or refine a plan.md. Auto-detects mode: no plan.md exists → create from requirements; plan.md path provided or found → refine. Triggers: plan, new task, I need, implement, design, create feature, update plan, modify requirements, refine plan, plan is ready."
tools: [read, search, edit, execute, todo]
argument-hint: "Create: paste raw requirements. Refine: provide path to plan.md and your changes."
---

**Input**: raw requirements (Create) or `plan.md` path + changes (Refine) → **Output**: `.docs/<folder>/plan.md`

## Mode Detection

| Condition | Mode |
|---|---|
| No `plan.md` found | **Create** |
| `plan.md` path provided or exists | **Refine** |

---

## Create Mode

- DO: parse requirements — never invent unstated items
- DO: search codebase for affected domain context
- DO: create `.docs/<kebab-folder>/` if needed
- IF: Figma URL → CALL: figma-design-context skill (Workflow A step 1-2 outline + Workflow B UX flow, not deep per-node styling) → cache under `.docs/<kebab-folder>/figma/` (becomes `<plan-folder>/figma/` for all downstream agents — check cache before re-fetching) → fold into AC
- DO: estimate SP (holistic — layers touched × regression risk × uncertainty):

| SP | Category | Signal |
|---|---|---|
| 0.5 | Tiny | One file/config; no logic; near-zero risk |
| 1 | Small | Existing path; basic correctness |
| 2 | Bounded | New capability in one layer |
| 3 | Moderate | Multi-layer; one sprint; regression checks |
| 5 | Significant | Cross-layer; auth/security; workflow change |

> \>5 SP → STOP and split into sub-cards

- DO: write `plan.md` per Structure below
- EMIT: jira-prompt (A: create/update story | B: edit | C: skip)

## Refine Mode

- DO: read existing `plan.md`; apply Figma if relevant
- DO: fold answered questions into AC; revise for new/changed reqs
- DO: append `## Changelog`; recompute estimate
- DO: run Readiness Check
- IF: `task-NNN.md` files exist → run Task Cascade (update impacted files only)
- EMIT: jira-prompt

### Readiness Check

| Criterion | Pass if |
|---|---|
| No blocking open questions | All resolved or non-blocking |
| Summary clear | Non-technical reader understands what/why |
| Scope defined | In/out both listed |
| AC complete | Every in-scope item has ≥1 Given/When/Then |
| AC concrete | No vague terms ("works correctly") |

- All pass → `✅ Plan ready` · Any fail → `⚠️ Plan has gaps: [criteria]`

---

## Jira Prompt

> ✅ Plan saved. **A** — Create/update Jira Story · **B** — Edit · **C** — Skip

- **A**: load jira-ticket skill → create/update Story from Summary+Scope+AC; write `jira.json`
- **B**: apply edits; re-present prompt
- **C**: stop

---

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
**Story Points**: <N> SP — <Category> (<rationale>)

## Notes
Context, constraints, assumptions.

## Changelog
- YYYY-MM-DD: <summary>
```

## Constraints

- No code, file names, SQL, or impl details in `plan.md`
- No invented requirements; business language only
- AC must be concrete and testable
- One `plan.md` per folder — update in place
- Only touch task files genuinely impacted
