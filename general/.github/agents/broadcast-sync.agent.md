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

## Phase 1 — Detect Changed Sources

- RUN: `git diff --name-only -- .github/` (unstaged) + `git diff --staged --name-only -- .github/` (staged), union both
- IF: no changes found → EMIT "No changes in .github/ — nothing to sync" and STOP
- FILTER: only files under `.github/agents/`, `.github/instructions/`, `.github/skills/`
- CLASSIFY: changed_agents[], changed_instructions[], changed_skills[]
- ALSO STORE: git_agents[], git_skills[] (exclusion lists, same as before)
- EMIT: list of changed source files being synced

## Phase 2 — Sync root-claude (changed only)

- LOOP: changed_agents → `.claude/commands/<name>.md` (strip `.agent`)
- LOOP: changed_skills → `.claude/skills/<name>/SKILL.md`
- IF: changed_instructions not empty → `.claude/CLAUDE.md` (wrap in `<!-- sync-ghcp:... -->` markers)

## Phase 3 — Sync general-github (changed only)

- LOOP: changed non-git agents → `general/.github/agents/`
- LOOP: changed non-git skills → `general/.github/skills/`
- LOOP: changed instructions → `general/.github/instructions/`

## Phase 4 — Sync general-claude (changed only)

- LOOP: changed non-git agents → `general/.claude/commands/`
- LOOP: changed non-git skills → `general/.claude/skills/`
- IF: changed_instructions not empty → `general/.claude/CLAUDE.md` (markers)

## Phase 5 — Sync monorepo-github (changed only)

- LOOP: changed agents → `monorepo/.github/agents/`
- LOOP: changed skills → `monorepo/.github/skills/`
- IF: changed_instructions not empty → `monorepo/.github/instructions/` (preserve monorepo context)

## Phase 6 — Sync monorepo-claude (changed only)

- LOOP: changed agents → `monorepo/.claude/commands/`
- LOOP: changed skills → `monorepo/.claude/skills/`
- IF: changed_instructions not empty → `monorepo/.claude/CLAUDE.md` (markers + monorepo context)

## Phase 7 — Detect Orphans

- DO: list destination files without source → EMIT orphan list (do not delete)

## Phase 8 — Summary

- EMIT: per-provider table (ADDED / UPDATED / OK counts) + orphan list
- IF: `--dry-run` → prefix with `[DRY RUN]`, do not write files

## Constraints

- Never delete files — only add or update
- Never modify `.claude/settings.local.json`
- Only sync files with git changes (staged or unstaged); skip unchanged files
- Git agents excluded from general only; monorepo gets all
- `broadcast-sync.md` excluded from orphan detection
- Preserve monorepo-specific context sections when syncing
