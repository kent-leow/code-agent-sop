---
description: "Sync .github/** to .qwen/** — translates GitHub Copilot agent/skill/instruction format to Qwen Code format. Detects new, updated, and removed source files. Use --dry-run to preview."
---

**Input**: optional `--dry-run` flag → **Output**: `.qwen/commands/qc/` and `QWEN.md` up to date with `.github/`.

## Mapping Rules

| Source (GHCP) | Destination (Qwen Code) | Transform |
|---|---|---|
| `.github/agents/<name>.agent.md` | `.qwen/commands/qc/<name>.md` | Strip `.agent` from filename; strip `tools:` and `argument-hint:` from frontmatter; replace `.github/skills/` → `.qwen/skills/` in body |
| `.github/instructions/<name>.instructions.md` | Inline in `QWEN.md` at project root | Copy full content into QWEN.md (strip YAML frontmatter) |
| `.github/skills/<skill>/SKILL.md` | `.qwen/skills/<skill>/SKILL.md` | Copy verbatim |
| `.github/skills/<skill>/scripts/*` | `.qwen/skills/<skill>/scripts/*` | Copy verbatim |
| `.github/skills/<skill>/references/*` | `.qwen/skills/<skill>/references/*` | Copy verbatim |

---

## Step 1 — Sync Agents → Commands

- DO: list all files matching `.github/agents/*.agent.md`
- LOOP: each file `<name>.agent.md`
  - STORE: target = `.qwen/commands/qc/<name>.md`
  - DO: read source content
  - DO: transform frontmatter — keep only `description:` line; remove `tools:`, `argument-hint:`, all other fields
  - DO: replace all `.github/skills/` → `.qwen/skills/` in body
  - IF: target does not exist → write → mark **ADDED**
  - IF: target exists and content differs → overwrite → mark **UPDATED**
  - IF: target exists and content matches → mark **OK** (skip write)
- DO: detect orphans — `.qwen/commands/qc/` files with no corresponding `.github/agents/` source AND not `sync-ghcp.md` → list as **ORPHAN** (do not delete)

## Step 2 — Sync Instructions → QWEN.md

- DO: list all files matching `.github/instructions/*.instructions.md`
- DO: read `QWEN.md` at project root (create if missing)
- LOOP: each instructions file
  - DO: read full content; strip YAML frontmatter (`---` block)
  - IF: not already present in QWEN.md → append inline → mark **ADDED**
  - IF: already present and matches → mark **OK**
  - IF: already present but differs → update inline block → mark **UPDATED**
- DO: wrap each inlined block:
  ```
  <!-- sync-ghcp:instructions/<filename> -->
  <content>
  <!-- /sync-ghcp:instructions/<filename> -->
  ```

## Step 3 — Sync Skills

- DO: list all skill directories under `.github/skills/` (ignore `.DS_Store` and hidden files)
- LOOP: each skill `<skill-name>`
  - LOOP: each file recursively under `.github/skills/<skill-name>/` (skip `.DS_Store`)
    - STORE: target = `.qwen/skills/<skill-name>/<relative-path>`
    - IF: target missing or content differs → write → mark **ADDED/UPDATED**
    - IF: content matches → mark **OK**

## Step 4 — Summary

- EMIT:
```
Sync complete
─────────────────────────────────────
Commands:     X added, Y updated, Z ok, W orphaned
Instructions: X added, Y updated, Z ok
Skills:       X added, Y updated, Z ok
─────────────────────────────────────
```

- IF: `--dry-run` passed → prefix every ADDED/UPDATED line with `[DRY RUN]`; do not write any files

## Constraints

- Never delete files from `.qwen/` — only add or update
- `sync-ghcp.md` (this file) is excluded from orphan detection
- Compare content byte-for-byte (no whitespace normalization)
- Frontmatter transform: only `description:` is kept; all other YAML keys are dropped
