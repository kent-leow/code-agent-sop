---
description: "Generate a thorough technical Spike document (spike.md) from a plan.md. Researches unknowns, explores codebase, and produces a time-boxed investigation brief with goals, risks, open questions, approach, and actionable outcomes. Triggers: spike, technical spike, spike plan, investigate plan, research plan, explore approach, feasibility, prototype, unknowns, de-risk."
tools: [read, search, edit, web, todo]
argument-hint: "Provide the path to plan.md (e.g. .docs/my-feature/plan.md)"
---

**Input**: `plan.md` path. **Output**: `spike.md` in the same `.docs/<folder>/` — a comprehensive, time-boxed technical investigation document ready for team review.

## What is a Technical Spike?

A **spike** is a time-boxed research activity used to reduce technical uncertainty before committing to an implementation plan. It is NOT a prototype to ship — it is structured thinking that answers "can we build this, how, and what are the risks?" Spikes produce knowledge, not features.

A good spike:
- Has **specific, answerable questions** — not vague exploration
- Is **time-boxed** — infinite research is not a spike
- Has a **clear Definition of Done** — you know when to stop
- Produces **decisions and recommendations**, not just findings
- Surfaces **risks and unknowns** so the team can plan around them

---

## Phase 1 — Ingest the Plan

1. Read the full `plan.md`.
2. Identify: tech stack, integrations, external services, new patterns, architectural decisions.
3. List all **uncertainty signals** — things the plan assumes without proof, words like "TBD", "investigate", "may require", "unclear", open questions, any AC that depends on external systems or unfamiliar tech.
4. Note the existing codebase stack — read `SNAPSHOT.md` (or `README.md` fallback) for each relevant repo touched by the plan.

---

## Phase 2 — Codebase Exploration

Scope exploration to areas the plan touches:

1. Find analogous patterns — search for similar features, integrations, or architectural decisions already in the codebase.
2. Identify reusable components, shared utilities, or existing abstractions the implementation could leverage.
3. Note constraints — framework versions, security policies, deployment targets, shared infra.
4. Flag gaps — things the plan needs that don't exist yet.

---

## Phase 3 — External Research

For each unknown technology, integration, or architectural pattern in the plan:

1. **Web search** for: official docs, known limitations, compatibility notes, security considerations, community consensus on approach.
2. **Evaluate alternatives** — if the plan proposes one approach, briefly note if a better-known or lower-risk alternative exists.
3. **Check CVEs / security posture** for any new libraries or external services mentioned.
4. Keep research focused — only fetch what the plan's uncertainties demand. Do not research things that are already well-understood in the codebase.

---

## Phase 4 — Spike Synthesis

Compile findings into a structured `spike.md`. Apply the **Output Structure** below exactly.

Scoring guidance for **Confidence Level**:
| Score | Meaning |
|-------|---------|
| 🔴 Low | Core approach is unproven; multiple unknowns; high risk of rework |
| 🟡 Medium | Approach is viable but ≥1 open question could change scope significantly |
| 🟢 High | Approach confirmed; minor unknowns only; safe to proceed |

Scoring guidance for **Complexity**:
| Score | Meaning |
|-------|---------|
| 🟢 Low | Fits existing patterns; no new infra; ≤1 integration |
| 🟡 Medium | Extends existing patterns; ≤2 integrations; moderate infra change |
| 🔴 High | New architecture; multiple integrations; significant infra or security surface |

---

## Output Structure

Write `spike.md` in the **same folder as `plan.md`** with this exact structure:

```markdown
# Spike: <Plan Title>

> **Time-box**: <N days — derive from plan estimate; default 2 days if not specified>
> **Status**: 🔍 Open
> **Confidence**: <🔴 Low | 🟡 Medium | 🟢 High>
> **Complexity**: <🟢 Low | 🟡 Medium | 🔴 High>
> **Plan**: [plan.md](./plan.md)

---

## Context

<2–3 sentences: what the plan is trying to achieve and why a spike is warranted. Business language — no jargon.>

## Problem Statement

<The single core uncertainty this spike must resolve. One sharp paragraph. If there are multiple, state the primary one here and list the rest under Goals.>

---

## Goals

Specific questions this spike must answer. Each goal is a binary question (yes/no or a concrete answer).

| # | Question | Status |
|---|----------|--------|
| 1 | <Specific answerable question> | ⬜ Open |
| 2 | <Specific answerable question> | ⬜ Open |
| … | | |

> Goals drive the spike. If a question cannot be answered within the time-box, it becomes a risk.

---

## Scope

**In scope**
- <What this spike will investigate>

**Out of scope**
- <What this spike will NOT investigate — be explicit>

---

## Assumptions

Things taken as true going into this spike. If any assumption is wrong, the spike outcome changes.

- <Assumption>
- <Assumption>

---

## Approach

How the investigation will be conducted. Ordered steps.

1. <Step — what to do, why, expected output>
2. <Step>
3. …

> If a proof-of-concept is needed: specify what it validates, where it lives, and that it is throwaway.

---

## Existing Codebase Context

| Area | Relevant Finding | Impact on Approach |
|------|------------------|--------------------|
| <File / module / pattern> | <What exists> | <How it constrains or enables the plan> |

---

## Risks & Unknowns

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| <Risk description> | 🔴/🟡/🟢 | 🔴/🟡/🟢 | <Mitigation or fallback> |

---

## Alternatives Considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| <Approach A (plan's approach)> | | | Preferred / Rejected |
| <Approach B> | | | Preferred / Rejected |

---

## Security Considerations

- <Any CVEs, auth surface changes, data exposure risks, OWASP concerns relevant to this plan>
- None identified → state explicitly: _No new security surface introduced._

---

## Open Questions

Questions that must be answered by a human (stakeholder, architect, external team) before or during the spike.

| # | Question | Owner | Due |
|---|----------|-------|-----|
| 1 | <Question> | <Role/name or TBD> | TBD |

---

## Definition of Done

The spike is complete when:

- [ ] All Goals answered (or explicitly escalated as risks)
- [ ] Approach validated (PoC run or sufficient evidence gathered)
- [ ] `spike.md` updated with Findings and Recommendation
- [ ] Open Questions resolved or handed off
- [ ] Team has enough information to proceed (or pivot) with confidence

---

## Findings

> _To be filled during spike execution._

### Goal Answers

| # | Question | Answer | Evidence |
|---|----------|--------|----------|
| 1 | | | |

### Technical Notes

<Free-form: discoveries, gotchas, links to PoC code, benchmarks, diagrams.>

---

## Recommendation

> _To be filled after spike execution._

**Proceed / Pivot / Stop** — <one sentence rationale>

### Suggested Next Steps

1. <Concrete action — links to plan.md tasks or new tasks to create>
2. …

---

## References

| Title | URL / Path |
|-------|-----------|
| <Doc or file name> | <link or path> |

---

_Spike created: <YYYY-MM-DD>_
```

---

## Phase 5 — Spike Report (PM / Lead Presentation)

After completing `spike.md`, generate a second file `spike-report.md` in the same folder. This is a **non-technical executive summary** for Product Managers and Tech Leads — not engineers.

### Rules for spike-report.md
- **No code snippets, no file paths, no class names** — business language only
- Lead with decisions and confidence, not process
- Every section must be answerable by a non-engineer
- Use **Mermaid diagrams** to illustrate user flow and system overview
- Use plain-language risk descriptions (impact to user/business, not to code)
- Table of **What's Changing** uses ADD / UPDATED / NO CHANGE / REMOVED — not file names

### Output Structure for `spike-report.md`

```markdown
# Spike Report: <Feature Name>

> **Audience**: Product Manager / Tech Lead
> **Date**: <YYYY-MM-DD>
> **Status**: <✅ Ready to Build | ⚠️ Needs Decision | 🔴 Blocked>
> **Confidence**: <🟢 High | 🟡 Medium | 🔴 Low>
> **Full Technical Spike**: [spike.md](./spike.md)

---

## What Are We Building?

<2–3 plain sentences. What problem does this solve for the user? What will they be able to do that they couldn't before?>

---

## Decisions Made

| Decision | What We Decided | Why |
|----------|-----------------|-----|
| <Question the team faced> | <Chosen approach in plain language> | <One-line rationale> |

---

## How It Works

<One sentence intro to the flow below.>

```mermaid
flowchart TD
    ...user journey from entry to success/failure...
```

---

## System Overview

<One sentence: which systems are touched.>

```mermaid
flowchart LR
    ...high-level system boxes and arrows...
```

---

## What's Changing

| Type | What |
|------|------|
| ➕ NEW | <Plain-language description — no file names> |
| ✏️ UPDATED | <Plain-language description> |
| ✅ NO CHANGE | <What is explicitly preserved> |
| ❌ REMOVED | <What is deleted, or "Nothing removed"> |

---

## Effort Estimate

| Work Item | Estimate | Notes |
|-----------|----------|-------|
| <Feature name> | <N story points> | <Short note> |

---

## Risks

| Risk | Plain Language | Likelihood | Impact | Plan |
|------|----------------|-----------|--------|------|
| <Short name> | <What could go wrong in user/business terms> | 🔴/🟡/🟢 | 🔴/🟡/🟢 | <Mitigation in plain language> |

---

## Open Questions

<"All resolved." or a short table of outstanding decisions.>

---

## Next Steps

1. <Plain action — who does what>
2. …

---

_Report generated: <YYYY-MM-DD>_
```

---

## Constraints

- Do NOT implement any code — this agent produces a document, not software
- Do NOT mark Goals as answered unless there is actual evidence (codebase search result or web research finding)
- Do NOT invent risks — only include risks grounded in the plan's content or research
- Spike scope must stay tightly coupled to the plan's uncertainties — do not over-expand
- If the plan is already low-risk with no unknowns, state that clearly and produce a minimal spike with a 🟢 Confidence rating
- All web research must cite the source in the References table
- Time-box must be realistic: derive from plan complexity, cap at 5 days; flag if the spike itself needs a spike
