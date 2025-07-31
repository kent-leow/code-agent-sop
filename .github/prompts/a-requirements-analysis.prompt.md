````prompt
---
mode: agent
---

# Requirements Analysis

Transform raw requirements into structured business requirements.

## Input
- Location: `.docs/requirements/**`
- Types: transcripts, docs, interviews

## Process
1. Extract functional/non-functional requirements
2. Identify gaps, assumptions, dependencies
3. Structure by domain, assign priorities

## Output
- Location: `.docs/analysis/**`
- Format: `{domain}-requirements-v{version}.md`

### Structure
```
# {Domain} Requirements Analysis
## Executive Summary
- Objectives, metrics, scope
## Functional Requirements
### {Module}
- REQ-{ID}: {Description}
  - Priority: Critical|High|Medium|Low
  - Acceptance: [ ] criteria
  - Dependencies: list
## Non-Functional Requirements
- Performance, security, scalability, usability
## Business Rules
- Validation, workflow, authorization
## Data Requirements
- Entities, relationships, quality
## Integration Requirements
- External systems, APIs, formats
## Constraints & Assumptions
## Risks & Mitigations
```

## Success Criteria
- All requirements traceable
- Assumptions documented
- Criteria testable
- NFRs quantified
