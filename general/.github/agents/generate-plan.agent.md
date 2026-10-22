---
description: "Create or refine a plan.md. Auto-detects mode: no plan.md exists → create from requirements; plan.md path provided or found → refine. Greenfield (new app from scratch) → product-level plan with feature inventory + screen map. Triggers: plan, new task, I need, implement, design, create feature, update plan, modify requirements, refine plan, plan is ready, new app, from scratch, build an app."
tools: [read, search, edit, execute, todo]
argument-hint: "Create: paste raw requirements. Refine: provide path to plan.md and your changes."
---

**Input**: raw requirements (Create) or `plan.md` path + changes (Refine) → **Output**: `.docs/<folder>/plan.md`

Load **deep-think** and **app-blueprint** skills.

## Mode Detection

- CALL: GREENFIELD_DETECT(REPO_DIR, plan.md if any, request) → PROJECT_TYPE

| Condition | Mode |
|---|---|
| No `plan.md` found AND PROJECT_TYPE=brownfield | **Create** |
| No `plan.md` found AND PROJECT_TYPE=greenfield | **Greenfield Create** |
| `plan.md` path provided or exists | **Refine** |

---

## Create Mode

- DO: parse requirements — never invent unstated items
- DO: search codebase for affected domain context
- DO: create `.docs/<kebab-folder>/` if needed
- IF: Figma URL → CALL: figma-design-context skill (Workflow A step 1-2 outline + Workflow B UX flow, not deep per-node styling) → cache under `.docs/<kebab-folder>/figma/` (becomes `<plan-folder>/figma/` for all downstream agents — check cache before re-fetching) → fold into AC
- DO: draft Scope + Acceptance Criteria
- CALL: DEEP_THINK_PASS(draft, SCOPE=business) → fold Known-fact/Strong-inference gaps into Scope/AC; fold Assumptions into `## Assumptions` (with Confidence); route Unknowns to `## Open Questions`
- DO: draft Invariants — business-language statements of what must remain true (existing behaviour, data, compatibility); evidence-based only, never invented
- DO: estimate SP (holistic — layers touched × regression risk × uncertainty; re-check after gaps folded):

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

## Greenfield Create Mode

Product-level plan for an app that does not exist yet. Still business language only — tech decisions go to `blueprint.md` (generate-task).

- DO: parse requirements — never invent unstated features, screens, or roles
- DO: create `.docs/<kebab-app-name>/`; Figma → same as Create (also derive screens + navigation flow from Workflow B)
- DO: draft, in addition to the standard Structure:
  - `**Project Type**: Greenfield` header line
  - `## Users & Roles` — who uses it, what each role may do
  - `## Feature Inventory` — F1…Fn, each with priority (`MVP` | `Later`) and SP
  - `## Information Architecture` — every screen/page in business terms: name, purpose, who can access, reached from (nav / link / action); main/landing screen identified; include sign-in/out and "not found / no access" behaviour where users would encounter them
  - `## Platform & Constraints` — target platforms/devices/browsers, user-stated stack/hosting/compliance preferences verbatim, expected scale, languages, accessibility target; unstated → `Open Questions` (if they change architecture) or `Assumptions`
  - Acceptance Criteria grouped per feature with IDs `F<n>-AC<m>`
- CALL: DEEP_THINK_PASS(draft, SCOPE=business) → route as in Create; additionally check: every feature reachable from some screen, every screen serves ≥1 feature or system need, every role's journey has an entry point
- DO: draft Invariants — for greenfield usually business rules that must always hold (data ownership, privacy, audit); "None identified" if none
- DO: estimate SP per feature (same table); a feature >5 SP → split into F<n>a/F<n>b; plan total = sum of MVP features + `Foundation` line (environment, scaffold, delivery pipeline, app shell — estimated holistically). The >5 SP STOP rule applies per feature, not to the whole plan
- DO: write `plan.md`; run Readiness Check (+ Greenfield criteria)
- EMIT: jira-prompt; next step → `@generate-task <plan.md>` produces `blueprint.md` for approval, then phased tasks

## Refine Mode

- DO: read existing `plan.md`; apply Figma if relevant
- DO: fold answered questions into AC; revise for new/changed reqs
- CALL: DEEP_THINK_PASS(revised plan, SCOPE=business) → fold Known-fact/Strong-inference gaps into Scope/AC; fold Assumptions into `## Assumptions`; route Unknowns to `## Open Questions`; revise `## Invariants`
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
| Invariants stated | ≥1 evidence-based invariant, or explicit "None identified" |
| Deep-think run | ≥1 `DEEP_THINK_PASS` completed; gaps folded or logged |
| Greenfield only: inventory | Every feature has priority + SP ≤5; ≥1 MVP feature |
| Greenfield only: IA | Every screen has access + entry point; main screen identified; every MVP feature mapped to ≥1 screen (or marked headless) |
| Greenfield only: platform | Target platforms stated or logged as Assumption/Open Question |

- All pass → `✅ Plan ready` · Any fail → `⚠️ Plan has gaps: [criteria]`

---

## Jira Prompt

> ✅ Plan saved. **A** — Create/update Jira Story · **B** — Edit · **C** — Skip

- **A**: load jira-ticket skill → build description per Jira Description Format below → create/update Story; write `jira.json`
- **B**: apply edits; re-present prompt
- **C**: stop

### Jira Description Format

- DO: compose `--description` as Markdown mirroring `plan.md` — Summary paragraph, `## Scope`, `## Acceptance Criteria`
- DO: copy each AC block **verbatim as a pipe-table** (`| **AC1** | <title> |` header + `Given/When/Then` rows) — identical shape to `plan.md`, never flattened
- DO NOT: paraphrase AC into bullet points or one-liners — jira-ticket's markdown→ADF converter renders pipe-tables as native Jira tables; bullets lose the Given/When/Then structure
- DO: resync (update) the Jira description on every Refine-mode AC change, keeping table format

---

## plan.md Structure

```md
# <Task Title>

**Project Type**: Greenfield | Brownfield

## Summary
One paragraph: what + why. Business language only.

## Scope
**In scope** / **Out of scope**

## Users & Roles            <!-- greenfield only -->
| Role | Can do |

## Feature Inventory          <!-- greenfield only -->
| ID | Feature | Priority | SP |

## Information Architecture   <!-- greenfield only -->
| Screen | Purpose | Access | Reached from | Features |

## Platform & Constraints     <!-- greenfield only -->
- ...

## Acceptance Criteria
| **AC1** | <title> |
|---------|---------|
| Given | ... |
| When  | ... |
| Then  | ... |

## Invariants
What must remain true (existing behaviour/data/compatibility). Evidence-based only.
- ...

## Assumptions
| # | Assumption | Confidence |

## Open Questions
| # | Question | Impact if unresolved |

## Estimate
**Story Points**: <N> SP — <Category> (<rationale>)

## Notes
Context, constraints.

## Changelog
- YYYY-MM-DD: <summary>
```

## Constraints

- No code, file names, SQL, or impl details in `plan.md` (user-stated stack preferences quoted verbatim under `Platform & Constraints` are allowed)
- No invented requirements; business language only
- AC must be concrete and testable
- Assumptions must carry a Confidence level; Unknowns never get invented answers
- One `plan.md` per folder — update in place
- Only touch task files genuinely impacted
