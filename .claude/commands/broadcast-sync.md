---
description: "Broadcasts agent/instruction/skill changes from root .github/ to multiple destinations (.claude/, general/.github/, general/.claude/). Triggers: broadcast, sync agents, sync all, broadcast changes, sync to general, publish agents."
tools: [read, edit, search]
argument-hint: "[--dry-run] to preview changes without writing"
---

Syncs `.github/` content to multiple providers. Root keeps integrations; general is integration-free.

## Providers

| Provider | Source | Destination | Transform |
|---|---|---|---|
| **root-claude** | `.github/agents/*.agent.md` | `.claude/commands/*.md` | Strip `.agent`; all agents |
| **root-claude** | `.github/instructions/*.instructions.md` | `.claude/CLAUDE.md` | Inline with markers |
| **general-github** | `.github/agents/*.agent.md` | `general/.github/agents/*.agent.md` | Verbatim; exclude integrations |
| **general-github** | `.github/instructions/*.instructions.md` | `general/.github/instructions/*.instructions.md` | Verbatim |
| **general-claude** | `.github/agents/*.agent.md` | `general/.claude/commands/*.md` | Strip `.agent`; exclude integrations |
| **general-claude** | `.github/instructions/*.instructions.md` | `general/.claude/CLAUDE.md` | Inline with markers |

## Integration Agents (excluded from general)

- `fix-vulnerabilities.agent.md`
- `git-fix-review.agent.md`
- `git-review.agent.md`

## Phase 1 — Discover

- DO: list `.github/agents/*.agent.md`
- DO: list `.github/instructions/*.instructions.md`
- STORE: `agents[]`, `instructions[]`, `integration_agents[]`

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

- LOOP: each agent NOT in `integration_agents[]`
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

- LOOP: each agent NOT in `integration_agents[]`
  - Target: `general/.claude/commands/<name>.md`
  - IF: target missing or differs → write → mark ADDED/UPDATED
  - ELSE: mark OK

### 4.2 — Instructions → CLAUDE.md

- DO: read `general/.claude/CLAUDE.md`
- LOOP: each instructions file (same marker logic as Phase 2.2)

## Phase 5 — Detect Orphans

- DO: list `.claude/commands/` files without `.github/agents/` source
- DO: list `general/.claude/commands/` files without non-integration source
- Exclude: `broadcast-sync.md` (this agent's command form)
- EMIT: orphan list (do not delete)

## Phase 6 — Summary

```
Broadcast complete
───────────────────────────────────────────────────
Provider        Commands    Instructions
───────────────────────────────────────────────────
root-claude     X/Y/Z       X/Y/Z
general-github  X/Y/Z       X/Y/Z
general-claude  X/Y/Z       X/Y/Z
───────────────────────────────────────────────────
Orphans: N
```

(X = added, Y = updated, Z = ok)

If `--dry-run`: prefix writes with `[DRY RUN]`, do not write files.

## Constraints

- Never delete files — only add or update
- Never modify `.claude/settings.local.json`
- Byte-for-byte comparison (no whitespace normalization)
- Integration agents never go to general providers
- `broadcast-sync.md` excluded from orphan detection
