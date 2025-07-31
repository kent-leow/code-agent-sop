````prompt
---
mode: agent
---

# Task Execution Engine

Execute implementation tasks by following task breakdown, implementing code, testing, and validating completion.

## Input
- Primary: `.docs/tasks/phase-{phase}/us-{phase}.{story}/task-{phase}-{story}-{task}-{name}.md`
- Context: Technical specs, project codebase

## Process
1. Parse task dependencies and prerequisites
2. Implement code per specifications
3. Execute tests and validate criteria
4. Update task/story status to "Done"

## Execution Standards
### Code Implementation
- Follow specifications exactly
- Use project patterns
- Implement error handling
- Meet performance requirements

### Testing Approach
- Unit tests: functions/methods
- Integration tests: component interactions
- E2E tests: user workflows
- Performance/security validation

### Quality Gates
- [ ] All subtasks completed
- [ ] Code follows standards
- [ ] Tests passing
- [ ] Requirements met
- [ ] Documentation updated
- [ ] Task file marked "Done"
- [ ] User story marked "Done"

## Status Updates
### Task File Update
```yaml
---
status: Done
completed_date: {timestamp}
implementation_summary: "{brief description}"
validation_results: "All deliverables completed"
code_location: "{path}"
---
```

### User Story Update
```yaml
---
status: Done
completed_date: {timestamp}
implementation_summary: "{brief description}"
validation_results: "All criteria met"
---
```

## Error Handling
1. Document issue and root cause
2. Try alternative approaches
3. Escalate if blocking

## Success Criteria
- All tasks completed
- Code matches specifications
- All tests passing
- Performance/security validated
- Source files marked "Done"
- Ready for deployment
