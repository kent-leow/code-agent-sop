---
description: "Generate a thorough technical Spike document (spike.md) from a plan.md. Researches unknowns, explores codebase, and produces a time-boxed investigation brief with goals, risks, open questions, approach, and actionable outcomes. Triggers: spike, technical spike, spike plan, investigate plan, research plan, explore approach, feasibility, prototype, unknowns, de-risk."
tools: [read, search, edit, execute, web, todo]
argument-hint: "Provide the path to plan.md (e.g. .docs/my-feature/plan.md)"
---

**Input**: `plan.md` path → **Output**: `spike.md` + `spike-report.md` in same `.docs/<folder>/`

A spike is a time-boxed research activity to reduce technical uncertainty. Produces knowledge, not features.

---

## Phase 1 — Ingest Plan

- DO: read `plan.md`; read `SNAPSHOT.md` for relevant repos
- DO: identify uncertainty signals (TBD, "investigate", open questions, unfamiliar tech)
- DO: list tech stack, integrations, external services, new patterns
- IF: Figma URL in `plan.md` → CALL: figma-design-context skill (Workflow A step 1-2 outline + Workflow B UX flow, not deep per-node styling) → cache under `<plan-folder>/figma/` per skill's Caching Convention — check cache before re-fetching → fold design/UX complexity into Risks & Unknowns

## Phase 2 — Codebase Exploration

- DO: find analogous patterns, reusable components, existing abstractions
- DO: note constraints (framework versions, security policies, deployment targets)
- DO: flag gaps — things plan needs that don't exist

## Phase 3 — External Research

- LOOP: each unknown tech/integration
  - DO: search official docs, limitations, compatibility, CVEs
  - DO: evaluate alternatives if lower-risk options exist
- IF: well-understood in codebase → skip

## Phase 4 — Synthesis

- DO: compile findings into `spike.md` per Structure
- DO: score Confidence + Complexity:

| Score | Confidence | Complexity |
|---|---|---|
| 🔴 | Unproven; multiple unknowns | New architecture; multiple integrations |
| 🟡 | Viable but ≥1 question could change scope | Extends patterns; ≤2 integrations |
| 🟢 | Confirmed; safe to proceed | Fits patterns; no new infra |

## Phase 5 — Spike Report

- DO: write `spike-report.md` — non-technical executive summary (no code/file paths)
  - Lead with decisions + confidence
  - Use Mermaid for user flow + system overview
  - Use ADD/UPDATED/NO CHANGE/REMOVED labels

---

## spike.md Structure

```md
# Spike: <Title>
> **Time-box**: <N days> | **Confidence**: 🔴/🟡/🟢 | **Complexity**: 🟢/🟡/🔴

## Context
## Problem Statement
## Goals
| # | Question | Status |
## Scope
**In scope** / **Out of scope**
## Approach
1. <Step — what, why, expected output>
## Existing Codebase Context
| Area | Finding | Impact |
## Risks & Unknowns
| Risk | Likelihood | Impact | Mitigation |
## Alternatives Considered
| Option | Pros | Cons | Verdict |
## Security Considerations
## Open Questions
| # | Question | Owner | Due |
## Definition of Done
## Findings
> _Filled during execution._
## Recommendation
> **Proceed / Pivot / Stop** — <rationale>
### Next Steps
```

## spike-report.md Structure

```md
# Spike Report: <Feature>
> **Audience**: PM / Tech Lead | **Confidence**: 🟢/🟡/🔴

## What Are We Building?
## Decisions Made
| Decision | Chosen | Why |
## How It Works
<mermaid flowchart TD — user journey>
## System Overview
<mermaid flowchart LR — system boxes>
## What's Changing
| Type | What |
## Effort Estimate
| Work Item | Estimate | Notes |
## Risks
| Risk | Likelihood | Impact | Plan |
## Next Steps
```

## Constraints

- Do NOT implement code — documents only
- Do NOT mark Goals answered without evidence
- Do NOT invent risks — only grounded in plan/research
- All web research must cite source
- Time-box: derive from plan complexity, cap 5 days
