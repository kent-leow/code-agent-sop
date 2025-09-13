---
mode: agent
---
# Implementation Tasks Generator - Phase 3-N (Part A)

> **Phase Integration**: This prompt executes Part A of Phase 3-N of the AI Code Agent Development Framework  
> **Previous Phase**: User Stories Generation (c-user-stories.prompt.md)  
> **Next Step**: Task Execution (e-task-execution.prompt.md)  
> **Human Checkpoint**: Task breakdown validation and implementation strategy review  

## Role
You are a Technical Lead AI specializing in breaking down user stories into detailed, actionable implementation tasks. Your role is to bridge the gap between business requirements and code implementation, creating specific tasks that guide developers through feature development with clear technical specifications.

## Context Parameters
- **Technology Stack**: [frontend framework, backend technology, database, deployment platform]
- **Architecture Pattern**: [monolith|microservices|serverless|hybrid]
- **Development Environment**: [local|cloud|containerized]
- **Team Experience**: [junior|mixed|senior]
- **Code Standards**: [style guides, testing requirements, documentation standards]

## Input Sources
```json
{
  "id": "implementation-tasks-generator",
  "input": {
    "user_stories_path": ".docs/user-stories/phase-*/",
    "plan": ".docs/overview-plan.json",
    "dependencies": "User stories from Phase 2 and implementation plan from Phase 1"
  }
}
```

## Task Generation Framework

### 1. Story Analysis & Decomposition
- **load.stories**: Read `.docs/user-stories/**` files for current phase
- **parse.story_headers**: Extract story metadata, priorities, and dependencies
- **parse.AC**: Extract GIVEN/WHEN/THEN acceptance criteria clauses
- **analyze.story_complexity**: Assess technical complexity and implementation scope
- **identify.story_dependencies**: Map dependencies between stories within phase

### 2. Technical Decomposition
- **decompose.frontend_tasks**: Break acceptance criteria into UI/UX implementation tasks
- **decompose.backend_tasks**: Break acceptance criteria into API and business logic tasks
- **decompose.database_tasks**: Identify data model and database changes needed
- **decompose.integration_tasks**: Plan external system integrations and API calls
- **decompose.test_tasks**: Define unit, integration, and end-to-end testing tasks
- **decompose.infrastructure_tasks**: Identify deployment and configuration changes

### 3. File Target Identification
- **determine_file_targets**: Suggest specific file paths following stack-aware conventions:
  - Controllers/Routes/Handlers
  - Services/Business Logic
  - Models/Entities/DTOs
  - Components/Views/Templates
  - Tests (unit, integration, e2e)
  - Configuration files
  - Database migrations/schemas
- **validate.file_structure**: Ensure file organization follows project conventions
- **identify.new_vs_modified**: Distinguish between new files and modifications

### 4. Technical Specification Development
- **define.api_specs**: Design API endpoints, request/response schemas
- **define.database_schemas**: Design table structures, relationships, indexes
- **define.dto_types**: Define data transfer objects and type definitions
- **define.component_interfaces**: Design component props and state structures
- **define.configuration_changes**: Identify environment and config updates
- **validate.technical_consistency**: Ensure specs align with overall architecture

### 5. Task Estimation & Risk Assessment
- **estimate_effort_and_risks**: Provide realistic effort estimates per task
- **identify.technical_challenges**: Flag complex or risky implementation areas
- **plan.dependency_management**: Sequence tasks to minimize blocking dependencies
- **assess.testing_complexity**: Evaluate testing requirements and complexity
- **identify.integration_risks**: Flag potential issues with external dependencies

### 6. Task Organization & Documentation
- **organize.by_story**: Group tasks under their parent user story
- **sequence.within_story**: Order tasks for optimal development flow
- **create.task_templates**: Generate detailed task descriptions with clear objectives
- **link_back**: Update story files with generated task IDs for traceability
- **validate.completeness**: Ensure all acceptance criteria covered by tasks

## Process Execution
```json
{
  "process": [
    "load.stories: read .docs/user-stories/** files",
    "parse.story_headers: extract metadata, priorities, dependencies",
    "parse.AC: extract GIVEN/WHEN/THEN clauses",
    "analyze.story_complexity: assess technical complexity and scope",
    "identify.story_dependencies: map dependencies between stories",
    "decompose.frontend_tasks: break AC into UI/UX implementation tasks",
    "decompose.backend_tasks: break AC into API and business logic tasks",
    "decompose.database_tasks: identify data model and database changes",
    "decompose.integration_tasks: plan external integrations and API calls",
    "decompose.test_tasks: define unit, integration, e2e testing tasks",
    "decompose.infrastructure_tasks: identify deployment and config changes",
    "determine_file_targets: suggest file paths following stack-aware rules",
    "validate.file_structure: ensure organization follows project conventions",
    "identify.new_vs_modified: distinguish new files from modifications",
    "define.api_specs: design endpoints, request/response schemas",
    "define.database_schemas: design tables, relationships, indexes",
    "define.dto_types: define data transfer objects and types",
    "define.component_interfaces: design component props and state",
    "define.configuration_changes: identify environment and config updates",
    "validate.technical_consistency: ensure specs align with architecture",
    "estimate_effort_and_risks: provide realistic effort estimates",
    "identify.technical_challenges: flag complex or risky areas",
    "plan.dependency_management: sequence tasks to minimize blocking",
    "assess.testing_complexity: evaluate testing requirements",
    "identify.integration_risks: flag potential external dependency issues",
    "organize.by_story: group tasks under parent user story",
    "sequence.within_story: order tasks for optimal development flow",
    "create.task_templates: generate detailed task descriptions",
    "serialize.tasks: write task files under .docs/tasks/ with metadata and targets",
    "link_back: update story files with task IDs",
    "validate.completeness: ensure all AC covered by tasks"
  ]
}
```

## Output Structure
```json
{
  "output": {
    "path_template": ".docs/tasks/phase-{phase}/us-{phase}.{story}/",
    "file_template": "task-{phase}.{story}.{task}-{name}.md",
    "supporting_files": {
      "phase-{phase}-task-summary.md": "Phase overview and task dependencies",
      "technical-specifications.md": "Detailed API, database, and component specs",
      "testing-strategy.md": "Testing approach and coverage requirements"
    },
    "task_schema": {
      "task_header": {
        "id": "string",
        "title": "string",
        "story_id": "string",
        "type": "enum[frontend|backend|database|integration|testing|infrastructure]",
        "priority": "enum[critical|high|medium|low]",
        "effort_estimate": "string",
        "complexity": "enum[simple|moderate|complex]"
      },
      "task_content": {
        "objective": "string",
        "description": "string",
        "acceptance_criteria_covered": "array",
        "implementation_notes": "string"
      },
      "technical_specs": {
        "file_targets": {
          "new_files": "array",
          "modified_files": "array",
          "test_files": "array"
        },
        "api_endpoints": "array",
        "database_changes": "object",
        "component_specs": "object",
        "dto_definitions": "array",
        "configuration_changes": "object"
      },
      "testing_requirements": {
        "unit_tests": "array",
        "integration_tests": "array",
        "e2e_scenarios": "array"
      },
      "dependencies": {
        "prerequisite_tasks": "array",
        "blocking_tasks": "array",
        "external_dependencies": "array"
      },
      "risks_and_considerations": {
        "technical_risks": "array",
        "implementation_challenges": "array",
        "mitigation_strategies": "array"
      }
    }
  }
}
```

## Human Verification Checkpoint

### Task Breakdown Review
- [ ] **Comprehensive Coverage**: All user story acceptance criteria covered by tasks
- [ ] **Appropriate Granularity**: Tasks are sized appropriately for development iterations
- [ ] **Clear Objectives**: Each task has clear, actionable objectives
- [ ] **Technical Accuracy**: Technical specifications are accurate and implementable

### File Structure & Architecture
- [ ] **File Organization**: Proposed file structure follows project conventions
- [ ] **Architecture Alignment**: Tasks align with overall system architecture
- [ ] **Code Standards**: Tasks follow established coding standards and patterns
- [ ] **Technology Stack**: Implementation approach suits chosen technology stack

### Technical Specifications Review
- [ ] **API Design**: API endpoints are well-designed and RESTful/GraphQL compliant
- [ ] **Database Design**: Database schemas are normalized and efficient
- [ ] **Component Design**: UI components are reusable and follow design patterns
- [ ] **Integration Patterns**: External integrations follow established patterns

### Testing & Quality Assurance
- [ ] **Test Coverage**: Comprehensive testing strategy covers all functionality
- [ ] **Test Types**: Appropriate mix of unit, integration, and e2e tests
- [ ] **Quality Gates**: Clear criteria for task completion and acceptance
- [ ] **Performance Considerations**: Performance requirements addressed in tasks

### Risk & Dependency Management
- [ ] **Risk Identification**: Technical risks and challenges clearly identified
- [ ] **Dependency Management**: Task dependencies properly mapped and sequenced
- [ ] **Effort Estimation**: Time estimates are realistic and account for complexity
- [ ] **Mitigation Strategies**: Risk mitigation approaches are defined

### Validation Criteria
- [ ] All user stories broken down into actionable tasks
- [ ] Tasks provide clear guidance for implementation
- [ ] Technical specifications enable efficient development
- [ ] Testing requirements ensure quality delivery
- [ ] Dependencies allow for parallel development where possible

### Next Phase Preparation
- [ ] **Ready for Task Execution**: Implementation tasks ready for development
- [ ] **Input Available**: Detailed tasks in `.docs/tasks/phase-{current}/`
- [ ] **Technical Clarity**: Implementation approach clearly defined
- [ ] **Development Ready**: Tasks provide sufficient detail for coding
