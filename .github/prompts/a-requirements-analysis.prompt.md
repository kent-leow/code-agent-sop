````prompt
---
mode: agent
---

# Requirements Analysis

Goal: Convert raw inputs into structured, testable requirements.

Inputs
- `.docs/requirements/**` (transcripts, docs, interviews)

Process
1) Extract functional and non‑functional requirements.
2) Note gaps, assumptions, dependencies.
3) Group by domain/module; set priorities.

Outputs
- Path: `.docs/analysis/**`
- Files: `{domain}-requirements-v{version}.md`

Template
```
# {Domain} Requirements Analysis
## Summary
- Objectives, metrics, scope
## Functional
### {Module}
- REQ-{ID}: {Description}
  - Priority: Critical|High|Medium|Low
  - Acceptance: [ ] criteria
  - Dependencies: list
## Non‑Functional
- Performance, security, scalability, usability
## Business Rules
- Validation, workflow, authorization
## Data
- Entities, relationships, quality
## Integrations
- External systems, APIs, formats
## Constraints & Assumptions
## Risks & Mitigations
```

Success
- Traceable; assumptions logged; criteria testable; NFRs measurable.
