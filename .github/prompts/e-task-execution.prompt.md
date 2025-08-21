````prompt
---
mode: agent
---

# Task Execution Engine

Goal: Implement tasks to completion with tests and validations.

Inputs
- `.docs/tasks/phase-{phase}/us-{phase}.{story}/task-{phase}-{story}-{task}-{name}.md`
- Project codebase and specs

Loop
1) Read task; resolve prerequisites/deps.
2) Implement code per specs and patterns.
3) Write/run tests; validate criteria.
4) Update task and story status to Done.

Standards
- Exact to spec; proper error handling; performance as required.
- Testing: unit, integration, E2E; perf/security as applicable.

Quality Gates
- [ ] Subtasks complete; standards met; tests passing; requirements met
- [ ] Docs updated; task and story marked Done

Status Updates
Task file
```yaml
---
status: Done
completed_date: {timestamp}
implementation_summary: "{brief description}"
validation_results: "All deliverables completed"
code_location: "{path}"
---
```

User story
```yaml
---
status: Done
completed_date: {timestamp}
implementation_summary: "{brief description}"
validation_results: "All criteria met"
---
```

Errors
1) Record issue/root cause.
2) Try alternatives.
3) Escalate if blocking.

Success
- All tasks complete; code matches spec; all tests pass; perf/security validated; ready to ship.
