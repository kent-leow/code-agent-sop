# Code Agent SOP

Platform-agnostic AI coding agent instructions that turn raw requirements into production code via a structured pipeline. Works with any codebase — no CI/CD, issue tracker, or design tool required.

## Pipeline

```
Raw Requirements
  → @generate-plan   →  plan.md
  → @generate-task   →  task-001.md, task-002.md, ...
  → @execute-task    →  production code + tests
  → @fix-task        →  fixes/fix-{datetime}-{name}.md
```

Each stage produces artefacts in one work folder per ticket (`docs-folder` skill):

| Variant | Folder | Example |
|---|---|---|
| root / `monorepo/` (gobiz) | `.docs/<JIRA-KEY>-<kebab-title>/` — Jira key required | `.docs/GOBIZWKST2-324-create-form-and-application/` |
| `general/` | `.docs/<kebab-title>/` | `.docs/create-form-and-application/` |

Nothing advances until prior stage is complete.

### Greenfield (new app from scratch)

Detected automatically (empty repo / no app manifest / "from scratch" request / `**Project Type**: Greenfield` in `plan.md`):

```
@generate-plan  →  plan.md (feature inventory, users & roles, information architecture, platform constraints)
@generate-task  →  blueprint.md (stack + verified versions, envs, env vars, commands, route map, navigation) → STOP for approval
"approve blueprint" →  phased task-NNN.md:
   P0 Environment & Toolchain → P1 Backbone Scaffold → P2 Delivery Pipeline (CI)
   → P3 Cross-cutting Foundations → P4 App Shell, Routing & Navigation
   → P5 Features (walking skeleton first) → P6 Hardening & Release
@execute-task   →  one task at a time; app stays runnable after every task
```

Rules live in the `app-blueprint` skill.

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

Invoke via `@<agent-name>` in your IDE's AI chat.

## Agents

| Agent | Purpose | Triggers |
|---|---|---|
| `generate-plan` | Raw requirements → structured `plan.md` with AC | plan, I need, create feature |
| `generate-task` | `plan.md` → vertical-slice `task-NNN.md` files (greenfield: `blueprint.md` + phased tasks) | generate tasks, break down plan, new app, approve blueprint |
| `execute-task` | Implement `task-NNN.md` end-to-end (code + tests) | execute task, implement, code this |
| `fix-task` | Apply fixes from review comments / bugs / failing tests | fix, bug, review comment, regression |
| `investigate` | Root-cause analysis + evidence-based report | investigate, why is, root cause, debug |
| `snapshot-sync` | Create/update `SNAPSHOT.md` for repo orientation | snapshot, update snapshot |
| `spike-plan` | Technical spike document from `plan.md` uncertainties | spike, feasibility, de-risk |

## Instructions

| File | Scope |
|---|---|
| `instructions/guidelines.instructions.md` | Core principles — grounding, anti-hallucination, SOLID, quality gates |

Applied automatically to every interaction.

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

Reduces token waste; unambiguous for LLMs to parse.

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

.docs/                       # One folder per ticket, created by agents (docs-folder skill)
└── <JIRA-KEY>-<kebab-title>/  # general/: <kebab-title>/
    ├── plan.md              # Requirements + AC
    ├── spike.md, spike-report.md
    ├── blueprint.md         # Greenfield only: stack, envs, commands, route map, nav
    ├── jira.json            # Jira story + sub-task keys
    ├── task-NNN.md          # Vertical slices
    ├── figma/               # Cached Figma assets
    ├── fixes/fix-{dt}-{name}.md        # Fix logs
    ├── investigation-<topic>/          # investigate / investigate-apex reports
    ├── cft-checklist.md
    ├── env-chope/cleanup-*.sql  # Draft Flyway cleanup for choped env cards
    └── vulnerability/vulnerabilities-{date}.md
```

## Monorepo Workspace Context

`monorepo/` targets workspaces structured like:

```
workspace/
├── monorepo/           # Main monorepo with AGENTS.md, CLAUDE.md, skills/
├── molb-dp-shiok-job/  # Sibling project
└── other-project/      # Another sibling
```

The agent: applies these instructions → reads `monorepo/AGENTS.md` for routing → uses `monorepo/skills/` → follows service-local context inside monorepo services.

## Extended Variant

Root `.github/` and `.qwen/` add:

| Extra | Purpose |
|---|---|
| `git-review` | Review/summarise/act on GitHub PR or GitLab MR |
| `git-fix-review` | Fix open review threads, commit, push, poll pipeline |
| `fix-vulnerabilities` | Fetch + fix GitLab security vulnerabilities |
| `env-chope` | Chope/release DEV/QA/STAGING env cards on the MOLBLT Chope Env board from a GitLab MR (touched apps + Flyway) |
| `figma-design-context` skill | Fetch design context from Figma REST API |
| `jira-ticket` skill | Create/update Jira stories and sub-tasks |
| `opensearch-logs` skill | Read-only log search/count/aggregate/trace on MOLB OpenSearch (dev/qa/stg/prod; VPN) — used by `investigate` |
| `postgres-query` skill | psql access to licence / agency-portal / formbuilder / onboarding-portal / payment DBs (PROD read-only; lower-env writes need approval) — used by `investigate` |
| `git-workflow` skill | Branch → commit → push → MR → pipeline polling |
| `git-apis` skill | Shared GitLab + GitHub REST API primitives |

Requires tokens in `~/.zshenv` — see `.env.example` for the full list.

## Workflow Details

See [.docs-workflow-README.md](.docs-workflow-README.md) for the full pipeline documentation.
