# Kent's Copilot Agent SOP

A production-ready collection of VS Code Copilot agents, skills, and instructions for end-to-end software development workflows — from raw requirements to shipped code.

## Structure

```
.github/
├── agents/          # Custom Copilot agent modes
├── instructions/    # Always-on Copilot instructions
└── skills/          # Reusable capability modules
```

## Agents

Invoke with `@<agent-name>` in Copilot Chat.

| Agent | Purpose | Trigger phrases |
|---|---|---|
| [`generate-plan`](.github/agents/generate-plan.agent.md) | Turn raw requirements into a Jira-ready `plan.md` | *analyze, plan, I need, create feature* |
| [`refine-plan`](.github/agents/refine-plan.agent.md) | Answer open questions and lock a plan for implementation | *refine plan, answer questions, plan is ready* |
| [`generate-execute-plan`](.github/agents/generate-execute-plan.agent.md) | Break a ready `plan.md` into vertical-slice execute plans | *generate tasks, break down plan, ready to implement* |
| [`execute-plan`](.github/agents/execute-plan.agent.md) | Implement an `execute-plan-NNN.md` end-to-end | *implement, code this, run slice, do the work* |
| [`refine-execute-plan`](.github/agents/refine-execute-plan.agent.md) | Apply corrections or additions to an execute plan | *update execute plan, fix task, adjust slice* |
| [`gitlab-mr`](.github/agents/gitlab-mr.agent.md) | Review, summarise, or fix comments on a GitLab MR | *review MR, fix comment, show diff* |
| [`snapshot-sync`](.github/agents/snapshot-sync.agent.md) | Create or update `SNAPSHOT.md` for any repo | *snapshot, update snapshot, missing snapshot* |

## Skills

Skills are loaded on demand by agents or directly via `@agent` when the domain applies.

| Skill | Purpose |
|---|---|
| [`figma-design-context`](.github/skills/figma-design-context/SKILL.md) | Fetch Figma layout, spacing, typography, and screenshots via REST API (no MCP needed) |
| [`jira-ticket`](.github/skills/jira-ticket/SKILL.md) | Create stories, sub-tasks, and update story points via Jira REST API |

## Instructions

Automatically applied to every Copilot interaction.

| File | Scope |
|---|---|
| [`guidelines.instructions.md`](.github/instructions/guidelines.instructions.md) | Core engineering principles — grounding, anti-hallucination, SOLID, quality gates |
| [`jira.instructions.md`](.github/instructions/jira.instructions.md) | Jira instance config, project key, auth env vars, script paths |

## Workflow

See [`.docs-workflow-README.md`](.docs-workflow-README.md) for the full requirements-to-code pipeline.

```
Raw requirement
  → @generate-plan       (plan.md + Jira story)
  → @refine-plan         (resolve open questions)
  → @generate-execute-plan  (execute-plan-NNN.md per slice)
  → @execute-plan           (production code + tests)
```

## Prerequisites

- VS Code with GitHub Copilot
- `JIRA_TOKEN`, `JIRA_EMAIL`, `JIRA_BASE_URL`, `JIRA_PROJECT_KEY` in `~/.zshenv`
- `FIGMA_TOKEN` in `~/.zshenv` (if using Figma skill without MCP)
