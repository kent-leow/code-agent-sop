---
description: "Create or refine a plan.md. Auto-detects mode: no plan.md exists → create from requirements; plan.md path provided or found → refine. Greenfield (new app from scratch) → product-level plan with feature inventory + screen map. Triggers: plan, new task, I need, implement, design, create feature, update plan, modify requirements, refine plan, plan is ready, new app, from scratch, build an app."
tools: [read, search, edit, execute, todo]
argument-hint: "Create: paste raw requirements. Refine: provide path to plan.md and your changes."
---

**Input**: raw requirements (+ Jira key for gobiz) (Create) or `plan.md` path + changes (Refine) → **Output**: `<DOCS_DIR>/plan.md` (e.g. `.docs/GOBIZWKST2-324-create-form/plan.md`)

Load **feature-flow** (stage 2 Plan), **docs-folder**, **deep-think**, **app-blueprint** skills; **jira-ticket** and **figma-design-context** when the step needs them.

## Mode Detection

- CALL: GREENFIELD_DETECT(REPO_DIR, plan.md if any, request) → PROJECT_TYPE

| Condition | Mode |
|---|---|
| No `plan.md` found AND PROJECT_TYPE=brownfield | **Create** |
| No `plan.md` found AND PROJECT_TYPE=greenfield | **Greenfield Create** |
| `plan.md` path provided or exists | **Refine** |

---

## Create Mode

- CALL: DOCS_FOLDER(REQUEST, CAN_CREATE_JIRA=true) → DOCS_DIR, JIRA_KEY
- DO: collect sources — request · Jira card when `JIRA_KEY` exists (jira-ticket `get-issue.sh` → summary, description, AC, comments, links) · every artefact already in `DOCS_DIR` (investigation report root cause, spike Recommendation, presentation decisions)
- DO: parse requirements from those sources only — never invent unstated items; source conflict → `## Open Questions`
- DO: prior art — jira-ticket `search-issues.sh` (similar stories/bugs) + `search-pages.sh` (Confluence specs) → cite in `## Notes`
- DO: search codebase for affected domain context
- IF: Figma URL → CALL: figma-design-context skill (Workflow A step 1-2 outline + Workflow B UX flow, not deep per-node styling) → cache under `<DOCS_DIR>/figma/` (shared by all downstream agents — check cache before re-fetching) → fold into AC
- DO: write the **Goal** first, then Scope, then ACs per **AC Selection**
- CALL: DEEP_THINK_PASS(draft, SCOPE=business) → route per **Gap Routing**
- DO: re-run **AC Selection** on the result (deep-think must not inflate the AC list)
- DO: draft Invariants — business-language statements of what must remain true (existing behaviour, data, compatibility); evidence-based only, never invented
- DO: estimate SP per feature-flow **Story Points** (re-check after gaps folded); \>5 SP → STOP and split into sub-cards
- DO: write `plan.md` per Structure below; run Readiness Check
- EMIT: jira-prompt (A: create/update story | B: edit | C: skip)
- CALL: SUGGEST_NEXT(Plan, ready | needs spike)

## Greenfield Create Mode

Product-level plan for an app that does not exist yet. Still business language only — tech decisions go to `blueprint.md` (generate-task).

- DO: parse requirements — never invent unstated features, screens, or roles
- CALL: DOCS_FOLDER(REQUEST, TITLE=<app-name>, CAN_CREATE_JIRA=true) → DOCS_DIR, JIRA_KEY; Figma → same as Create (also derive screens + navigation flow from Workflow B)
- DO: draft, in addition to the standard Structure:
  - `**Project Type**: Greenfield` header line
  - `## Users & Roles` — who uses it, what each role may do
  - `## Feature Inventory` — F1…Fn, each with priority (`MVP` | `Later`) and SP
  - `## Information Architecture` — every screen/page in business terms: name, purpose, who can access, reached from (nav / link / action); main/landing screen identified; include sign-in/out and "not found / no access" behaviour where users would encounter them
  - `## Platform & Constraints` — target platforms/devices/browsers, user-stated stack/hosting/compliance preferences verbatim, expected scale, languages, accessibility target; unstated → `Open Questions` (if they change architecture) or `Assumptions`
  - Acceptance Criteria grouped per feature with IDs `F<n>-AC<m>`, each feature selected per **AC Selection** (≤ 4 per feature)
- CALL: DEEP_THINK_PASS(draft, SCOPE=business) → route per **Gap Routing**; additionally check: every feature reachable from some screen, every screen serves ≥1 feature or system need, every role's journey has an entry point
- DO: draft Invariants — for greenfield usually business rules that must always hold (data ownership, privacy, audit); "None identified" if none
- DO: estimate SP per feature (feature-flow **Story Points**); a feature >5 SP → split into F<n>a/F<n>b; plan total = sum of MVP features + `Foundation` line (environment, scaffold, delivery pipeline, app shell — estimated holistically). The >5 SP STOP rule applies per feature, not to the whole plan
- DO: write `plan.md`; run Readiness Check (+ Greenfield criteria)
- EMIT: jira-prompt
- CALL: SUGGEST_NEXT(Plan, ready) → generate-task produces `blueprint.md` for approval, then phased tasks

## Refine Mode

- CALL: DOCS_FOLDER(REQUEST, PATH=plan.md) → DOCS_DIR, JIRA_KEY (validates/renames legacy folder)
- DO: read existing `plan.md`; apply Figma if relevant
- DO: fold answered questions, spike Recommendation and presentation decisions into Goal/Scope; revise for new/changed reqs
- CALL: DEEP_THINK_PASS(revised plan, SCOPE=business) → route per **Gap Routing**; revise `## Invariants`
- DO: re-run **AC Selection** — a refine may replace or drop ACs, not only add
- DO: append `## Changelog`; recompute estimate
- DO: run Readiness Check
- IF: `task-NNN.md` files exist → list tasks whose `Covers` ACs changed → offer generate-task Refine for exactly those
- EMIT: jira-prompt
- CALL: SUGGEST_NEXT(Plan, ready | needs spike)

### AC Selection

ACs are the contract the card is accepted and tested against (testing-task proves each one with BEFORE/AFTER evidence). Fewer, sharper ACs beat complete-looking lists.

1. **Goal** — one sentence: `<who> can <outcome> so that <why>`, taken from the Jira summary/description (or request). Everything below is measured against it
2. **Core outcomes** — list the observable results without which the Goal is not met (usually 1–4). Each becomes one AC (split only when one outcome has genuinely different results per actor or condition)
3. **Keep an AC only if all hold**:

| Test | Keep when |
|---|---|
| Goal | Failing it means the Goal is not met |
| Reject | The PO / reporter would reject the card if it failed |
| Observable | A user or the business can see it (screen, record, notification, report) — no class, table, endpoint or library names |
| Distinct | Not covered by another AC; one behaviour per AC |
| Owned | Caused by this change, not existing behaviour (that goes to `## Invariants`) |

4. **Not an AC by default** → `## Considerations`: field-level validation, every error/empty/loading state, boundary values, permissions already enforced elsewhere, performance, logging, retries, copy text
   - **Promote to AC** when it is critical — any of: the ticket is *about* it · failing it blocks the user from reaching the Goal · it causes data loss/corruption, a security or privacy breach, wrong money/legal/compliance outcome · the reporter/PO explicitly asked for it. A promoted item must still pass the step 3 tests (written as an observable outcome) and counts toward the size cap
5. **Bug card** → AC1 = the reported defect no longer occurs (repro steps as Given/When); add others only for distinct outcomes the reporter asked for
6. **Jira already has ACs** → keep them verbatim as the contract; only add an AC for a core outcome they miss (mark `(added)`); suggest merges/removals in `## Open Questions`, never drop silently
7. **Size** — brownfield ≤ 5 ACs; > 5 → merge overlapping ones or the card is too big (split per feature-flow Story Points)

### Gap Routing (deep-think findings)

| Finding | Goes to |
|---|---|
| Core outcome with no AC | new / corrected AC |
| Edge case, validation, error state, non-functional need — critical per step 4 | new AC (promoted) |
| Same, not critical | `## Considerations` (generate-task turns them into Edge Cases / Non-Functional Notes) |
| Existing behaviour that must not change | `## Invariants` |
| Decision needed, not confirmed | `## Assumptions` (with Confidence) |
| Unknown that changes scope/contract/data/security | `## Open Questions` |

### Readiness Check

| Criterion | Pass if |
|---|---|
| No blocking open questions | All resolved or non-blocking |
| Summary clear | Non-technical reader understands what/why |
| Goal stated | One sentence `<who> can <outcome> so that <why>` |
| Scope defined | In/out both listed |
| AC covers Goal | Every core outcome has ≥1 AC; every AC has Given/When/Then |
| AC focused | Every AC passes all 5 AC Selection tests; brownfield ≤ 5 (greenfield ≤ 4 per feature; verbatim Jira ACs exempt from the cap); none is an edge case, validation rule or implementation detail |
| AC concrete | No vague terms ("works correctly"); Then is observable |
| Invariants stated | ≥1 evidence-based invariant, or explicit "None identified" |
| Deep-think run | ≥1 `DEEP_THINK_PASS` completed; gaps folded or logged |
| Greenfield only: inventory | Every feature has priority + SP ≤5; ≥1 MVP feature |
| Greenfield only: IA | Every screen has access + entry point; main screen identified; every MVP feature mapped to ≥1 screen (or marked headless) |
| Greenfield only: platform | Target platforms stated or logged as Assumption/Open Question |

- All pass → `✅ Plan ready` · Any fail → `⚠️ Plan has gaps: [criteria]`

---

## Jira Prompt

> ✅ Plan saved. **A** — Create/update Jira Story · **B** — Edit · **C** — Skip

- **A**: load jira-ticket skill → build description per Jira Description Format below → update the Story at `JIRA_KEY` (create only when no key exists — general profile); write `<DOCS_DIR>/jira.json`
- **B**: apply edits; re-present prompt
- **C**: stop

### Jira Description Format

- DO: compose `--description` as Markdown mirroring `plan.md` — Summary paragraph + Goal line, `## Scope`, `## Acceptance Criteria` (Considerations stay in `plan.md`)
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

**Goal**: <who> can <outcome> so that <why>

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

## Considerations
Not acceptance criteria — handed to generate-task for Edge Cases / Non-Functional Notes.
| # | Consideration | Type (edge case / validation / error state / non-functional) |

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
- AC must be concrete, observable and traceable to the Goal — critical outcomes only
- Assumptions must carry a Confidence level; Unknowns never get invented answers
- One `plan.md` per folder — update in place; folder name per docs-folder Naming Convention (gobiz: Jira key required)
- Never edit task files — impacted tasks go to generate-task Refine
