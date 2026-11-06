---
description: "Broadcasts agent/instruction/skill changes from root .github/ to multiple destinations (.claude/, general/.github/, general/.claude/, monorepo/.github/, monorepo/.claude/). Triggers: broadcast, sync agents, sync all, broadcast changes, sync to general, publish agents."
tools: [read, edit, search]
argument-hint: "[--dry-run] to preview changes without writing"
---

**Input**: root `.github/` (+ root `.claude/hooks/`, `.claude/settings.json`) → **Output**: synced to all provider destinations.

---

## Providers

| Provider | Source → Destination | Transform |
|---|---|---|
| root-claude | agents → `.claude/commands/` | Strip `.agent`; all |
| root-claude | skills → `.claude/skills/` | Whole skill folder (SKILL.md + `scripts/`) verbatim; all |
| root-claude | instructions → `.claude/CLAUDE.md` | Inline with markers |
| general-github | agents → `general/.github/agents/` | Exclude integration agents |
| general-github | skills → `general/.github/skills/` | Whole folder; exclude integration skills; docs-folder transforms |
| general-github | instructions → `general/.github/instructions/` | Verbatim |
| general-claude | agents → `general/.claude/commands/` | Exclude integration agents |
| general-claude | skills → `general/.claude/skills/` | Whole folder; exclude integration skills; docs-folder transforms |
| general-claude | instructions → `general/.claude/CLAUDE.md` | Inline with markers |
| general-claude | `.claude/hooks/*`, `.claude/settings.json` → `general/.claude/` | Verbatim (session_start.sh is a no-op without integration-health) |
| monorepo-github | agents → `monorepo/.github/agents/` | Verbatim; all |
| monorepo-github | skills → `monorepo/.github/skills/` | Whole folder verbatim; all |
| monorepo-github | instructions → `monorepo/.github/instructions/` | Merge monorepo context |
| monorepo-claude | agents → `monorepo/.claude/commands/` | All |
| monorepo-claude | skills → `monorepo/.claude/skills/` | Whole folder; all |
| monorepo-claude | instructions → `monorepo/.claude/CLAUDE.md` | Markers + monorepo context |
| monorepo-claude | `.claude/hooks/*`, `.claude/settings.json` → `monorepo/.claude/` | Verbatim |

**docs-folder transforms (general only)**: replace `**PROFILE: gobiz**` → `**PROFILE: general**`; drop the Folder Layout line containing `env-chope/`.

## Exclusions (general only)

`tests/test_sync.py` parses these two lines — keep the format.

**Integration Agents**: `cft-onboarding`, `env-chope`, `fix-vulnerabilities`, `git-fix-review`, `git-review`, `investigate-apex`
**Integration Skills**: `apex-onboarding`, `aws-access`, `cft-agency-onboarding`, `change-timeline`, `env-chope`, `fix-vulnerabilities`, `git-apis`, `git-workflow`, `integration-health`, `investigate-apex`, `opensearch-logs`, `postgres-query`

---

## Phase 1 — Detect Changed Sources

- RUN: `git diff --name-only -- .github/ .claude/hooks .claude/settings.json` (unstaged) + same with `--staged` + `git ls-files --others --exclude-standard -- .github/ .claude/hooks` (new files), union all
- IF: no changes found → EMIT "No changes in .github/ — nothing to sync" and STOP
- FILTER: only files under `.github/agents/`, `.github/instructions/`, `.github/skills/` (any file in a skill folder → that skill), `.claude/hooks/`, `.claude/settings.json`
- CLASSIFY: changed_agents[], changed_instructions[], changed_skills[], changed_hooks (bool)
- ALSO STORE: integration_agents[], integration_skills[] (Exclusions section)
- EMIT: list of changed source files being synced

## Phase 2 — Sync root-claude (changed only)

- LOOP: changed_agents → `.claude/commands/<name>.md` (strip `.agent`)
- LOOP: changed_skills → `.claude/skills/<name>/` (whole folder)
- IF: changed_instructions not empty → `.claude/CLAUDE.md` (wrap in `<!-- sync-ghcp:... -->` markers)

## Phase 3 — Sync general-github (changed only)

- LOOP: changed non-integration agents → `general/.github/agents/`
- LOOP: changed non-integration skills → `general/.github/skills/<name>/` (whole folder)
  - IF: skill = `docs-folder` → apply docs-folder transforms
- LOOP: changed instructions → `general/.github/instructions/`

## Phase 4 — Sync general-claude (changed only)

- LOOP: changed non-integration agents → `general/.claude/commands/`
- LOOP: changed non-integration skills → `general/.claude/skills/<name>/` (whole folder)
  - IF: skill = `docs-folder` → apply docs-folder transforms
- IF: changed_hooks → copy `.claude/hooks/*` + `.claude/settings.json` → `general/.claude/`
- IF: changed_instructions not empty → `general/.claude/CLAUDE.md` (markers)

## Phase 5 — Sync monorepo-github (changed only)

- LOOP: changed agents → `monorepo/.github/agents/`
- LOOP: changed skills → `monorepo/.github/skills/<name>/` (whole folder)
- IF: changed_instructions not empty → `monorepo/.github/instructions/` (preserve monorepo context)

## Phase 6 — Sync monorepo-claude (changed only)

- LOOP: changed agents → `monorepo/.claude/commands/`
- LOOP: changed skills → `monorepo/.claude/skills/<name>/` (whole folder)
- IF: changed_instructions not empty → `monorepo/.claude/CLAUDE.md` (markers + monorepo context)
- IF: changed_hooks → copy `.claude/hooks/*` + `.claude/settings.json` → `monorepo/.claude/`

## Phase 7 — Detect Orphans

- DO: list destination files without source → EMIT orphan list (do not delete; a skill/agent removed at root → ask the user, then `git rm` its copies)
- DO: `python3 -m unittest tests.test_sync -q` → must pass (verifies every destination matches root after transforms)

## Phase 8 — Summary

- EMIT: per-provider table (ADDED / UPDATED / OK counts) + orphan list
- IF: `--dry-run` → prefix with `[DRY RUN]`, do not write files

## Constraints

- Never delete files — only add or update
- Never modify `.claude/settings.local.json`
- Only sync files with git changes (staged or unstaged); skip unchanged files
- Integration agents/skills excluded from general only; monorepo gets all
- `broadcast-sync.md` excluded from orphan detection
- Preserve monorepo-specific context sections when syncing
- `docs-folder` PROFILE: root + monorepo = `gobiz` (Jira key in folder name); general = `general`
