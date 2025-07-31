---
mode: agent
---

# User Stories Generator

Transform implementation plan modules into detailed user stories with complete acceptance criteria and context from original requirements.

## Input Sources
- **Primary**: `.docs/overview-plan.json` (implementation plan)
- **Reference**: `.docs/requirements/**` (original requirement documents)
- **Context**: All requirement analysis files for detailed context

## Task Requirements

### Story Generation Process
1. **Extract Module Information**
   - Parse phase and module definitions from plan
   - Identify associated requirements and acceptance criteria
   - Map to user personas and business value

2. **Enrich with Original Context**
   - Cross-reference requirement IDs with analysis files
   - Extract detailed business context and rationale
   - Include relevant business rules and constraints

3. **Structure as User Stories**
   - Follow standard user story format
   - Include comprehensive acceptance criteria
   - Add technical notes and dependencies

## Output Structure
- **Location**: `.docs/user-stories/phase-{phase-id}/`
- **Naming Convention**: `us-{phase}.{story-number}-{descriptive-title}.md`
- **Example**: `us-1.1-user-authentication.md`, `us-1.2-dashboard-layout.md`, `us-2.1-payment-processing.md`

### File Format Template
```markdown
# User Story {Phase}.{Number}: {Title}

## Story
**As a** {user role}  
**I want** {functionality}  
**So that** {business value}

## Business Context
- **Module**: {module name}
- **Phase**: {phase name}
- **Priority**: {priority level}
- **Business Value**: {value statement}
- **Related Requirements**: {REQ-IDs}

## Acceptance Criteria
### Functional Requirements
- [ ] **Given** {precondition} **When** {action} **Then** {expected result}
- [ ] **Given** {precondition} **When** {action} **Then** {expected result}

### Non-Functional Requirements
- [ ] Performance: {specific metrics}
- [ ] Security: {security requirements}
- [ ] Usability: {usability requirements}

## Business Rules
- {Rule 1}: {Description}
- {Rule 2}: {Description}

## Dependencies
### Technical Dependencies
- {Component/Service}: {Reason}

### Story Dependencies
- {Story ID}: {Relationship}

## Definition of Done
- [ ] Code implemented and reviewed
- [ ] Unit tests written and passing
- [ ] Integration tests passing
- [ ] Documentation updated
- [ ] Acceptance criteria verified
- [ ] Performance requirements met
- [ ] Security requirements validated

## Notes
### Technical Considerations
- {Technical constraint or consideration}

### Business Assumptions
- {Assumption made during story creation}

## Estimated Effort
- **Story Points**: {points}
- **Estimated Hours**: {hours}
- **Complexity**: {Low|Medium|High}
```

## Story Quality Standards
- **Independent**: Can be developed standalone
- **Negotiable**: Details can be discussed with stakeholders
- **Valuable**: Delivers business value
- **Estimable**: Size can be estimated
- **Small**: Completable within one iteration
- **Testable**: Acceptance criteria are verifiable

## Naming & Organization
- **Phase Folder**: `phase-{phase-id}/` (e.g., `phase-1/`, `phase-2/`)
- **Story File**: `us-{phase}.{story}-{descriptive-title}.md` (e.g., `us-1.1-user-authentication.md`, `us-2.3-payment-gateway.md`)
- **Story Numbering**: Sequential within each phase
- **Title Format**: `{Action Verb} {Object} {Context}`
- **File Naming**: Kebab-case descriptive titles based on story functionality

## Success Criteria
- All modules from implementation plan converted to stories
- Each story traceable to original requirements
- Acceptance criteria comprehensive and testable
- Dependencies properly identified
- Stories sized appropriately for development iterations
- Business context preserved from original requirements
