---
description: Sync .github/** to .qwen/** — translates GitHub Copilot agent/instruction format to Qwen Code format (no skills). Detects new, updated, and removed source files. Use --dry-run to preview.
---

**Input**: optional `--dry-run` flag. **Output**: `.qwen/commands/qc/` and `QWEN.md` up to date with `.github/`.

## Mapping rules

| Source (GHCP) | Destination (Qwen Code) | Transform |
|---|---|---|
| `.github/agents/<name>.agent.md` | `.qwen/commands/qc/<name>.md` | Strip `.agent` from filename; strip `tools:` and `argument-hint:` from frontmatter |
| `.github/instructions/<name>.instructions.md` | Inline in `QWEN.md` at project root | Copy full content into QWEN.md (strip YAML frontmatter) |

## Steps

### 1 — Sync agents → commands

1. List all files matching `.github/agents/*.agent.md`.
2. For each file `<name>.agent.md`:
   - Target: `.qwen/commands/qc/<name>.md`
   - Read source content.
   - Transform frontmatter: keep only `description:` line; remove `tools:`, `argument-hint:`, and any other fields.
   - If target does not exist → write → mark **ADDED**.
   - If target exists and content differs → overwrite → mark **UPDATED**.
   - If target exists and content matches → mark **OK** (skip write).
3. Detect orphans: `.qwen/commands/qc/` files that have no corresponding `.github/agents/` source and are NOT `sync-ghcp.md`. List as **ORPHAN** (do not delete).

### 2 — Sync instructions → QWEN.md inline content

1. List all files matching `.github/instructions/*.instructions.md`.
2. Read `QWEN.md` at project root (create if missing).
3. For each instructions file:
   - Read full content; strip YAML frontmatter (the `---` block).
   - If not already present in QWEN.md → append inline → mark **ADDED**.
   - If already present and matches → mark **OK**.
   - If already present but differs → update inline block → mark **UPDATED**.
4. Wrap each inlined block:
   ```
   <!-- sync-ghcp:instructions/<filename> -->
   <content>
   <!-- /sync-ghcp:instructions/<filename> -->
   ```

### 3 — Summary

```
Sync complete
─────────────────────────────────────
Commands:     X added, Y updated, Z ok, W orphaned
Instructions: X added, Y updated, Z ok
─────────────────────────────────────
```

If `--dry-run` was passed, prefix every ADDED/UPDATED line with `[DRY RUN]` and do not write any files.

## Constraints

- Never delete files from `.qwen/` — only add or update.
- `sync-ghcp.md` (this file) is excluded from orphan detection.
- Compare content byte-for-byte (no whitespace normalization).
- Frontmatter transform: only `description:` is kept; all other YAML keys are dropped.
