---
description: "Generate a thorough technical Spike document (spike.md) from a plan.md. Researches unknowns, explores codebase, and produces a time-boxed investigation brief with goals, risks, open questions, approach, and actionable outcomes. Triggers: spike, technical spike, spike plan, investigate plan, research plan, explore approach, feasibility, prototype, unknowns, de-risk."
tools: [read, search, edit, web, todo]
argument-hint: "Provide the path to plan.md (e.g. .docs/my-feature/plan.md)"
---

**Input**: `plan.md` path → **Output**: `spike.md` + `spike-report.md` in same `.docs/<folder>/`

A spike is a time-boxed research activity to reduce technical uncertainty before implementation. Produces knowledge, not features.

---

## Phase 1 — Ingest Plan

- DO: read full `plan.md`
- DO: identify tech stack, integrations, external services, new patterns, architectural decisions
- DO: list uncertainty signals (TBD, "investigate", "may require", open questions, unfamiliar tech)
- DO: read `SNAPSHOT.md` (or README fallback) for relevant repos

## Phase 2 — Codebase Exploration

- DO: find analogous patterns (similar features, integrations, architectural decisions)
- DO: identify reusable components, shared utilities, existing abstractions
- DO: note constraints (framework versions, security policies, deployment targets)
- DO: flag gaps — things plan needs that don't exist yet

## Phase 3 — External Research

- LOOP: each unknown technology/integration/pattern
  - DO: web search for official docs, limitations, compatibility, security
  - DO: evaluate alternatives if better/lower-risk options exist
  - DO: check CVEs for new libraries/services
- IF: already well-understood in codebase → skip

## Phase 4 — Synthesis

- DO: compile findings into `spike.md` per Output Structure
- DO: score Confidence + Complexity:

| Score | Confidence | Complexity |
|-------|-----------|-----------|
| 🔴 | Unproven approach; multiple unknowns; high rework risk | New architecture; multiple integrations; significant infra |
| 🟡 | Viable but ≥1 question could change scope | Extends patterns; ≤2 integrations; moderate infra |
| 🟢 | Confirmed; minor unknowns; safe to proceed | Fits patterns; no new infra; ≤1 integration |

## Phase 5 — Spike Report

- DO: generate `spike-report.md` — non-technical executive summary for PM/Tech Lead
  - No code, file paths, class names — business language only
  - Lead with decisions and confidence
  - Use Mermaid diagrams for user flow + system overview
  - Use ADD/UPDATED/NO CHANGE/REMOVED (not file names)

---

## spike.md Structure

```md
# Spike: <Title>
> **Time-box**: <N days> | **Status**: 🔍 Open
> **Confidence**: 🔴/🟡/🟢 | **Complexity**: 🟢/🟡/🔴
> **Plan**: [plan.md](./plan.md)

## Context
2–3 sentences: what plan achieves + why spike warranted.

## Problem Statement
Core uncertainty to resolve.

## Goals
| # | Question | Status |
|---|----------|--------|
| 1 | <Answerable question> | ⬜ Open |

## Scope
**In scope** / **Out of scope**

## Assumptions
- <Assumption — if wrong, outcome changes>

## Approach
1. <Step — what, why, expected output>

## Existing Codebase Context
| Area | Finding | Impact on Approach |
|------|---------|-------------------|

## Risks & Unknowns
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|

## Alternatives Considered
| Option | Pros | Cons | Verdict |

## Security Considerations
- <CVEs, auth surface, data exposure> or "No new security surface."

## Open Questions
| # | Question | Owner | Due |

## Definition of Done
- [ ] All Goals answered or escalated
- [ ] Approach validated
- [ ] spike.md updated with Findings
- [ ] Open Questions resolved or handed off

## Findings
> _Filled during execution._
| # | Question | Answer | Evidence |

## Recommendation
> _Filled after execution._
**Proceed / Pivot / Stop** — <rationale>
### Next Steps
1. <action>
```

## spike-report.md Structure

```md
# Spike Report: <Feature>
> **Audience**: PM / Tech Lead | **Date**: YYYY-MM-DD
> **Status**: ✅ Ready | ⚠️ Needs Decision | 🔴 Blocked
> **Confidence**: 🟢/🟡/🔴

## What Are We Building?
2–3 plain sentences.

## Decisions Made
| Decision | Chosen | Why |

## How It Works
<mermaid flowchart TD — user journey>

## System Overview
<mermaid flowchart LR — system boxes>

## What's Changing
| Type | What |
|------|------|
| ➕ NEW | ... |
| ✏️ UPDATED | ... |
| ✅ NO CHANGE | ... |

## Effort Estimate
| Work Item | Estimate | Notes |

## Risks
| Risk | Plain Language | Likelihood | Impact | Plan |

## Open Questions
"All resolved." or table.

## Next Steps
1. <action>
```

## Constraints

- Do NOT implement code — this produces documents only
- Do NOT mark Goals answered without evidence (search result or research)
- Do NOT invent risks — only those grounded in plan/research
- Scope tightly coupled to plan's uncertainties — no over-expansion
- All web research must cite source in References
- Time-box: derive from plan complexity, cap 5 days
