---
mode: agent
---

# Implementation Plan Generator

Transform analyzed business requirements into a comprehensive, machine-readable implementation plan that serves as the single source of truth for development.

## Input Sources
- **Location**: `.docs/analysis/**`
- **Files**: All requirement analysis files (`*-requirements-v*.md`)
- **Dependencies**: Complete business requirements analysis

## Task Requirements

### Plan Generation Process
1. **Analyze Requirements Comprehensively**
   - Parse all functional/non-functional requirements
   - Identify system architecture needs
   - Map requirements to technical components

2. **Design Phase Structure**
   - Break down into logical development phases
   - Ensure dependencies are properly ordered
   - Balance scope across phases for iterative delivery

3. **Define Technical Architecture**
   - System components and their relationships
   - Technology stack recommendations
   - Integration patterns and data flows

## Output Structure
- **Location**: `.docs/overview-plan.json`
- **Format**: Structured JSON with complete development blueprint

````prompt
---
mode: agent
---

# Implementation Plan Generator

Transform requirements into machine-readable implementation plan.

## Input
- Location: `.docs/analysis/**`
- Files: `*-requirements-v*.md`

## Process
1. Parse functional/non-functional requirements
2. Design phase structure with dependencies
3. Define technical architecture

## Output
- Location: `.docs/overview-plan.json`
- Format: Structured JSON

### JSON Schema
```json
{
  # Implementation Plan Generator

  Goal: Convert analysis into a single machine‑readable plan.

  Inputs
  - `.docs/analysis/**` files `*-requirements-v*.md`

  Process
  1) Parse functional/non‑functional requirements.
  2) Design phases with ordered dependencies.
  3) Define technical architecture and integrations.

  Output
  - Path: `.docs/overview-plan.json`
  - Format: Structured JSON

  JSON Schema
  ```json
  {
    "project": {"name": "string", "version": "string", "description": "string"},
    "architecture": {
      "style": "monolithic|microservices|serverless",
      "components": [{"id": "string", "name": "string", "type": "frontend|backend|database|service", "technology": "string", "dependencies": ["string"]}],
      "integrations": [{"source": "string", "target": "string", "type": "REST|GraphQL|messaging|database"}]
    },
    "phases": [{
      "id": "string", "name": "string", "priority": "number", "estimatedDuration": "string", "dependencies": ["string"],
      "modules": [{"id": "string", "name": "string", "requirements": ["REQ-ID"], "components": ["component-id"], "complexity": "low|medium|high"}]
    }],
    "requirements": {
      "functional": [{"id": "string", "title": "string", "priority": "string", "phase": "string", "acceptanceCriteria": ["string"]}],
      "nonFunctional": [{"id": "string", "category": "performance|security|scalability|usability", "metric": "string", "target": "string"}]
    },
    "technology": {
      "frontend": {"framework": "string", "language": "string"},
      "backend": {"framework": "string", "language": "string"},
      "database": {"primary": "string", "caching": "string"},
      "infrastructure": {"hosting": "string", "cicd": "string"}
    },
    "risks": [{"description": "string", "impact": "low|medium|high", "mitigation": "string"}]
  }
  ```

  Quality
  - Complete, consistent, feasible, and traceable.

  Success
  - JSON validates; all requirements covered; deps sequenced; tech coherent.
  },
