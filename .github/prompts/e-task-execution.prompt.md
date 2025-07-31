---
mode: agent
---

# Task Execution Engine

Execute implementation tasks efficiently by following the detailed task breakdown, implementing code, running tests, and validating completion against defined criteria.

## Input Sources
- **Primary**: `.docs/user-stories/phase-{x}/us-{x}.{y}-{description}.md`
- **Context**: Related technical specifications and supporting files
- **Reference**: Project codebase and existing patterns

## Task Requirements

### Execution Process
1. **Task Analysis & Planning**
   - Parse task structure and dependencies
   - Validate prerequisites are met
   - Set up development environment
   - Plan execution order

2. **Implementation Execution**
   - Follow subtask sequence precisely
   - Implement code according to specifications
   - Apply project patterns and standards
   - Handle errors and edge cases

3. **Validation & Testing**
   - Execute all defined tests
   - Validate against acceptance criteria
   - Perform integration testing
   - Verify performance requirements

4. **Documentation & Completion**
   - Update relevant documentation
   - Complete definition of done checklist
   - Prepare for code review
   - Mark task as complete
   - **Update user story status to done**

## Execution Standards

### Code Implementation
- **Follow Specifications**: Implement exactly as specified in tasks
- **Use Project Patterns**: Maintain consistency with existing codebase
- **Error Handling**: Implement comprehensive error handling
- **Performance**: Meet specified performance requirements
- **Security**: Follow security best practices
- **Accessibility**: Ensure accessible implementation

### Testing Approach
- **Unit Tests**: Test individual functions/methods
- **Integration Tests**: Test component interactions
- **E2E Tests**: Test complete user workflows
- **Performance Tests**: Validate performance metrics
- **Security Tests**: Verify security requirements

### Quality Gates
Before marking any task complete, ensure:
- [ ] All subtasks completed
- [ ] Code follows project standards
- [ ] Tests written and passing
- [ ] Performance requirements met
- [ ] Security requirements validated
- [ ] Documentation updated
- [ ] Code reviewed (if required)
- [ ] Deployment ready
- [ ] **User story marked as done**

## Execution Flow

### 1. Pre-Execution Setup
```bash
# Validate environment
- Check development environment setup
- Verify dependencies installed
- Confirm database/services running
- Create feature branch (if using Git)
```

### 2. Task-by-Task Execution
For each task in implementation-tasks.md:

```bash
# Task Start
- Read task description and specifications
- Review subtasks and acceptance criteria
- Check dependencies satisfied
- Begin implementation

# Subtask Execution
For each subtask:
  - Implement specific deliverable
  - Run relevant tests
  - Verify acceptance criteria
  - Update progress

# Task Completion
- Run all task tests
- Validate against definition of done
- Update documentation
- Mark task complete
- Update source user story status
```

### 3. Integration & Validation
```bash
# Integration Testing
- Run full test suite
- Test integration points
- Validate end-to-end workflows
- Check performance benchmarks

# Final Validation
- Verify all acceptance criteria met
- Confirm business rules implemented
- Test error scenarios
- Validate security requirements
```

### 4. Completion & Handoff
```bash
# Documentation Update
- Update API documentation
- Update user documentation
- Update deployment notes
- Update changelog

# Code Review Preparation
- Clean up code
- Add comments where needed
- Ensure code standards compliance
- Create pull request (if applicable)

# User Story Status Update
- Update source user story file status to "Done"
- Add completion timestamp
- Document any deviations from original requirements
- Link to implemented code/features
```

## Error Handling Protocol

### When Tasks Fail
1. **Document the Issue**
   - Capture error details
   - Identify root cause
   - Assess impact on timeline

2. **Attempt Resolution**
   - Try alternative approaches
   - Consult project patterns
   - Review specifications for clarity

3. **Escalate if Needed**
   - Flag blocking issues
   - Request clarification on requirements
   - Seek technical guidance

### Recovery Strategies
- **Rollback**: Revert to last working state
- **Alternative Implementation**: Use different technical approach
- **Scope Adjustment**: Modify requirements if necessary
- **Dependency Resolution**: Address blocking dependencies

## Progress Tracking

### User Story Status Management
After successful task completion, update the source user story file:

```markdown
# Update Pattern for User Stories
## Status Update in `.docs/user-stories/phase-{x}/us-{x}.{y}-{description}.md`

### Required Updates
1. **Status Field**: Change from "In Progress" → "Done"
2. **Completion Date**: Add timestamp of completion
3. **Implementation Notes**: Brief summary of what was built
4. **Validation Results**: Summary of test results and acceptance criteria validation

### Update Format
```yaml
---
status: Done
completed_date: {YYYY-MM-DD HH:MM:SS}
implemented_by: {system/agent identifier}
validation_status: Passed
---

## Implementation Summary
- **Features Delivered**: {list of completed features}
- **Tests Status**: {test results summary}
- **Acceptance Criteria**: {all criteria met confirmation}
- **Performance**: {performance validation results}
- **Security**: {security validation results}
```

### Validation Before Status Update
- [ ] All acceptance criteria validated
- [ ] All tests passing
- [ ] Performance requirements met
- [ ] Security requirements satisfied
- [ ] Integration tests completed
- [ ] Documentation updated
```

### Task Status Levels
- **Not Started**: Task not yet begun
- **In Progress**: Currently being implemented
- **Blocked**: Waiting for dependency/resolution
- **Testing**: Implementation complete, validation in progress
- **Review**: Ready for code review
- **Complete**: All criteria met, task finished

### Reporting Format
```markdown
## Execution Status Report

### Current Task: {Task Name}
- **Status**: {status level}
- **Progress**: {percentage complete}
- **Estimated Completion**: {date/time}

### Completed Subtasks
- [x] {Subtask name} - {completion date}
- [x] {Subtask name} - {completion date}

### In Progress Subtasks
- [ ] {Subtask name} - {current status}

### Blocked Items
- {Blocker description} - {resolution needed}

### Next Steps
1. {Next action item}
2. {Next action item}
```

## Success Criteria
- All tasks from implementation-tasks.md completed
- Code matches technical specifications exactly
- All tests passing at unit, integration, and E2E levels
- Performance requirements validated
- Security requirements implemented
- Documentation updated and accurate
- **Source user story file updated to "Done" status**
- **Implementation summary added to user story**
- Ready for deployment or next phase
- Zero critical bugs or issues remaining

## User Story Completion Protocol

### Final Step: Mark User Story as Done
After all implementation and validation is complete:

1. **Locate Source User Story**
   - Find the original `.docs/user-stories/phase-{x}/us-{x}.{y}-{description}.md` file
   - Verify this is the correct source user story

2. **Update Status Metadata**
   ```yaml
   ---
   status: Done
   completed_date: {current timestamp}
   implementation_summary: "{brief description of what was built}"
   validation_results: "All acceptance criteria met, tests passing"
   ---
   ```

3. **Add Implementation Notes Section**
   ```markdown
   ## Implementation Completed
   
   ### Delivered Features
   - {feature 1 with brief description}
   - {feature 2 with brief description}
   
   ### Technical Implementation
   - **Code Location**: {main files/modules created}
   - **Test Coverage**: {test suite summary}
   - **Performance**: {performance validation results}
   - **Security**: {security measures implemented}
   
   ### Validation Results
   - [x] All acceptance criteria met
   - [x] Unit tests passing
   - [x] Integration tests passing
   - [x] Performance requirements satisfied
   - [x] Security requirements validated
   
   **Completion Date**: {timestamp}
   **Status**: ✅ DONE
   ```

4. **Verify Update**
   - Confirm file is saved properly
   - Verify status change is reflected
   - Ensure all required information is documented
