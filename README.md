# Code Agent SOP

Pipeline for transforming raw requirements into production code — plan → tasks → implement → fix.

## Quick Start

| Requirement | Setup |
|---|---|
| VS Code + GitHub Copilot | [Extension](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot) |
| Jira | `JIRA_TOKEN`, `JIRA_EMAIL`, `JIRA_BASE_URL`, `JIRA_PROJECT_KEY` in `~/.zshenv` |
| Figma | `FIGMA_TOKEN` in `~/.zshenv` (only for Figma skill without MCP) |
| GitLab | `GITLAB_TOKEN` in `~/.zshenv` (for git-review, fix-vulnerabilities) |

```bash
cat .env.example >> ~/.zshenv  # fill real values, then: source ~/.zshenv
```

## Pipeline

```
Raw Requirements
  → @generate-plan   →  plan.md
  → @generate-task   →  task-001.md, task-002.md, ...
  → @execute-task    →  production code + tests
  → @fix-task        →  fix-{datetime}.md
```

Each stage produces artefacts in `.docs/<feature>/`. Nothing advances until prior stage is complete.

## Agents

Invoke with `@<agent-name>` in Copilot Chat.

| Agent | Purpose | Triggers |
|---|---|---|
| `generate-plan` | Raw requirements → structured `plan.md` with AC | plan, I need, create feature |
| `generate-task` | `plan.md` → vertical-slice `task-NNN.md` files | generate tasks, break down plan |
| `execute-task` | Implement `task-NNN.md` end-to-end (code + tests + git) | execute task, implement, code this |
| `fix-task` | Apply fixes from review comments / bugs / failing tests | fix, bug, review comment, regression |
| `investigate` | Root-cause analysis + evidence-based report | investigate, why is, root cause, debug |
| `git-review` | Review/summarise/act on GitHub PR or GitLab MR | review PR, review MR, code review |
| `git-fix-review` | Fix open review threads, commit, push, poll pipeline | fix review comments, address review |
| `snapshot-sync` | Create/update `SNAPSHOT.md` for repo orientation | snapshot, update snapshot |
| `spike-plan` | Technical spike document from `plan.md` uncertainties | spike, feasibility, de-risk |
| `fix-vulnerabilities` | Fetch + fix GitLab security vulnerabilities | fix vulnerabilities, CVE fix |

## Skills

Loaded on demand by agents or invoked directly.

| Skill | Purpose |
|---|---|
| `figma-design-context` | Fetch layout, typography, colours from Figma REST API |
| `jira-ticket` | Create stories, sub-tasks, update SP via Jira API |
| `git-workflow` | Branch → commit → push → MR → pipeline polling |
| `git-apis` | Shared GitLab + GitHub REST API primitives |
| `fix-vulnerabilities` | Fetch vulnerability findings from GitLab |

## Instructions

| File | Scope |
|---|---|
| [`guidelines.instructions.md`](.github/instructions/guidelines.instructions.md) | Core principles — grounding, anti-hallucination, SOLID, quality gates |

## Step Prefix Format

All agent files use a prefix-based step format for machine-readability:

| Prefix | Meaning |
|--------|---------|
| `DO:` | Execute action |
| `IF:` | Conditional branch (→ action) |
| `LOOP:` | Iterate over collection |
| `CALL:` | Invoke skill(params) → outputs |
| `EMIT:` | Output/write/report |
| `STORE:` | Save value for later |
| `STOP:` | Halt with reason |

## File Structure

```
.github/
├── agents/              # Agent instruction files (.agent.md)
├── instructions/        # Always-on Copilot instructions
└── skills/              # Reusable capability modules

.docs/
└── <feature>/           # Per-feature artefacts
    ├── plan.md          # Stage 1: requirements + AC
    ├── jira.json        # Jira story/sub-task keys
    ├── task-NNN.md      # Stage 2: vertical slices
    ├── fix-{dt}.md      # Stage 4: fix logs
    └── figma/           # Cached Figma assets
```

## Variants

| Folder | Purpose |
|---|---|
| `general/` | Platform-agnostic baseline (no git-review, fix-vulnerabilities, no skills) |
| `.qwen/` | Qwen-compatible format (same content, `.qwen/skills/` paths) |

## Workflow Details

See [.docs-workflow-README.md](.docs-workflow-README.md) for full pipeline documentation.
