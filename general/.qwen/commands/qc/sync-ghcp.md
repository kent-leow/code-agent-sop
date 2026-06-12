**Input**: optional `--dry-run` flag → **Output**: `.qwen/commands/qc/` and `QWEN.md` synced with `.github/`.

## Mapping

| Source | Destination | Transform |
|---|---|---|
| `.github/agents/<name>.agent.md` | `.qwen/commands/qc/<name>.md` | Strip `.agent` from filename; strip `tools:` and `argument-hint:` from frontmatter |
| `.github/instructions/<name>.instructions.md` | Inline in `QWEN.md` | Strip YAML frontmatter; wrap in sync markers |

## Steps

### 1 — Sync agents → commands

- DO: list all `.github/agents/*.agent.md`
- LOOP: each `<name>.agent.md`
  - STORE: target = `.qwen/commands/qc/<name>.md`
  - DO: read source content
  - DO: transform frontmatter — keep only `description:`; remove `tools:`, `argument-hint:`, other fields
  - IF: target missing → DO: write → EMIT: **ADDED**
  - IF: target exists + content differs → DO: overwrite → EMIT: **UPDATED**
  - IF: target exists + content matches → EMIT: **OK**
- DO: detect orphans in `.qwen/commands/qc/` with no `.github/agents/` source (exclude `sync-ghcp.md`) → EMIT: **ORPHAN** (do not delete)

### 2 — Sync instructions → QWEN.md

- DO: list all `.github/instructions/*.instructions.md`
- DO: read `QWEN.md` (create if missing)
- LOOP: each instructions file
  - DO: read content; strip YAML frontmatter
  - IF: not in QWEN.md → DO: append → EMIT: **ADDED**
  - IF: present + matches → EMIT: **OK**
  - IF: present + differs → DO: update → EMIT: **UPDATED**
- DO: wrap each block in `<!-- sync-ghcp:instructions/<filename> -->` markers

### 3 — Summary

- EMIT:

```
Sync complete
─────────────────────────────────────
Commands:     X added, Y updated, Z ok, W orphaned
Instructions: X added, Y updated, Z ok
─────────────────────────────────────
```

- IF: `--dry-run` → prefix ADDED/UPDATED with `[DRY RUN]`; do not write

## Constraints

- Never delete files from `.qwen/` — only add or update
- `sync-ghcp.md` excluded from orphan detection
- Compare content byte-for-byte (no whitespace normalization)
- Frontmatter transform: only `description:` kept; all other YAML keys dropped
