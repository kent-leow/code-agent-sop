---
description: "Broadcasts agent/instruction/skill changes from root .github/ to multiple destinations (.claude/, general/.github/, general/.claude/, monorepo/.github/, monorepo/.claude/). Triggers: broadcast, sync agents, sync all, broadcast changes, sync to general, publish agents."
tools: [read, edit, search]
argument-hint: "[--dry-run] to preview changes without writing"
---

**Input**: root `.github/` content → **Output**: synced to all provider destinations.

---

## Providers

| Provider | Source → Destination | Transform |
|---|---|---|
| root-claude | agents → `.claude/commands/` | Strip `.agent`; all |
| root-claude | skills → `.claude/skills/` | Verbatim; all |
| root-claude | instructions → `.claude/CLAUDE.md` | Inline with markers |
| general-github | agents → `general/.github/agents/` | Exclude git agents |
| general-github | skills → `general/.github/skills/` | Exclude git skills |
| general-github | instructions → `general/.github/instructions/` | Verbatim |
| general-claude | agents → `general/.claude/commands/` | Exclude git agents |
| general-claude | skills → `general/.claude/skills/` | Exclude git skills |
| general-claude | instructions → `general/.claude/CLAUDE.md` | Inline with markers |
| monorepo-github | agents → `monorepo/.github/agents/` | Verbatim; all |
| monorepo-github | skills → `monorepo/.github/skills/` | Verbatim; all |
| monorepo-github | instructions → `monorepo/.github/instructions/` | Merge monorepo context |
| monorepo-claude | agents → `monorepo/.claude/commands/` | All |
| monorepo-claude | skills → `monorepo/.claude/skills/` | All |
| monorepo-claude | instructions → `monorepo/.claude/CLAUDE.md` | Markers + monorepo context |

## Exclusions (general only)

**Git Agents**: `fix-vulnerabilities`, `git-fix-review`, `git-review`
**Git Skills**: `fix-vulnerabilities`, `git-apis`, `git-workflow`, `gitlab-mr-automation`

---

## Phase 1 — Discover

- DO: list `.github/agents/`, `.github/instructions/`, `.github/skills/*/SKILL.md`
- STORE: agents[], instructions[], skills[], git_agents[], git_skills[]

## Phase 2 — Sync root-claude

- LOOP: agents → `.claude/commands/<name>.md` (strip `.agent`)
- LOOP: skills → `.claude/skills/<name>/SKILL.md`
- DO: instructions → `.claude/CLAUDE.md` (wrap in `<!-- sync-ghcp:... -->` markers)

## Phase 3 — Sync general-github

- LOOP: non-git agents → `general/.github/agents/`
- LOOP: non-git skills → `general/.github/skills/`
- LOOP: instructions → `general/.github/instructions/`

## Phase 4 — Sync general-claude

- LOOP: non-git agents → `general/.claude/commands/`
- LOOP: non-git skills → `general/.claude/skills/`
- DO: instructions → `general/.claude/CLAUDE.md` (markers)

## Phase 5 — Sync monorepo-github

- LOOP: all agents → `monorepo/.github/agents/`
- LOOP: all skills → `monorepo/.github/skills/`
- DO: instructions → `monorepo/.github/instructions/` (preserve monorepo context)

## Phase 6 — Sync monorepo-claude

- LOOP: all agents → `monorepo/.claude/commands/`
- LOOP: all skills → `monorepo/.claude/skills/`
- DO: instructions → `monorepo/.claude/CLAUDE.md` (markers + monorepo context)

## Phase 7 — Detect Orphans

- DO: list destination files without source → EMIT orphan list (do not delete)

## Phase 8 — Summary

- EMIT: per-provider table (ADDED / UPDATED / OK counts) + orphan list
- IF: `--dry-run` → prefix with `[DRY RUN]`, do not write files

## Constraints

- Never delete files — only add or update
- Never modify `.claude/settings.local.json`
- Byte-for-byte comparison (no whitespace normalization)
- Git agents excluded from general only; monorepo gets all
- `broadcast-sync.md` excluded from orphan detection
- Preserve monorepo-specific context sections when syncing

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
