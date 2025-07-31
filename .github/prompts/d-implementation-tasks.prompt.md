---
mode: agent
---

# Implementation Tasks Generator

Transform user stories into detailed, executable implementation tasks with explicit development steps, technical specifications, and complete task breakdowns.

## Input Sources
- **Primary**: User story files from `.docs/user-stories/phase-{x}/us-{x}.{y}-{description}.md`
- **Reference**: `.docs/overview-plan.json` for technical architecture context
- **Context**: Related user stories for dependency understanding

## Task Requirements

### Task Generation Process
1. **Analyze User Story**
   - Parse acceptance criteria into development tasks
   - Identify technical components needed
   - Map to architecture from implementation plan

2. **Break Down Implementation**
   - Create atomic, executable tasks
   - Define subtasks with specific deliverables
   - Include testing and validation steps

3. **Add Technical Specifications**
   - Database schema changes
   - API specifications
   - UI/UX implementation details
   - Integration requirements

4. **Generate Individual Task Files**
   - Create separate files for each major task
   - Use hierarchical numbering system (phase.story.task)
   - Include descriptive names for easy identification
   - Maintain traceability to user story

## Output Structure
- **Location**: `.docs/tasks/phase-{phase-id}/us-{phase}.{story}/`
- **Task Files**: `task-{phase}.{story}.{task-number}-{descriptive-name}.md` for each major task
- **Supporting Files**: Technical specifications as needed

### File Structure Example
```
.docs/tasks/
└── phase-1/
    └── us-1.1/
        ├── task-1.1.1-setup-auth-service.md
        ├── task-1.1.2-implement-login-flow.md
        ├── task-1.1.3-create-user-dashboard.md
        ├── api-spec.yaml (if applicable)
        ├── database-schema.sql (if applicable)
        └── ui-mockups/ (if applicable)
```

### Individual Task File Template
```markdown
# Task {Phase}.{Story}.{Task}: {Task Name}

## Task Overview
- **User Story**: us-{phase}.{story}-{description}
- **Task ID**: task-{phase}.{story}.{task}-{descriptive-name}
- **Priority**: {High|Medium|Low}
- **Estimated Effort**: {hours}
- **Dependencies**: {other task files}

## Description
{Detailed description of what needs to be implemented in this specific task}

## Technical Requirements
### Architecture Components
- **Frontend**: {specific components for this task}
- **Backend**: {specific services/controllers for this task}
- **Database**: {specific tables/collections for this task}
- **Integration**: {specific external systems for this task}

### Technology Stack
- **Language/Framework**: {specific versions}
- **Dependencies**: {new packages required}
- **Tools**: {development/testing tools}

## Implementation Steps

### Step 1: {Step Name}
- **Action**: {Specific action to take}
- **Deliverable**: {Expected output}
- **Acceptance**: {How to verify completion}
- **Files**: {Files to create/modify}

### Step 2: {Step Name}
- **Action**: {Specific action to take}
- **Deliverable**: {Expected output}
- **Acceptance**: {How to verify completion}
- **Files**: {Files to create/modify}

## Technical Specifications
### API Endpoints (if applicable)
```
GET /api/endpoint
POST /api/endpoint
```

### Database Changes (if applicable)
```sql
CREATE TABLE example (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100)
);
```

### Component Structure (if applicable)
```
ComponentName/
├── index.tsx
├── styles.css
└── types.ts
```

## Testing Requirements
- [ ] Unit tests for {specific functions/methods}
- [ ] Integration tests for {specific flows}
- [ ] E2E tests for {user workflows}
- [ ] Performance tests for {specific metrics}

## Acceptance Criteria
- [ ] {Specific acceptance criteria from user story}
- [ ] {Technical acceptance criteria}
- [ ] All implementation steps completed
- [ ] Tests written and passing
- [ ] Code reviewed and approved

## Dependencies
### Task Dependencies
- **Before**: {tasks that must complete first}
- **After**: {tasks that depend on this task}

### External Dependencies
- **Services**: {external APIs/services required}
- **Infrastructure**: {deployment/environment requirements}

## Risk Mitigation
- **Risk**: {potential issue}
- **Mitigation**: {approach to address}

## Definition of Done
- [ ] All implementation steps completed
- [ ] Code follows project standards
- [ ] Tests written and passing
- [ ] Documentation updated
- [ ] Peer review completed
- [ ] Integration validated
```

## Task Generation Guidelines

### Task Identification
1. **Analyze User Story Acceptance Criteria**
   - Each acceptance criterion should map to one or more tasks
   - Break down complex criteria into multiple focused tasks
   - Ensure each task delivers measurable value

2. **Task Sizing**
   - Each task should be completable within 1-3 days
   - If larger, break into smaller sub-tasks
   - Consider developer skill level and complexity

3. **Task Numbering**
   - Use hierarchical numbering: `{phase}.{story}.{task}`
   - Example: For user story `us-1.2`, tasks are `task-1.2.1`, `task-1.2.2`, etc.
   - Maintains clear traceability from phase → story → task

4. **Task Naming**
   - Use action-oriented, descriptive names
   - Follow pattern: `task-{phase}.{story}.{task}-{verb}-{object}-{context}`
   - Examples: `task-1.1.1-setup-auth-service`, `task-1.1.2-implement-password-reset`, `task-2.3.1-create-payment-gateway`

## Cross-Story Dependencies
### Internal Dependencies
- **Task Dependencies**: {task files that must complete first}
- **Story Dependencies**: {other user stories that must complete first}

### External Dependencies
- **Third-party Services**: {external APIs/services required}
- **Infrastructure**: {deployment/environment requirements}
- **Team Dependencies**: {other team deliverables needed}

## Risk Assessment
### Technical Risks
- **Risk**: {description}
  - **Impact**: {High|Medium|Low}
  - **Mitigation**: {approach to address}

### Implementation Risks
- **Risk**: {description}
  - **Impact**: {High|Medium|Low}
  - **Mitigation**: {approach to address}

## Validation Checklist
### Functional Validation
- [ ] All acceptance criteria from user story met
- [ ] Business rules properly implemented
- [ ] Error handling implemented
- [ ] Input validation implemented

### Technical Validation
- [ ] Code follows project standards
- [ ] Performance requirements met
- [ ] Security requirements implemented
- [ ] Accessibility requirements met
- [ ] Cross-browser/device compatibility

### Integration Validation
- [ ] API contracts maintained
- [ ] Database migrations successful
- [ ] Third-party integrations working
- [ ] Monitoring/logging implemented

## Deployment Notes
### Environment Changes
- **Configuration**: {environment variables/settings}
- **Infrastructure**: {new resources needed}
- **Migrations**: {database/data migrations}

### Rollback Plan
- **Rollback Steps**: {steps to undo changes}
- **Data Recovery**: {approach for data rollback}
- **Monitoring**: {what to monitor post-deployment}
```

## Task Quality Standards
- **Atomic**: Each task completable independently
- **Explicit**: No assumptions about implementation approach
- **Testable**: Clear validation criteria
- **Traceable**: Links back to user story acceptance criteria
- **Executable**: Sufficient detail for implementation

## Naming & Organization
- **Folder Structure**: `phase-{id}/us-{phase}.{story}/`
- **Task Files**: `task-{phase}.{story}.{task}-{descriptive-name}.md` (e.g., `task-1.1.1-setup-database.md`, `task-1.1.2-create-api-endpoints.md`)
- **Supporting Files**: Domain-specific technical files
- **Task Naming**: Action-oriented, specific outcomes using kebab-case
- **Numbering**: Hierarchical - matches user story number plus sequential task number

## Success Criteria
- All user story acceptance criteria covered by individual task files
- Each task file is atomic and independently executable
- Tasks are granular enough for daily development (1-3 days each)
- Technical specifications complete and accurate in each task
- Dependencies clearly identified between task files
- Testing strategy comprehensive for each task
- Implementation approach technically sound
- Validation criteria measurable and specific
- File naming follows consistent patterns for easy navigation
