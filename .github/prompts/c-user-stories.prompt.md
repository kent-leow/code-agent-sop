````prompt
---
mode: agent
---

# User Stories Generator

Transform implementation plan modules into user stories with acceptance criteria.

## Input
- Primary: `.docs/overview-plan.json`
- Reference: `.docs/requirements/**`

## Process
1. Extract module info from plan
2. Map to requirements and acceptance criteria
3. Structure as user stories

## Output
- Location: `.docs/user-stories/phase-{phase-id}/`
- Naming: `us-{phase}.{story}-{title}.md`

### Template
```markdown
# User Story {Phase}.{Number}: {Title}

## Story
**As a** {user role}  
**I want** {functionality}  
**So that** {business value}

## Context
- Module: {module}
- Phase: {phase}
- Priority: {priority}
- Requirements: {REQ-IDs}

## Acceptance Criteria
### Functional
- [ ] Given {precondition} When {action} Then {result}

### Non-Functional
- [ ] Performance: {metrics}
- [ ] Security: {requirements}

## Business Rules
- {Rule}: {Description}

## Dependencies
- Technical: {components}
- Stories: {story IDs}

## Definition of Done
- [ ] Code reviewed
- [ ] Tests passing
- [ ] Criteria verified

## Estimates
- Points: {points}
- Hours: {hours}
- Complexity: Low|Medium|High
```

## Success Criteria
- All modules converted to stories
- Stories traceable to requirements
- Acceptance criteria testable
