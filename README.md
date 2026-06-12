# Code Agent SOP

A general-purpose, platform-agnostic collection of AI coding agent instructions that transform raw requirements into production code through a structured pipeline.

Works with any codebase — no specific CI/CD, issue tracker, or design tool required.

## Pipeline

```
Raw Requirements
  → @generate-plan   →  plan.md
  → @generate-task   →  task-001.md, task-002.md, ...
  → @execute-task    →  production code + tests
  → @fix-task        →  fix-{datetime}.md
```

Each stage produces artefacts in `.docs/<feature>/`. Nothing advances until prior stage is complete.

## Quick Start

1. Copy the `general/` folder into your project root (rename to `.github/` for Copilot or `.qwen/` for Qwen)
2. Invoke agents via `@<agent-name>` in your IDE's AI chat

No tokens or credentials required for the core pipeline. Optional integrations (Jira, Figma, GitLab) are available in the extended variant — see [Extended Variant](#extended-variant).

## Agents

| Agent | Purpose | Triggers |
|---|---|---|
| `generate-plan` | Raw requirements → structured `plan.md` with AC | plan, I need, create feature |
| `generate-task` | `plan.md` → vertical-slice `task-NNN.md` files | generate tasks, break down plan |
| `execute-task` | Implement `task-NNN.md` end-to-end (code + tests) | execute task, implement, code this |
| `fix-task` | Apply fixes from review comments / bugs / failing tests | fix, bug, review comment, regression |
| `investigate` | Root-cause analysis + evidence-based report | investigate, why is, root cause, debug |
| `snapshot-sync` | Create/update `SNAPSHOT.md` for repo orientation | snapshot, update snapshot |
| `spike-plan` | Technical spike document from `plan.md` uncertainties | spike, feasibility, de-risk |

## Instructions

| File | Scope |
|---|---|
| `instructions/guidelines.instructions.md` | Core principles — grounding, anti-hallucination, SOLID, quality gates |

Applied automatically to every interaction. Enforces concise communication, no hallucination, and code quality standards.

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

This format reduces token waste and makes agent instructions unambiguous for LLMs to parse.

## File Structure

```
general/
├── .github/
│   ├── agents/              # Agent instruction files (.agent.md)
│   ├── instructions/        # Always-on guidelines
│   └── copilot-instructions.md
└── .qwen/
    └── commands/qc/         # Same agents in Qwen format

.docs/                       # Created per-feature by agents
└── <feature>/
    ├── plan.md              # Requirements + AC
    ├── task-NNN.md          # Vertical slices
    └── fix-{dt}.md          # Fix logs
```

## Extended Variant

The root `.github/` and `.qwen/` folders contain an extended version with:

| Extra | Purpose |
|---|---|
| `git-review` | Review/summarise/act on GitHub PR or GitLab MR |
| `git-fix-review` | Fix open review threads, commit, push, poll pipeline |
| `fix-vulnerabilities` | Fetch + fix GitLab security vulnerabilities |
| `figma-design-context` skill | Fetch design context from Figma REST API |
| `jira-ticket` skill | Create/update Jira stories and sub-tasks |
| `git-workflow` skill | Branch → commit → push → MR → pipeline polling |
| `git-apis` skill | Shared GitLab + GitHub REST API primitives |

Requires tokens in `~/.zshenv` — see `.env.example` for the full list.

## Workflow Details

See [.docs-workflow-README.md](.docs-workflow-README.md) for the full pipeline documentation.
