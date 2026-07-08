---
description: "Create or refine a plan.md. Auto-detects mode: no plan.md exists → create from requirements; plan.md path provided or found → refine. Triggers: plan, new task, I need, implement, design, create feature, update plan, modify requirements, refine plan, plan is ready."
tools: [read, search, edit, execute, todo, com.figma.mcp/mcp/*]
argument-hint: "Create: paste raw requirements. Refine: provide path to plan.md and your changes."
---

**Input**: raw requirements (Create) or `plan.md` path + changes (Refine) → **Output**: `.docs/<folder>/plan.md`

## Mode Detection

| Condition | Mode |
|---|---|
| No `plan.md` path AND none in matching `.docs/` folder | **Create** |
| `plan.md` path provided OR found in `.docs/` folder | **Refine** |

## Figma

- IF: Figma URL provided:
  - DO: create `figma/` folder under same folder as `plan.md` (e.g., `.docs/<folder>/figma/`)
  - DO: store all Figma cache/context files in `figma/` folder:
    - `figma/context.json` — design spec
    - `figma/screenshot.png` — visual reference
    - `figma/summary.md` — parsed summary
    - `figma/flow.json` — UI flow (if applicable)
  - CALL: figma-design-context skill → outputs to `figma/`
  - DO: fold extracted context into AC/Scope/Notes; mark `(from Figma)`
- IF: no Figma URL but UI-related → EMIT: add to Open Questions: `Figma design URL needed`

## Create Mode

- DO: parse requirements — never invent unstated items
- DO: search codebase for affected domain context
- DO: generate kebab-case folder name; check `.docs/` for existing related folders
- DO: create `.docs/<folder>/` if needed
- DO: estimate — assign SP by matching overall feature complexity to the scale below; if scope spans multiple categories, pick the highest applicable tier

| SP | Category | Signal |
|-----|---|---|
| 0.5 | Tiny / mechanical | One file/config; no logic; near-zero regression risk |
| 1 | Small refinement | Existing path; basic correctness + light testing |
| 2 | Bounded enhancement | New capability in one layer; clear scope; meaningful testing |
| 3 | Moderate feature | Multi-layer (FE + BE, BE + DB + integration); one sprint; regression checks |
| 5 | Significant feature | Cross-layer; auth/security; workflow change; high regression risk |

> If complexity exceeds 5 SP → STOP and split into sub-cards (BE / FE / integration / spike)
- DO: write `plan.md` per Structure below
- EMIT: jira-prompt (A: create/update story | B: edit | C: skip)

## Refine Mode

- DO: read existing `plan.md`; apply Figma if relevant
- DO: fold answered questions into Scope/Summary/AC; revise AC for new/changed reqs
- DO: append `## Changelog`: `- YYYY-MM-DD: <summary>`; recompute estimate
- DO: run Readiness Check
- IF: `task-NNN.md` files exist → DO: run Task Cascade
- EMIT: jira-prompt (A: update story | B: edit | C: skip)

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
- DO: check if changes affect objectives, AC, checklist, ordering
- DO: update only impacted files; re-open `[ ]` + `<!-- re-opened: <reason> -->`; append changelog
- EMIT: cascade summary table (File | Status | Changes)

## plan.md Structure

```md
# <Task Title>

## Summary
One paragraph: what + why. Business language only.

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
| # | Question | Impact if unresolved |
|---|----------|----------------------|

## Estimate
**Story Points**: <N> SP — <Category> (<one-line rationale>)

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
