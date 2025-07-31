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

```json
{
  "project": {
    "name": "string",
    "version": "string",
    "description": "string",
    "created": "ISO8601",
    "lastUpdated": "ISO8601"
  },
  "architecture": {
    "style": "string (monolithic|microservices|serverless)",
    "components": [
      {
        "id": "string",
        "name": "string",
        "type": "string (frontend|backend|database|service)",
        "technology": "string",
        "dependencies": ["string"],
        "description": "string"
      }
    ],
    "integrations": [
      {
        "source": "string",
        "target": "string",
        "type": "string (REST|GraphQL|messaging|database)",
        "description": "string"
      }
    ]
  },
  "phases": [
    {
      "id": "string",
      "name": "string",
      "description": "string",
      "priority": "number",
      "estimatedDuration": "string",
      "dependencies": ["string"],
      "deliverables": ["string"],
      "modules": [
        {
          "id": "string",
          "name": "string",
          "description": "string",
          "requirements": ["REQ-ID"],
          "components": ["component-id"],
          "complexity": "string (low|medium|high)",
          "estimatedEffort": "string"
        }
      ]
    }
  ],
  "requirements": {
    "functional": [
      {
        "id": "string",
        "title": "string",
        "description": "string",
        "priority": "string",
        "phase": "string",
        "module": "string",
        "acceptanceCriteria": ["string"],
        "dependencies": ["string"]
      }
    ],
    "nonFunctional": [
      {
        "id": "string",
        "category": "string (performance|security|scalability|usability)",
        "title": "string",
        "description": "string",
        "metric": "string",
        "target": "string",
        "phases": ["string"]
      }
    ]
  },
  "technology": {
    "frontend": {
      "framework": "string",
      "language": "string",
      "buildTools": ["string"],
      "testing": ["string"]
    },
    "backend": {
      "framework": "string",
      "language": "string",
      "runtime": "string",
      "testing": ["string"]
    },
    "database": {
      "primary": "string",
      "caching": "string",
      "migrations": "string"
    },
    "infrastructure": {
      "hosting": "string",
      "cicd": "string",
      "monitoring": "string",
      "logging": "string"
    }
  },
  "timeline": {
    "totalEstimate": "string",
    "milestones": [
      {
        "name": "string",
        "phase": "string",
        "deliverables": ["string"],
        "estimatedDate": "ISO8601"
      }
    ]
  },
  "risks": [
    {
      "id": "string",
      "description": "string",
      "impact": "string (low|medium|high)",
      "probability": "string (low|medium|high)",
      "mitigation": "string",
      "phases": ["string"]
    }
  ]
}
```

## Quality Standards
- **Completeness**: All requirements mapped to phases/modules
- **Consistency**: Technology choices align across components
- **Feasibility**: Realistic timelines and effort estimates
- **Traceability**: Clear mapping from requirements to implementation

## Success Criteria
- JSON validates against schema
- All business requirements covered in phases
- Dependencies properly sequenced
- Technology stack coherent and justified
- Timeline realistic with buffer for risks
