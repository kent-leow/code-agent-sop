---
description: "Sync .github/** to .claude/** — translates GitHub Copilot agent/skill/instruction format to Claude Code format. Detects new, updated, and removed source files. Triggers: sync github, sync agents, sync commands, sync skills, sync instructions, /sync-github."
tools: [read, write, search, edit, execute]
argument-hint: "[--dry-run] to preview changes without writing"
---

**Input**: optional `--dry-run` flag. **Output**: `.claude/commands/` and `.claude/CLAUDE.md` up to date with `.github/`.

## Mapping rules

| Source (GHCP) | Destination (Claude Code) | Transform |
|---|---|---|
| `.github/agents/<name>.agent.md` | `.claude/commands/<name>.md` | Strip `.agent` from filename; content verbatim |
| `.github/instructions/<name>.instructions.md` | Reference line in `.claude/CLAUDE.md` | Ensure `Refer to ../.github/instructions/<name>.instructions.md for rules.` exists |
| `.github/skills/<skill>/SKILL.md` | `.claude/skills/<skill>/SKILL.md` | Copy verbatim |
| `.github/skills/<skill>/scripts/*` | `.claude/skills/<skill>/scripts/*` | Copy verbatim |
| `.github/skills/<skill>/references/*` | `.claude/skills/<skill>/references/*` | Copy verbatim |

## Steps

### 1 — Sync agents → commands

1. List all files matching `.github/agents/*.agent.md`.
2. For each file `<name>.agent.md`:
   - Target: `.claude/commands/<name>.md`
   - Read source content.
   - If target does not exist → write source content → mark **ADDED**.
   - If target exists and content differs → overwrite → mark **UPDATED**.
   - If target exists and content matches → mark **OK** (skip write).
3. Detect orphans: `.claude/commands/` files that have no corresponding `.github/agents/` source and are NOT `sync-github.md` (this file itself). List them as **ORPHAN** (do not delete — may be Claude Code-only commands).

### 2 — Sync instructions → CLAUDE.md references

1. List all files matching `.github/instructions/*.instructions.md`.
2. Read `.claude/CLAUDE.md`.
3. For each instructions file not yet referenced:
   - Append line: `Refer to ../.github/instructions/<filename> for rules.`
   - Mark **ADDED** to CLAUDE.md.
4. Report already-present references as **OK**.

### 3 — Sync skills

1. List all skill directories under `.github/skills/` (ignore `.DS_Store` and hidden files).
2. For each skill `<skill-name>`:
   - For each file recursively under `.github/skills/<skill-name>/` (skip `.DS_Store`):
     - Target: `.claude/skills/<skill-name>/<relative-path>`
     - If target missing or content differs → write → mark **ADDED/UPDATED**.
     - Otherwise mark **OK**.

### 4 — Summary

Print a concise table:

```
Sync complete
─────────────────────────────────────
Commands:     X added, Y updated, Z ok, W orphaned
Instructions: X added, Z ok
Skills:       X added, Y updated, Z ok
─────────────────────────────────────
```

If `--dry-run` was passed, prefix every ADDED/UPDATED line with `[DRY RUN]` and do not write any files.

## Constraints

- Never delete files from `.claude/` — only add or update.
- Never modify `.claude/settings.local.json`.
- `sync-github.md` (this file) is excluded from orphan detection.
- When comparing content, compare byte-for-byte (no whitespace normalization).
