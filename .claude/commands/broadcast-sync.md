---
description: "Broadcasts agent/instruction/skill changes from root .github/ to multiple destinations (.claude/, general/.github/, general/.claude/, monorepo/.github/, monorepo/.claude/). Triggers: broadcast, sync agents, sync all, broadcast changes, sync to general, publish agents."
tools: [read, edit, search]
argument-hint: "[--dry-run] to preview changes without writing"
---

Syncs `.github/` content to multiple providers.

- **Root** = standalone repo template (all agents + skills incl. git)
- **Monorepo** = monorepo template (all agents + skills incl. git)
- **General** = integration-free template (no git agents/skills)

## Providers

| Provider | Source | Destination | Transform |
|---|---|---|---|
| **root-claude** | `.github/agents/*.agent.md` | `.claude/commands/*.md` | Strip `.agent`; all agents |
| **root-claude** | `.github/instructions/*.instructions.md` | `.claude/CLAUDE.md` | Inline with markers |
| **general-github** | `.github/agents/*.agent.md` | `general/.github/agents/*.agent.md` | Verbatim; exclude git agents |
| **general-github** | `.github/instructions/*.instructions.md` | `general/.github/instructions/*.instructions.md` | Verbatim |
| **general-claude** | `.github/agents/*.agent.md` | `general/.claude/commands/*.md` | Strip `.agent`; exclude git agents |
| **general-claude** | `.github/instructions/*.instructions.md` | `general/.claude/CLAUDE.md` | Inline with markers |
| **monorepo-github** | `.github/agents/*.agent.md` | `monorepo/.github/agents/*.agent.md` | Verbatim; all agents |
| **monorepo-github** | `.github/skills/*/SKILL.md` | `monorepo/.github/skills/*/SKILL.md` | Verbatim; all skills |
| **monorepo-github** | `.github/instructions/*.instructions.md` | `monorepo/.github/instructions/*.instructions.md` | Merge monorepo context |
| **monorepo-claude** | `.github/agents/*.agent.md` | `monorepo/.claude/commands/*.md` | Strip `.agent`; all agents |
| **monorepo-claude** | `.github/instructions/*.instructions.md` | `monorepo/.claude/CLAUDE.md` | Inline with markers + monorepo context |

## Git Agents (excluded from general only)

- `fix-vulnerabilities.agent.md`
- `git-fix-review.agent.md`
- `git-review.agent.md`

## Skills (synced to monorepo)

- `figma-design-context/SKILL.md` (+ scripts/)
- `fix-vulnerabilities/SKILL.md`
- `git-apis/SKILL.md`
- `git-workflow/SKILL.md`
- `gitlab-mr-automation/SKILL.md`
- `jira-ticket/SKILL.md`

## Monorepo Context (appended to monorepo version)

The monorepo version includes additional context for workspace navigation when the monorepo is a sibling folder. Preserve monorepo-specific sections when syncing base instructions.

## Phase 1 — Discover

- DO: list `.github/agents/*.agent.md`
- DO: list `.github/instructions/*.instructions.md`
- DO: list `.github/skills/*/SKILL.md`
- STORE: `agents[]`, `instructions[]`, `skills[]`, `git_agents[]`

## Phase 2 — Sync root-claude

### 2.1 — Agents → Commands

- LOOP: each `<name>.agent.md` in `agents[]`
  - Target: `.claude/commands/<name>.md`
  - IF: target missing or content differs → write → mark ADDED/UPDATED
  - ELSE: mark OK

### 2.2 — Instructions → CLAUDE.md

- DO: read `.claude/CLAUDE.md`
- LOOP: each instructions file
  - DO: extract content (strip YAML frontmatter)
  - DO: wrap with markers:
    ```
    <!-- sync-ghcp:instructions/<filename> -->
    <content>
    <!-- /sync-ghcp:instructions/<filename> -->
    ```
  - IF: marker block missing → append → mark ADDED
  - IF: marker block exists but differs → replace → mark UPDATED
  - ELSE: mark OK

## Phase 3 — Sync general-github

### 3.1 — Agents

- LOOP: each agent NOT in `git_agents[]`
  - Target: `general/.github/agents/<name>.agent.md`
  - IF: target missing or differs → write → mark ADDED/UPDATED
  - ELSE: mark OK

### 3.2 — Instructions

- LOOP: each instructions file
  - Target: `general/.github/instructions/<filename>`
  - IF: target missing or differs → write → mark ADDED/UPDATED
  - ELSE: mark OK

## Phase 4 — Sync general-claude

### 4.1 — Agents → Commands

- LOOP: each agent NOT in `git_agents[]`
  - Target: `general/.claude/commands/<name>.md`
  - IF: target missing or differs → write → mark ADDED/UPDATED
  - ELSE: mark OK

### 4.2 — Instructions → CLAUDE.md

- DO: read `general/.claude/CLAUDE.md`
- LOOP: each instructions file (same marker logic as Phase 2.2)

## Phase 5 — Sync monorepo-github

### 5.1 — Agents (all agents)

- LOOP: each agent in `agents[]`
  - Target: `monorepo/.github/agents/<name>.agent.md`
  - IF: target missing or differs → write → mark ADDED/UPDATED
  - ELSE: mark OK

### 5.2 — Skills (all git skills)

- LOOP: each skill in `skills[]`
  - Target: `monorepo/.github/skills/<skill-name>/SKILL.md`
  - IF: target missing or differs → write → mark ADDED/UPDATED
  - ELSE: mark OK

### 5.3 — Instructions

- DO: monorepo instructions have additional context section — preserve it
- IF: monorepo guidelines differs (excluding monorepo context) → update base + keep context

## Phase 6 — Sync monorepo-claude

### 6.1 — Agents → Commands (all agents)

- LOOP: each agent in `agents[]`
  - Target: `monorepo/.claude/commands/<name>.md`
  - IF: target missing or differs → write → mark ADDED/UPDATED
  - ELSE: mark OK

### 6.2 — Instructions → CLAUDE.md

- DO: read `monorepo/.claude/CLAUDE.md`
- LOOP: each instructions file (same marker logic — preserve monorepo context)

## Phase 7 — Detect Orphans

- DO: list `.claude/commands/` files without `.github/agents/` source
- DO: list `general/.claude/commands/` files without non-git agent source
- DO: list `monorepo/.claude/commands/` files without agent source
- DO: list `monorepo/.github/skills/` folders without `.github/skills/` source
- Exclude: `broadcast-sync.md` (this agent's command form)
- EMIT: orphan list (do not delete)

## Phase 8 — Summary

```
Broadcast complete
─────────────────────────────────────────────────────
Provider          Agents      Skills      Instructions
─────────────────────────────────────────────────────
root-claude       X/Y/Z       -           X/Y/Z
general-github    X/Y/Z       -           X/Y/Z
general-claude    X/Y/Z       -           X/Y/Z
monorepo-github   X/Y/Z       X/Y/Z       X/Y/Z
monorepo-claude   X/Y/Z       -           X/Y/Z
─────────────────────────────────────────────────────
Orphans: N
```

(X = added, Y = updated, Z = ok)

If `--dry-run`: prefix writes with `[DRY RUN]`, do not write files.

## Constraints

- Never delete files — only add or update
- Never modify `.claude/settings.local.json`
- Byte-for-byte comparison (no whitespace normalization)
- Git agents excluded from general only; monorepo gets all agents + skills
- `broadcast-sync.md` excluded from orphan detection
- Preserve monorepo-specific context sections when syncing
