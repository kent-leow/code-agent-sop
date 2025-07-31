---
mode: agent
---

# Business Requirements Analysis

Transform raw business requirements/transcripts into comprehensive, detailed business requirements suitable for complete application development.

## Input Sources
- **Location**: `.docs/requirements/**`
- **Formats**: Meeting transcripts, requirement documents, stakeholder interviews, feature requests
- **File types**: `.md`, `.txt`, `.docx`, `.pdf`

## Task Requirements

### Analysis Process
1. **Extract Core Requirements**
   - Functional requirements with acceptance criteria
   - Non-functional requirements (performance, security, scalability)
   - Business rules and constraints
   - User personas and use cases

2. **Identify Gaps & Assumptions**
   - Missing information requiring clarification
   - Implicit assumptions made
   - Dependencies on external systems
   - Regulatory/compliance requirements

3. **Structure & Prioritize**
   - Categorize by business domain/module
   - Assign priority levels (Critical, High, Medium, Low)
   - Define MVP vs future phases
   - Map requirements to business value

## Output Structure
- **Location**: `.docs/analysis/**`
- **Naming**: `{domain}-requirements-v{version}.md`
- **Format**: Structured markdown with sections:

```markdown
# {Domain} Business Requirements Analysis

## Executive Summary
- Business objectives
- Success metrics
- High-level scope

## Functional Requirements
### {Module Name}
- **REQ-{ID}**: {Requirement}
  - **Priority**: {Critical|High|Medium|Low}
  - **Acceptance Criteria**: 
    - [ ] Criteria 1
    - [ ] Criteria 2
  - **Dependencies**: {List}
  - **Assumptions**: {List}

## Non-Functional Requirements
- Performance requirements
- Security requirements
- Scalability requirements
- Usability requirements

## Business Rules
- Validation rules
- Workflow rules
- Authorization rules

## Data Requirements
- Entity definitions
- Data relationships
- Data quality requirements

## Integration Requirements
- External system dependencies
- API requirements
- Data exchange formats

## Constraints & Assumptions
- Technical constraints
- Business constraints
- Timeline constraints

## Risks & Mitigations
- Identified risks
- Proposed mitigations
```

## Quality Standards
- **Completeness**: All requirements traceable to business needs
- **Clarity**: Unambiguous language, measurable criteria
- **Consistency**: No conflicting requirements
- **Testability**: Each requirement verifiable

## Success Criteria
- Requirements cover 100% of stated business needs
- All assumptions explicitly documented
- Acceptance criteria defined for each functional requirement
- Non-functional requirements quantified where possible
