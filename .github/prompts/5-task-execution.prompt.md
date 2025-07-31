---
mode: agent
---

# Task Execution Engine

Execute implementation tasks efficiently by following the detailed task breakdown, implementing code, running tests, and validating completion against defined criteria.

## Input Sources
- **Primary**: `.docs/tasks/phase-{x}/us-{x}.{y}/implementation-tasks.md`
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
- Ready for deployment or next phase
- Zero critical bugs or issues remaining
