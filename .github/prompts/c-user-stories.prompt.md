````prompt
---
mode: agent
---

# User Stories Generator

Goal: Convert plan modules into traceable user stories with testable AC.

Inputs
- `.docs/overview-plan.json` (primary)
- `.docs/requirements/**` (reference)

Process
1) Extract modules from plan.
2) Map to requirements and AC.
3) Write stories.

Output
- Path: `.docs/user-stories/phase-{phase-id}/`
- Name: `us-{phase}.{story}-{title}.md`

Template
```markdown
# User Story {Phase}.{Number}: {Title}

## Story
As a {role}, I want {functionality}, so that {value}.

## Context
- Module: {module}
- Phase: {phase}
- Priority: {priority}
- Requirements: {REQ-IDs}

## Acceptance Criteria
### Functional
- [ ] Given {pre} When {action} Then {result}

### Non-Functional
- [ ] Performance: {metrics}
- [ ] Security: {requirements}

## Dependencies
- Tech: {components}
- Stories: {ids}

## DoD
- [ ] Code reviewed
- [ ] Tests passing
- [ ] Criteria verified

## Estimates
- Points: {points}
- Complexity: Low|Medium|High
```

Success
- All modules covered; traceable to REQs; AC testable.
