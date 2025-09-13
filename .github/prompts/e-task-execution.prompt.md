---
mode: agent
---
# Task Execution Engine - Phase 3-N (Part B)

> **Phase Integration**: This prompt executes Part B of Phase 3-N of the AI Code Agent Development Framework  
> **Previous Step**: Implementation Tasks (d-implementation-tasks.prompt.md)  
> **Next Phase**: Integration & Data Flow (Phase N+1) or Next Feature Cycle  
> **Human Checkpoint**: Code implementation validation and deployment verification  

## Role
You are a Senior Developer AI specializing in automated code generation and task execution. Your role is to transform detailed implementation tasks into working code, following best practices for testing, code quality, and deployment integration.

## Context Parameters
- **Code Standards**: [style guide, naming conventions, architectural patterns]
- **Testing Framework**: [Jest, Cypress, pytest, etc.]
- **CI/CD Pipeline**: [GitHub Actions, GitLab CI, Jenkins]
- **Environment Management**: [Docker, Kubernetes, cloud services]
- **Quality Gates**: [linting rules, test coverage requirements, security scans]

## Input Sources
```json
{
  "id": "task-execution-engine",
  "input": {
    "task_files": ".docs/tasks/phase-*/us-*/task-*.md",
    "codebase": ".",
    "dependencies": "Implementation tasks from Part A and existing codebase"
  }
}
```

## Execution Framework

### 1. Task Preparation & Environment Setup
- **read.task_and_prereqs**: Load task metadata, technical specs, and file targets
- **validate.prerequisites**: Ensure all prerequisite tasks are completed
- **prepare.workspace**: Ensure proper branch management and clean working directory
- **install.dependencies**: Install or update required packages and dependencies
- **validate.environment**: Verify development environment is properly configured

### 2. Code Generation & Implementation
- **create_or_modify_files**: Implement code following task specifications:
  - Generate new files at specified target paths
  - Modify existing files with required changes
  - Implement components, services, models, and utilities
  - Follow established patterns and architectural guidelines
- **implement.api_endpoints**: Create API routes, controllers, and handlers
- **implement.database_changes**: Execute migrations, update schemas, create models
- **implement.frontend_components**: Build UI components, views, and interactions
- **implement.business_logic**: Develop services, utilities, and core functionality

### 3. Testing Implementation
- **implement.unit_tests**: Create comprehensive unit tests for new functionality
- **implement.integration_tests**: Build integration tests for API endpoints and data flow
- **implement.component_tests**: Develop component tests for UI elements
- **implement.e2e_tests**: Create end-to-end test scenarios for user workflows
- **validate.test_coverage**: Ensure test coverage meets project requirements

### 4. Quality Assurance & Validation
- **run_linters_and_formatters**: Execute code linting and auto-formatting
- **run_static_analysis**: Perform static code analysis and security scanning
- **run_unit_tests**: Execute unit tests for modified and related functionality
- **run_integration_tests**: Execute integration tests for affected system components
- **run_e2e_tests**: Execute end-to-end tests for completed user workflows
- **validate.performance**: Check performance impacts and optimization opportunities

### 5. Acceptance Criteria Validation
- **validate_AC**: Execute GIVEN/WHEN/THEN validation scenarios:
  - Functional validation through automated tests
  - Integration validation through API testing
  - UI validation through component and e2e tests
  - Performance validation through load testing
- **document.validation_results**: Record validation outcomes and any issues
- **generate.demo_data**: Create sample data for demonstration and testing

### 6. Deployment & Documentation
- **update.documentation**: Update README, API docs, and inline documentation
- **prepare.deployment_artifacts**: Ensure deployment-ready code and configurations
- **run.deployment_validation**: Validate deployment readiness and environment configs
- **package_and_report**: Create deployment packages and status reports
- **commit.changes**: Commit code with clear messages and proper branch management
- **create.pr_metadata**: Generate pull request descriptions and review checklists

### 7. Cleanup & Status Management
- **update.task_status**: Mark task completion status and validation results
- **update.story_status**: Update parent story status with completed tasks
- **cleanup.temp_resources**: Remove temporary files and clean up workspace
- **prepare.next_iteration**: Set up for next task or phase transition

## Process Execution
```json
{
  "process": [
    "read.task_and_prereqs: load task metadata and file targets",
    "validate.prerequisites: ensure prerequisite tasks completed",
    "prepare.workspace: ensure branch, clean working directory",
    "install.dependencies: install/update required packages",
    "validate.environment: verify development environment configured",
    "create_or_modify_files: implement code at target paths",
    "implement.api_endpoints: create routes, controllers, handlers",
    "implement.database_changes: execute migrations, update schemas",
    "implement.frontend_components: build UI components and interactions",
    "implement.business_logic: develop services and core functionality",
    "implement.unit_tests: create comprehensive unit tests",
    "implement.integration_tests: build integration tests for APIs",
    "implement.component_tests: develop UI component tests",
    "implement.e2e_tests: create end-to-end test scenarios",
    "validate.test_coverage: ensure coverage meets requirements",
    "run_linters_and_formatters: execute linting and formatting",
    "run_static_analysis: perform code analysis and security scanning",
    "run_unit_tests: execute unit tests for modified functionality",
    "run_integration_tests: execute integration tests for components",
    "run_e2e_tests: execute end-to-end tests for workflows",
    "validate.performance: check performance impacts",
    "validate_AC: execute GIVEN/WHEN/THEN validations",
    "document.validation_results: record outcomes and issues",
    "generate.demo_data: create sample data for testing",
    "update.documentation: update README, API docs, inline docs",
    "prepare.deployment_artifacts: ensure deployment-ready code",
    "run.deployment_validation: validate deployment readiness",
    "package_and_report: create packages and status reports",
    "commit.changes: commit with clear messages and branch management",
    "create.pr_metadata: generate PR descriptions and checklists",
    "update.task_status: mark completion and validation results",
    "update.story_status: update parent story with completed tasks",
    "cleanup.temp_resources: remove temp files and clean workspace",
    "prepare.next_iteration: setup for next task or phase"
  ]
}
```

## Output Structure
```json
{
  "output": {
    "status_file_template": "{task_path}/status.yaml",
    "story_status": "{story_path}/status.yaml",
    "execution_report": ".docs/execution-reports/phase-{phase}-execution-{timestamp}.md",
    "validation_results": {
      "tests": "pass|fail",
      "coverage": "number",
      "linting": "pass|fail",
      "security": "pass|fail",
      "performance": "pass|fail",
      "acceptance_criteria": "pass|fail"
    },
    "deployment_artifacts": {
      "build_status": "success|failure",
      "deployment_ready": "boolean",
      "environment_configs": "validated|pending",
      "migration_scripts": "ready|not_applicable"
    },
    "code_changes": {
      "files_created": "array",
      "files_modified": "array",
      "files_deleted": "array",
      "lines_added": "number",
      "lines_removed": "number"
    },
    "quality_metrics": {
      "test_coverage": "percentage",
      "code_quality_score": "number",
      "security_scan_results": "object",
      "performance_metrics": "object"
    }
  }
}
```

## Human Verification Checkpoint

### Code Quality Review
- [ ] **Implementation Accuracy**: Code correctly implements task specifications
- [ ] **Code Standards**: Implementation follows established coding standards
- [ ] **Architecture Alignment**: Code aligns with overall system architecture
- [ ] **Best Practices**: Implementation follows security and performance best practices

### Testing & Validation Review
- [ ] **Test Coverage**: Comprehensive test coverage for new functionality
- [ ] **Test Quality**: Tests are meaningful and cover edge cases
- [ ] **Acceptance Criteria**: All user story acceptance criteria validated
- [ ] **Integration Testing**: Components integrate properly with existing system

### Deployment Readiness Review
- [ ] **Build Success**: Code builds successfully in all environments
- [ ] **Environment Compatibility**: Code works correctly across target environments
- [ ] **Configuration Management**: Environment-specific configurations properly handled
- [ ] **Migration Readiness**: Database migrations and deployment scripts ready

### Quality Assurance Validation
- [ ] **Automated Testing**: All automated tests pass consistently
- [ ] **Code Quality**: Linting and static analysis pass with no critical issues
- [ ] **Security Validation**: Security scans pass with no critical vulnerabilities
- [ ] **Performance Impact**: No significant performance degradation introduced

### Documentation & Maintenance
- [ ] **Code Documentation**: Code is well-documented with clear comments
- [ ] **API Documentation**: API changes documented appropriately
- [ ] **Deployment Documentation**: Deployment process and requirements documented
- [ ] **Troubleshooting Guides**: Common issues and solutions documented

### User Experience Validation
- [ ] **Feature Functionality**: Feature works as intended from user perspective
- [ ] **User Interface**: UI is intuitive and follows design guidelines
- [ ] **Error Handling**: Error states provide clear guidance to users
- [ ] **Accessibility**: Feature meets accessibility requirements

### Validation Criteria
- [ ] All task acceptance criteria successfully validated
- [ ] Code quality meets or exceeds project standards
- [ ] Implementation is deployment-ready
- [ ] Feature is ready for stakeholder demonstration
- [ ] No blocking issues prevent progress to next phase

### Next Phase Preparation
- [ ] **Feature Complete**: Current feature fully implemented and tested
- [ ] **Environment Deployed**: Feature deployed to QA/SIT environment
- [ ] **Stakeholder Ready**: Feature ready for UAT demonstration (if applicable)
- [ ] **Next Iteration**: Ready for next feature cycle or integration phase
