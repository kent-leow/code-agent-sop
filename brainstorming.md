# AI Code Agent Development Phases Template

> A systematic, step-by-step approach for AI code agents to develop applications with human verification at each stage, integrated with structured prompts for automated execution.

## Core Principles
- **Incremental Development**: Each phase builds upon the previous
- **Human Validation**: Every phase ends with testable deliverables
- **Stack-Aware**: Follows framework-specific best practices
- **Atomic Design**: Small, focused changes that can be verified
- **Prompt-Driven**: Each phase executes specific prompts for consistent results

## Prompt Integration Flow
```
Phase 0 → a-requirements-analysis.prompt.md
Phase 1 → b-implementation-plan.prompt.md + CI/CD Setup
Phase 2 → c-user-stories.prompt.md + Architecture
Phase 3-N → d-implementation-tasks.prompt.md + e-task-execution.prompt.md (per feature)
Phase N+1 → Integration validation + testing
Phase N+2 → Polish + optimization
Phase N+3 → Production deployment
```

---

## Phase 0: Project Planning & Requirements Analysis
**Objective**: Establish clear project scope and technical requirements
**Prompt**: `a-requirements-analysis.prompt.md`

### Input Setup
- Create `.docs/requirements/` directory
- Gather all requirement documents, transcripts, interviews
- Place files matching types: `transcript`, `document`, `interview`

### Tasks
- Execute **a-requirements-analysis.prompt.md** to:
  - Analyze project requirements and user stories
  - Identify target users and use cases
  - Define technical constraints and non-functional requirements
  - Classify requirements (functional|non_functional|business_rule|data|integration)
  - Extract metadata: actors, triggers, outputs, constraints
  - Identify gaps and suggest questions
  - Assign priorities: critical|high|medium|low

### Prompt Execution
```bash
# Input: .docs/requirements/**
# Process: requirements-analysis prompt
# Output: .docs/analysis/{domain}-requirements-v{version}.md
```

### Human Verification Checkpoint
- **Deliverable**: Requirements analysis files in `.docs/analysis/`
- **Test**: Review generated requirement classifications and priorities
- **Success Criteria**: 
  - Clear understanding of functional and non-functional requirements
  - All requirement gaps identified with suggested questions
  - Requirements properly categorized and prioritized

---

## Phase 1: Foundation & Implementation Planning + Deployment Pipeline Setup
**Objective**: Create implementation plan and working development environment with full deployment capabilities
**Prompt**: `b-implementation-plan.prompt.md`

### Input Setup
- Requirements analysis files from Phase 0: `.docs/analysis/**`
- All requirement files: `*-requirements-v*.md`

### Tasks
#### Part A: Implementation Planning
- Execute **b-implementation-plan.prompt.md** to:
  - Parse functional/non-functional requirements
  - Design phase structure with dependencies
  - Define technical architecture (monolith|microservices|serverless)
  - Map requirements to technical components
  - Sequence phases topologically by dependencies and risk
  - Estimate phase effort

#### Part B: Infrastructure Setup
- Initialize project structure following stack conventions from plan
- Setup package.json/dependencies based on chosen stack
- Configure development tools (prettier, eslint, testing framework)
- Create basic folder structure following atomic design principles
- **Setup complete CI/CD pipeline with multiple environments**
- **Configure environment variables for all stages (.env.local, .env.development, .env.staging, .env.production)**
- **Setup deployment to DEV, QA/SIT, UAT, and PROD environments**
- **Configure automated testing in CI pipeline**
- **Setup environment-specific configurations and secrets**
- Create minimal "Hello World" entry point
- Setup development server and build processes
- **Configure domain/subdomain routing for each environment**
- **Setup monitoring and health checks for all environments**

### Prompt Execution
```bash
# Input: .docs/analysis/**
# Process: implementation-plan prompt
# Output: .docs/overview-plan.json
```

### Environment Setup Details
```
Environments to configure:
- DEV: localhost development
- QA/SIT: qa.yourapp.com or yourapp-qa.vercel.app
- UAT: uat.yourapp.com or yourapp-uat.vercel.app  
- PROD: yourapp.com or yourapp.vercel.app
```

### CI/CD Pipeline Requirements
- Automated testing on every commit
- Automatic deployment to QA/SIT on main branch
- Manual approval for UAT deployment
- Manual approval for PROD deployment
- Rollback capabilities for all environments
- Environment health monitoring

### Human Verification Checkpoint
- **Deliverable**: 
  - Implementation plan: `.docs/overview-plan.json`
  - Working development environment + Full deployment pipeline
- **Test**: 
  - Review implementation plan structure and technical decisions
  - `npm start` / `npm run dev` shows a basic page locally
  - **QA/SIT environment accessible via URL**
  - **CI/CD pipeline executes successfully**
  - **Can deploy to UAT with approval**
- **Success Criteria**: 
  - Implementation plan covers all requirements with clear phases
  - Development server runs without errors
  - Tests execute successfully in CI pipeline
  - Build process works for all environments
  - Linting and formatting rules are enforced
  - **All environments (QA/SIT/UAT/PROD) are accessible and deployable**
  - **Environment variables are properly configured for each stage**

---

## Phase 2: User Stories & Core Architecture + Routing
**Objective**: Generate user stories and establish application's navigation structure
**Prompt**: `c-user-stories.prompt.md`

### Input Setup
- Implementation plan: `.docs/overview-plan.json`
- Requirements files: `.docs/requirements/**`

### Tasks
#### Part A: User Stories Generation
- Execute **c-user-stories.prompt.md** to:
  - Extract modules and requirements from implementation plan
  - Synthesize story sentences (role, action, value)
  - Derive acceptance criteria in GIVEN/WHEN/THEN format
  - Add non-functional acceptance criteria from NFRs
  - Assign priority and estimates to stories
  - Ensure traceability to source requirement IDs

#### Part B: Core Architecture Implementation
- Implement routing system (React Router, Next.js routing, etc.)
- Create layout components (header, footer, navigation)
- Setup error boundaries and 404 pages
- Implement basic state management structure
- Create utility functions and helper modules
- Setup API integration patterns (if applicable)
- Add basic styling system and design tokens
- **Update environment-specific configurations as needed**

### Prompt Execution
```bash
# Input: .docs/overview-plan.json + .docs/requirements/**
# Process: user-stories-generator prompt
# Output: .docs/user-stories/phase-{phase-id}/us-{phase}.{story}-{title}.md
```

### Human Verification Checkpoint
- **Deliverable**: 
  - User stories: `.docs/user-stories/phase-{phase-id}/`
  - Navigable application skeleton
- **Test**: 
  - Review user stories for completeness and clarity
  - Navigate between different routes/pages locally
  - **Verify routing works in QA/SIT environment**
  - **Test environment-specific configurations**
- **Success Criteria**:
  - All user stories have clear acceptance criteria
  - Stories trace back to original requirements
  - All planned routes are accessible
  - Navigation works correctly in all environments
  - Error handling displays appropriate messages
  - Basic styling is consistent
  - **QA/SIT environment reflects latest changes automatically**

---

## Phase 3-N: Feature Development Cycles
**Objective**: Implement core features one at a time with full functionality
**Prompts**: `d-implementation-tasks.prompt.md` + `e-task-execution.prompt.md`

> **Note**: Repeat this phase for each major feature/page. Each iteration should be a complete, testable feature.

### Input Setup (Per Feature)
- User stories for current phase: `.docs/user-stories/phase-{current}/`
- Implementation plan: `.docs/overview-plan.json`
- Current codebase: `.`

### Tasks (Per Feature)
#### Part A: Task Generation
- Execute **d-implementation-tasks.prompt.md** to:
  - Load user stories for current phase
  - Parse GIVEN/WHEN/THEN acceptance criteria
  - Decompose into dev, test, infra subtasks
  - Determine file targets following stack-aware rules
  - Define tech specs: APIs, DB schema, DTOs, types, config changes
  - Estimate effort and risks
  - Link tasks back to user stories

#### Part B: Task Execution
- Execute **e-task-execution.prompt.md** to:
  - Read task metadata and file targets
  - Prepare workspace (branch, dependencies)
  - Create or modify files (implement code, types, tests)
  - Run linters and formatters
  - Execute unit and integration tests
  - Validate acceptance criteria
  - Package and report changes
  - Create PR metadata if required

#### Part C: Manual Integration
- Design and implement UI components following atomic design
- Add form validation and error handling
- Implement feature-specific routing and navigation
- Add loading states and user feedback
- Ensure responsive design and accessibility
- **Update environment variables if feature requires new configurations**

### Prompt Execution
```bash
# Step 1: Generate tasks
# Input: .docs/user-stories/phase-{current}/ + .docs/overview-plan.json
# Process: implementation-tasks-generator prompt
# Output: .docs/tasks/phase-{phase}/us-{phase}.{story}/task-{phase}.{story}.{task}-{name}.md

# Step 2: Execute tasks
# Input: .docs/tasks/phase-{current}/ + codebase
# Process: task-execution-engine prompt
# Output: Code changes + status files + validation results
```

### Human Verification Checkpoint
- **Deliverable**: 
  - Implementation tasks: `.docs/tasks/phase-{phase}/`
  - Task execution status and validation results
  - Fully functional feature
- **Test**: 
  - Review generated tasks for completeness
  - Verify task execution results and test coverage
  - Complete user workflow for the feature locally
  - **Feature works correctly in QA/SIT environment**
  - **Stakeholder review possible in UAT environment (optional)**
- **Success Criteria**:
  - All acceptance criteria validated successfully
  - Feature works end-to-end as specified
  - All user interactions provide appropriate feedback
  - Error cases are handled gracefully
  - Tests pass for the new functionality in CI pipeline
  - Feature integrates properly with existing code
  - **Feature is demonstrable in live environments for stakeholder feedback**

---

## Phase N+1: Integration & Data Flow
**Objective**: Connect all features and ensure proper data flow between components

### Tasks
- Implement cross-feature data sharing
- Add authentication and authorization (if required)
- Setup global state management
- Implement data persistence (local storage, database)
- Add search and filtering capabilities
- Implement bulk operations and data management
- Optimize API calls and data fetching
- **Configure production-ready environment variables and secrets**

### Human Verification Checkpoint
- **Deliverable**: Integrated application with all features working together
- **Test**: 
  - Complete user journeys spanning multiple features locally
  - **End-to-end testing in QA/SIT environment**
  - **User acceptance testing in UAT environment**
- **Success Criteria**:
  - Data flows correctly between features
  - User sessions are managed properly
  - Performance is acceptable across all environments
  - No data inconsistencies
  - **UAT environment ready for comprehensive user testing**

---

## Phase N+2: Polish & Optimization
**Objective**: Enhance user experience and application performance

### Tasks
- Implement advanced UI patterns (drag & drop, animations)
- Add comprehensive error handling and user feedback
- Optimize performance (code splitting, lazy loading)
- Implement analytics and monitoring
- Add advanced accessibility features
- Create comprehensive documentation
- Implement SEO optimizations (if applicable)
- **Finalize production configurations and security measures**

### Human Verification Checkpoint
- **Deliverable**: Production-ready application
- **Test**: 
  - Comprehensive user testing and performance evaluation locally
  - **Performance testing in QA/SIT environment**
  - **Final user acceptance testing in UAT environment**
  - **Production readiness assessment**
- **Success Criteria**:
  - Application feels polished and professional
  - Performance meets requirements across all environments
  - User experience is intuitive and accessible
  - **Ready for production deployment with confidence**

---

## Phase N+3: Production Deployment & Monitoring
**Objective**: Deploy to production and establish comprehensive monitoring

### Tasks
- **Execute production deployment using established pipeline**
- **Verify all production environment configurations**
- Configure comprehensive monitoring and logging
- Setup error tracking and alerting
- Implement backup and disaster recovery procedures
- **Validate production SSL certificates and security measures**
- Create operational runbooks and deployment documentation
- **Setup production health checks and uptime monitoring**

### Human Verification Checkpoint
- **Deliverable**: Live, monitored production application
- **Test**: 
  - **Application runs correctly in production environment**
  - **All production features work as expected**
  - **Monitoring and alerting systems are functional**
- **Success Criteria**:
  - Application is accessible via production URL
  - Monitoring and logging are working correctly
  - Security measures are properly implemented
  - Deployment process is documented and repeatable
  - **Production environment is stable and performant**

---

## Deployment Strategy & Environment Management

### Environment Progression Flow
```
Development (Local) → QA/SIT → UAT → Production
     ↓                 ↓       ↓       ↓
Auto-deploy         Auto      Manual   Manual
on commit          deploy    approval approval
```

### File Structure for Prompt Integration
```
.docs/
├── requirements/           # Phase 0 input
│   ├── transcripts/
│   ├── documents/
│   └── interviews/
├── analysis/              # Phase 0 output
│   └── {domain}-requirements-v{version}.md
├── overview-plan.json     # Phase 1 output
├── user-stories/          # Phase 2 output
│   └── phase-{id}/
│       └── us-{phase}.{story}-{title}.md
└── tasks/                 # Phase 3-N output
    └── phase-{phase}/
        └── us-{phase}.{story}/
            ├── task-{phase}.{story}.{task}-{name}.md
            └── status.yaml
```

### Environment-Specific Configurations

#### Development (.env.local)
```bash
NODE_ENV=development
API_URL=http://localhost:3001
DATABASE_URL=postgresql://localhost:5432/myapp_dev
REDIS_URL=redis://localhost:6379
DEBUG=true
```

#### QA/SIT (.env.staging)
```bash
NODE_ENV=staging
API_URL=https://api-qa.yourapp.com
DATABASE_URL=postgresql://qa-db.yourapp.com:5432/myapp_qa
REDIS_URL=redis://qa-redis.yourapp.com:6379
DEBUG=false
```

#### UAT (.env.uat)
```bash
NODE_ENV=uat
API_URL=https://api-uat.yourapp.com
DATABASE_URL=postgresql://uat-db.yourapp.com:5432/myapp_uat
REDIS_URL=redis://uat-redis.yourapp.com:6379
DEBUG=false
```

#### Production (.env.production)
```bash
NODE_ENV=production
API_URL=https://api.yourapp.com
DATABASE_URL=postgresql://prod-db.yourapp.com:5432/myapp_prod
REDIS_URL=redis://prod-redis.yourapp.com:6379
DEBUG=false
MONITORING_KEY=xxxxx
ERROR_TRACKING_DSN=xxxxx
```

### CI/CD Pipeline Configuration

#### GitHub Actions Example
```yaml
name: Deploy to Environments

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Tests
        run: npm test

  deploy-qa:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to QA/SIT
        run: npm run deploy:qa

  deploy-uat:
    needs: deploy-qa
    if: github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to UAT
        run: npm run deploy:uat

  deploy-prod:
    needs: deploy-uat
    if: github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Production
        run: npm run deploy:prod
```

### Deployment Commands
```json
{
  "scripts": {
    "deploy:qa": "vercel --prod --token $VERCEL_TOKEN",
    "deploy:uat": "vercel --prod --token $VERCEL_TOKEN --scope uat",
    "deploy:prod": "vercel --prod --token $VERCEL_TOKEN --scope production"
  }
}
```

---

## Master Workflow: Prompt Execution Guide

### Phase-by-Phase Prompt Execution

#### Phase 0: Requirements Analysis
```bash
# 1. Setup input directory
mkdir -p .docs/requirements/{transcripts,documents,interviews}

# 2. Place requirement files in appropriate subdirectories

# 3. Execute requirements analysis prompt
# Input: .docs/requirements/**
# Prompt: a-requirements-analysis.prompt.md
# Output: .docs/analysis/{domain}-requirements-v{version}.md

# 4. Human review of generated requirements analysis
```

#### Phase 1: Implementation Planning + Infrastructure
```bash
# 1. Execute implementation plan prompt
# Input: .docs/analysis/**
# Prompt: b-implementation-plan.prompt.md
# Output: .docs/overview-plan.json

# 2. Review implementation plan
# 3. Setup CI/CD pipeline based on plan recommendations
# 4. Initialize project structure following plan
# 5. Deploy initial "Hello World" to all environments
```

#### Phase 2: User Stories + Architecture
```bash
# 1. Execute user stories prompt
# Input: .docs/overview-plan.json + .docs/requirements/**
# Prompt: c-user-stories.prompt.md
# Output: .docs/user-stories/phase-{id}/

# 2. Review generated user stories
# 3. Implement routing and core architecture
# 4. Deploy to QA/SIT for testing
```

#### Phase 3-N: Feature Development (Repeat per feature)
```bash
# 1. Execute implementation tasks prompt
# Input: .docs/user-stories/phase-{current}/ + .docs/overview-plan.json
# Prompt: d-implementation-tasks.prompt.md
# Output: .docs/tasks/phase-{phase}/us-{phase}.{story}/

# 2. Execute task execution prompt
# Input: .docs/tasks/phase-{current}/ + codebase
# Prompt: e-task-execution.prompt.md
# Output: Code changes + validation results

# 3. Human review and manual integration
# 4. Deploy feature to QA/SIT
# 5. Optional UAT deployment for stakeholder review
```

### Prompt Chain Dependencies
```
a-requirements-analysis → b-implementation-plan → c-user-stories → d-implementation-tasks → e-task-execution
        ↓                        ↓                      ↓                    ↓                    ↓
  .docs/analysis/       .docs/overview-plan.json  .docs/user-stories/  .docs/tasks/        Code changes
```

---

## Quality Gates for Each Phase

### Before Phase Completion
1. **Code Quality**: All linting and formatting rules pass
2. **Testing**: All tests pass with adequate coverage in CI pipeline
3. **Documentation**: README and relevant docs are updated
4. **Error Handling**: No unhandled exceptions or errors
5. **Performance**: No obvious performance issues
6. **Deployment**: Changes successfully deployed to QA/SIT environment
7. **Environment Validation**: All environment-specific configurations work correctly
8. **Prompt Artifacts**: All expected prompt outputs are generated and validated

### Human Testing Checklist
- [ ] All intended functionality works as expected locally
- [ ] **QA/SIT environment reflects latest changes**
- [ ] **UAT environment ready for stakeholder testing (when applicable)**
- [ ] Error cases display appropriate messages
- [ ] UI is responsive and accessible
- [ ] Performance is acceptable across environments
- [ ] Integration with existing features works correctly
- [ ] **Environment-specific configurations are properly set**
- [ ] **Prompt-generated artifacts match expected outcomes**

---

## Success Metrics

### Technical Metrics
- Test coverage > 80%
- Build time < 2 minutes
- Page load time < 3 seconds
- Zero critical security vulnerabilities

### User Experience Metrics
- Intuitive navigation
- Clear error messages
- Responsive design across devices
- Accessible to users with disabilities

---

## Templates for Each Phase

### Phase Completion Report Template
```markdown
## Phase [X] Completion Report

### Prompt Execution Results
- [ ] **Prompt Used**: [a-requirements-analysis|b-implementation-plan|c-user-stories|d-implementation-tasks|e-task-execution]
- [ ] **Input Files**: [List input files/directories used]
- [ ] **Output Generated**: [List generated artifacts]
- [ ] **Validation Status**: [Pass/Fail with details]

### Completed Tasks
- [ ] Task 1
- [ ] Task 2  
- [ ] Task 3

### Deliverables
- **Primary**: [Main deliverable]
- **Supporting**: [Documentation, tests, etc.]
- **Prompt Artifacts**: [Generated requirements/plans/stories/tasks]

### Testing Results
- [ ] Manual testing completed
- [ ] All automated tests pass
- [ ] Performance criteria met
- [ ] **Environment testing completed (QA/SIT/UAT as applicable)**

### Known Issues
- [List any issues that need addressing in future phases]

### Next Phase Preparation
- [Any setup needed for the next phase]
- [Next prompt to execute with required inputs]
```

### Human Verification Checklist Template
```markdown
## Human Verification for Phase [X]

### Prompt Artifact Review
- [ ] **Generated artifacts are accurate and complete**
- [ ] **Requirements properly classified and prioritized** (Phase 0)
- [ ] **Implementation plan aligns with requirements** (Phase 1)
- [ ] **User stories have clear acceptance criteria** (Phase 2)
- [ ] **Tasks are well-defined with proper file targets** (Phase 3-N)
- [ ] **Code generation meets acceptance criteria** (Phase 3-N)

### Functional Testing
- [ ] Core functionality works as specified
- [ ] Edge cases are handled properly
- [ ] Error states display appropriate messages

### Technical Validation
- [ ] Code follows established patterns
- [ ] Tests are comprehensive and passing in CI
- [ ] Documentation is updated
- [ ] **All environments are properly configured**
- [ ] **Deployment pipeline executes successfully**
- [ ] **Prompt execution completed with expected outputs**
- [ ] **Generated artifacts (requirements, plans, stories, tasks) are accurate**

### User Experience
- [ ] Interface is intuitive and responsive
- [ ] Loading states provide feedback
- [ ] Accessibility requirements are met

### Environment Validation
- [ ] **Local development environment working**
- [ ] **QA/SIT environment reflects changes**
- [ ] **UAT environment ready for stakeholder review (when applicable)**

### Approval
- [ ] Ready to proceed to next phase
- [ ] Issues identified for future phases
- [ ] **Next prompt identified with required inputs**
```

### Prompt Execution Checklist Template
```markdown
## Prompt Execution Checklist for Phase [X]

### Pre-Execution Setup
- [ ] **Input directory/files prepared**: [list required inputs]
- [ ] **Prerequisites met**: [previous phase outputs available]
- [ ] **Environment configured**: [development environment ready]

### Prompt Execution
- [ ] **Prompt file**: [a-requirements-analysis|b-implementation-plan|c-user-stories|d-implementation-tasks|e-task-execution].prompt.md
- [ ] **Input paths verified**: [confirm input files exist and are formatted correctly]
- [ ] **Execution completed successfully**: [no errors during prompt processing]

### Post-Execution Validation
- [ ] **Output files generated**: [list expected output files/directories]
- [ ] **Output format validation**: [JSON schema validation, markdown structure, etc.]
- [ ] **Content review**: [human review of generated content for accuracy]
- [ ] **Integration check**: [outputs properly integrate with existing artifacts]

### Next Steps
- [ ] **Manual implementation tasks identified**: [list tasks not covered by prompts]
- [ ] **Environment deployment planned**: [QA/SIT deployment strategy]
- [ ] **Stakeholder review scheduled**: [UAT review if applicable]
```


