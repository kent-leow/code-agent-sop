---
mode: agent
---

# Implementation Tasks Generator

Transform user stories into detailed, executable implementation tasks with explicit development steps, technical specifications, and complete task breakdowns.

## Input Sources
- **Primary**: User story files from `.docs/user-stories/phase-{x}/us-{x}.{y}.md`
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

## Output Structure
- **Location**: `.docs/tasks/phase-{phase-id}/us-{phase}.{story}/`
- **Main File**: `implementation-tasks.md`
- **Supporting Files**: Technical specifications as needed

### File Structure Example
```
.docs/tasks/
└── phase-1/
    └── us-1.1/
        ├── implementation-tasks.md
        ├── api-spec.yaml (if applicable)
        ├── database-schema.sql (if applicable)
        └── ui-mockups/ (if applicable)
```

### Implementation Tasks Template
```markdown
# Implementation Tasks: {Story Title}

## Story Reference
- **Story ID**: us-{phase}.{story}
- **Story Title**: {title}
- **Estimated Effort**: {story points/hours}

## Technical Overview
### Architecture Components
- **Frontend**: {components affected}
- **Backend**: {services/controllers affected}
- **Database**: {tables/collections affected}
- **Integration**: {external systems}

### Technology Stack
- **Language/Framework**: {specific versions}
- **Dependencies**: {new packages required}
- **Tools**: {development/testing tools}

## Implementation Tasks

### Task 1: {Task Name}
**Priority**: {High|Medium|Low}  
**Estimated Effort**: {hours}  
**Dependencies**: {other tasks}

#### Description
{Detailed description of what needs to be implemented}

#### Subtasks
1. **{Subtask Name}**
   - **Action**: {Specific action to take}
   - **Deliverable**: {Expected output}
   - **Acceptance**: {How to verify completion}
   - **Files**: {Files to create/modify}

2. **{Subtask Name}**
   - **Action**: {Specific action to take}
   - **Deliverable**: {Expected output}
   - **Acceptance**: {How to verify completion}
   - **Files**: {Files to create/modify}

#### Technical Specifications
- **API Endpoints**: {if applicable}
  ```
  GET /api/endpoint
  POST /api/endpoint
  ```
- **Database Changes**: {if applicable}
  ```sql
  CREATE TABLE example (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100)
  );
  ```
- **Component Structure**: {if applicable}
  ```
  ComponentName/
  ├── index.tsx
  ├── styles.css
  └── types.ts
  ```

#### Testing Requirements
- [ ] Unit tests for {specific functions/methods}
- [ ] Integration tests for {specific flows}
- [ ] E2E tests for {user workflows}
- [ ] Performance tests for {specific metrics}

#### Definition of Done
- [ ] Code implemented according to specifications
- [ ] All subtasks completed
- [ ] Tests written and passing
- [ ] Code reviewed and approved
- [ ] Documentation updated
- [ ] Acceptance criteria from story verified

### Task 2: {Task Name}
{Repeat structure for each task}

## Dependencies
### Internal Dependencies
- **Task Dependencies**: {tasks that must complete first}
- **Story Dependencies**: {other stories that must complete first}

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
- **Main File**: `implementation-tasks.md`
- **Supporting Files**: Domain-specific technical files
- **Task Naming**: Action-oriented, specific outcomes

## Success Criteria
- All user story acceptance criteria covered by tasks
- Tasks are granular enough for daily development
- Technical specifications complete and accurate
- Dependencies clearly identified
- Testing strategy comprehensive
- Implementation approach technically sound
- Validation criteria measurable and specific
