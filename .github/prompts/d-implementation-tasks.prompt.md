````prompt
---
mode: agent
---

# Implementation Tasks Generator

Goal: Turn stories into atomic, executable tasks with specs.

Inputs
- `.docs/user-stories/phase-{x}/us-{x}.{y}-{desc}.md`
- `.docs/overview-plan.json`

Process
1) Parse AC into tasks.
2) Make tasks atomic and explicit.
3) Add technical specs.

Output
- Path: `.docs/tasks/phase-{phase}/us-{phase}.{story}/`
- Files: `task-{phase}.{story}.{task}-{name}.md`

Template
```markdown
# Task {Phase}.{Story}.{Task}: {Name}

## Overview
- Story: us-{phase}.{story}-{desc}
- ID: task-{phase}.{story}.{task}-{name}
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

## Steps
### Step 1: {Name}
- Action: {specific action}
- Deliverable: {output}
- Acceptance: {verification}
- Files: {create/modify}

## Specs
### API
GET /api/endpoint
POST /api/endpoint

### Database
```sql
CREATE TABLE example (id SERIAL PRIMARY KEY);
```

## Testing
- [ ] Unit: {functions}
- [ ] Integration: {flows}
- [ ] E2E: {workflows}

## Acceptance
- [ ] Story criteria covered
- [ ] Steps completed
- [ ] Tests passing

## Dependencies
- Before: {prereqs}
- After: {dependents}
- External: {services}

## Risks
- Risk: {issue}
- Mitigation: {approach}

## DoD
- [ ] Implemented
- [ ] Tests passing
- [ ] Reviewed
- [ ] Integrated
```

Standards
- Atomic; explicit; testable; traceable to story.

Success
- AC covered; 1–3 day tasks; deps identified; specs complete.
