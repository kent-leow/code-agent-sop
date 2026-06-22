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

## Versions

| Version | Folder | Use Case |
|---|---|---|
| **root** | `.github/`, `.claude/` | Extended variant with integrations (GitLab, GitHub, Jira, Figma) |
| **general** | `general/` | Integration-free, for any codebase |
| **monorepo** | `monorepo/` | For workspaces with monorepo as sibling (reads monorepo context) |

### Quick Start

**General version** (most repos):
```
cp -r general/.github your-repo/.github
cp -r general/.claude your-repo/.claude  # optional, for Claude Code
```

**Monorepo workspace version** (when monorepo is a sibling folder):
```
# In a workspace like:
# workspace/
# ├── monorepo/
# └── other-project/

# Copy to workspace root:
cp -r monorepo/.github workspace/.github
cp -r monorepo/.claude workspace/.claude

# The agent will read monorepo/AGENTS.md and monorepo/skills/ automatically
```

**Extended version** (with integrations):
```
cp -r .github your-repo/.github
cp -r .claude your-repo/.claude
# Requires tokens in ~/.zshenv — see .env.example
```

Invoke agents via `@<agent-name>` in your IDE's AI chat.

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
.github/                     # Extended variant (root)
├── agents/                  # All agents including integrations
├── instructions/            # Always-on guidelines
├── skills/                  # Git, Jira, Figma skills
└── copilot-instructions.md

.claude/                     # Claude Code integration (root)
├── commands/                # Agents as Claude commands
└── CLAUDE.md

general/                     # Integration-free variant
├── .github/
│   ├── agents/              # Core agents only
│   └── instructions/
└── .claude/
    └── commands/

monorepo/                    # Monorepo workspace variant
├── .github/
│   ├── agents/              # Core agents only
│   └── instructions/        # Includes monorepo context section
└── .claude/
    └── commands/

.docs/                       # Created per-feature by agents
└── <feature>/
    ├── plan.md              # Requirements + AC
    ├── task-NNN.md          # Vertical slices
    └── fix-{dt}.md          # Fix logs
```

## Monorepo Workspace Context

The `monorepo/` version is designed for workspaces structured like:

```
workspace/
├── monorepo/           # Main monorepo with AGENTS.md, CLAUDE.md, skills/
├── molb-dp-shiok-job/  # Sibling project
└── other-project/      # Another sibling
```

When working in this setup, the agent:
1. Applies the custom instructions from this repo
2. Reads `monorepo/AGENTS.md` for monorepo-specific routing
3. Uses skills from `monorepo/skills/` tree
4. Follows service-local context when working inside monorepo services

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
