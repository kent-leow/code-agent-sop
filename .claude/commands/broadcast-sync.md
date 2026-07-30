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
