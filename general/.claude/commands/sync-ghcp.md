---
description: "Sync .github/** to .claude/** — translates GitHub Copilot agent/instruction format to Claude Code format. Detects new, updated, and removed source files. Triggers: sync github, sync agents, sync commands, sync instructions, /sync-ghcp."
tools: [read, write, search, edit, execute]
argument-hint: "[--dry-run] to preview changes without writing"
---

**Input**: optional `--dry-run` flag. **Output**: `.claude/commands/` and `.claude/CLAUDE.md` up to date with `.github/`.

## Mapping rules

| Source (GHCP) | Destination (Claude Code) | Transform |
|---|---|---|
| `.github/agents/<name>.agent.md` | `.claude/commands/<name>.md` | Strip `.agent` from filename; content verbatim |
| `.github/instructions/<name>.instructions.md` | Inline in `.claude/CLAUDE.md` | Copy full content into CLAUDE.md (not just a reference path) |

## Steps

### 1 — Sync agents → commands

1. List all files matching `.github/agents/*.agent.md`.
2. For each file `<name>.agent.md`:
   - Target: `.claude/commands/<name>.md`
   - Read source content.
   - If target does not exist → write source content → mark **ADDED**.
   - If target exists and content differs → overwrite → mark **UPDATED**.
   - If target exists and content matches → mark **OK** (skip write).
3. Detect orphans: `.claude/commands/` files that have no corresponding `.github/agents/` source and are NOT `sync-ghcp.md` (this file itself). List them as **ORPHAN** (do not delete — may be Claude Code-only commands).

### 2 — Sync instructions → CLAUDE.md inline content

1. List all files matching `.github/instructions/*.instructions.md`.
2. Read `.claude/CLAUDE.md`.
3. For each instructions file:
   - Read the full content of the instructions file (strip YAML frontmatter if present).
   - If the content is not already present in CLAUDE.md → append it inline → mark **ADDED**.
   - If already present and content matches → mark **OK**.
   - If already present but content differs → update inline block → mark **UPDATED**.
4. Wrap each inlined block with comment markers for future diffing:
   ```
   <!-- sync-ghcp:instructions/<filename> -->
   <content>
   <!-- /sync-ghcp:instructions/<filename> -->
   ```

### 3 — Summary

Print a concise table:

```
Sync complete
─────────────────────────────────────
Commands:     X added, Y updated, Z ok, W orphaned
Instructions: X added, Y updated, Z ok
─────────────────────────────────────
```

If `--dry-run` was passed, prefix every ADDED/UPDATED line with `[DRY RUN]` and do not write any files.

## Constraints

- Never delete files from `.claude/` — only add or update.
- Never modify `.claude/settings.local.json`.
- `sync-ghcp.md` (this file) is excluded from orphan detection.
- When comparing content, compare byte-for-byte (no whitespace normalization).
