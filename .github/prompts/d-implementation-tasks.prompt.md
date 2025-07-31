````prompt
---
mode: agent
---

# Implementation Tasks Generator

Transform user stories into executable implementation tasks.

## Input
- Primary: `.docs/user-stories/phase-{x}/us-{x}.{y}-{description}.md`
- Reference: `.docs/overview-plan.json`

## Process
1. Parse acceptance criteria into development tasks
2. Break down into atomic, executable tasks
3. Add technical specifications

## Output
- Location: `.docs/tasks/phase-{phase}/us-{phase}.{story}/`
- Files: `task-{phase}.{story}.{task}-{name}.md`

### Task Template
```markdown
# Task {Phase}.{Story}.{Task}: {Name}

## Overview
- User Story: us-{phase}.{story}-{description}
- Task ID: task-{phase}.{story}.{task}-{name}
- Priority: High|Medium|Low
- Effort: {hours}
- Dependencies: {task files}

## Description
{Implementation details}

## Technical Requirements
### Components
- Frontend: {components}
- Backend: {services}
- Database: {tables}
- Integration: {systems}

### Tech Stack
- Language/Framework: {versions}
- Dependencies: {packages}
- Tools: {dev/test tools}

## Implementation Steps
### Step 1: {Name}
- Action: {specific action}
- Deliverable: {output}
- Acceptance: {verification}
- Files: {create/modify}

## Technical Specs
### API Endpoints
```
GET /api/endpoint
POST /api/endpoint
```

### Database
```sql
CREATE TABLE example (id SERIAL PRIMARY KEY);
```

## Testing
- [ ] Unit tests for {functions}
- [ ] Integration tests for {flows}
- [ ] E2E tests for {workflows}

## Acceptance Criteria
- [ ] {Criteria from user story}
- [ ] Steps completed
- [ ] Tests passing

## Dependencies
- Before: {prerequisite tasks}
- After: {dependent tasks}
- External: {services/infrastructure}

## Risks
- Risk: {issue}
- Mitigation: {approach}

## Definition of Done
- [ ] Code implemented
- [ ] Tests passing
- [ ] Reviewed
- [ ] Integrated
```

## Task Standards
- Atomic: Independently completable
- Explicit: No implementation assumptions
- Testable: Clear validation criteria
- Traceable: Links to user story

## Success Criteria
- All acceptance criteria covered
- Tasks atomic (1-3 days)
- Dependencies identified
- Technical specs complete
