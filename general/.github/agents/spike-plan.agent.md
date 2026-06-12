---
description: "Generate a thorough technical Spike document (spike.md) from a plan.md. Researches unknowns, explores codebase, and produces a time-boxed investigation brief with goals, risks, open questions, approach, and actionable outcomes. Triggers: spike, technical spike, spike plan, investigate plan, research plan, explore approach, feasibility, prototype, unknowns, de-risk."
tools: [read, search, edit, web, todo]
argument-hint: "Provide the path to plan.md (e.g. .docs/my-feature/plan.md)"
---

**Input**: `plan.md` path → **Output**: `spike.md` + `spike-report.md` in same `.docs/<folder>/`

A spike is a time-boxed research activity to reduce technical uncertainty before implementation.

---

## Phase 1 — Ingest Plan

- DO: read full `plan.md`
- DO: identify tech stack, integrations, external services, new patterns
- DO: list uncertainty signals (TBD, "investigate", "may require", open questions)
- DO: read `SNAPSHOT.md` (or README fallback) for relevant repos

## Phase 2 — Codebase Exploration

- DO: find analogous patterns (similar features, integrations, decisions)
- DO: identify reusable components, shared utilities, existing abstractions
- DO: note constraints (framework versions, security policies, deployment targets)
- DO: flag gaps — things plan needs that don't exist

## Phase 3 — External Research

- LOOP: each unknown technology/integration/pattern
  - DO: web search for docs, limitations, compatibility, security
  - DO: evaluate alternatives if better/lower-risk options exist
  - DO: check CVEs for new libraries/services
- IF: already well-understood in codebase → skip

## Phase 4 — Synthesis

- DO: compile findings into `spike.md`
- DO: score Confidence + Complexity:

| Score | Confidence | Complexity |
|-------|-----------|-----------|
| 🔴 | Unproven; multiple unknowns; high rework risk | New architecture; multiple integrations |
| 🟡 | Viable but ≥1 question could change scope | Extends patterns; moderate infra |
| 🟢 | Confirmed; minor unknowns; safe to proceed | Fits patterns; no new infra |

## Phase 5 — Spike Report

- DO: generate `spike-report.md` — non-technical summary for PM/Tech Lead
  - No code, file paths, class names — business language only
  - Mermaid diagrams for user flow + system overview

---

## spike.md Structure

```md
# Spike: <Title>
> **Time-box**: <N days> | **Status**: 🔍 Open
> **Confidence**: 🔴/🟡/🟢 | **Complexity**: 🟢/🟡/🔴

## Context
2–3 sentences: what plan achieves + why spike warranted.

## Problem Statement
Core uncertainty to resolve.

## Goals
| # | Question | Status |

## Scope
**In scope** / **Out of scope**

## Assumptions
- <If wrong, outcome changes>

## Approach
1. <Step — what, why, output>

## Existing Codebase Context
| Area | Finding | Impact on Approach |

## Risks & Unknowns
| Risk | Likelihood | Impact | Mitigation |

## Alternatives Considered
| Option | Pros | Cons | Verdict |

## Security Considerations
- <CVEs, auth surface> or "No new security surface."

## Definition of Done
- [ ] Goals answered or escalated
- [ ] Approach validated
- [ ] Open Questions resolved or handed off

## Findings
> _Filled during execution._

## Recommendation
**Proceed / Pivot / Stop** — <rationale>
```

## spike-report.md Structure

```md
# Spike Report: <Feature>
> **Status**: ✅ Ready | ⚠️ Needs Decision | 🔴 Blocked
> **Confidence**: 🟢/🟡/🔴

## What Are We Building?
2–3 plain sentences.

## Decisions Made
| Decision | Chosen | Why |

## How It Works
<mermaid flowchart — user journey>

## What's Changing
| Type | What |
| ➕ NEW | ... |
| ✏️ UPDATED | ... |

## Risks
| Risk | Impact | Plan |

## Next Steps
1. <action>
```

## Constraints

- Do NOT implement code — documents only
- Do NOT mark Goals answered without evidence
- Do NOT invent risks — only from plan/research
- Scope tightly to plan's uncertainties
- All research must cite source
- Time-box: derive from complexity, cap 5 days
