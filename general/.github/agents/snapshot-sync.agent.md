---
description: "Creates SNAPSHOT.md for any repo that is missing one, or updates all existing SNAPSHOT.md files based on user-provided changes (e.g. new sections, structure changes, content corrections). Triggers: snapshot, update snapshot, create snapshot, sync snapshot, missing snapshot, regenerate snapshot."
tools: [read, search, edit, todo]
argument-hint: "Leave blank to only create missing SNAPSHOT.md files. Or describe what to change."
---

Manages `SNAPSHOT.md` at repo root. Must NOT contain logic, endpoints, or anything that changes with normal feature work.

## Phase 1 — Discover

- DO: list all direct subdirectories of workspace root (these are repos)
- DO: check each for `SNAPSHOT.md`
- EMIT: Missing and Existing lists

## Phase 2 — Mode

| User input | Mode |
|---|---|
| Blank | **Create-only** — create for missing; skip existing |
| Content/structure change | **Update-all** — apply to all existing + create missing |

## Phase 3A — Create Missing

- LOOP: each in Missing list
  - DO: read `README.md` (if present) for purpose, commands, stack
  - DO: read build descriptor (`package.json`, `build.gradle`, `pom.xml`, etc.)
  - DO: write `SNAPSHOT.md` per Structure below
  - IF: no README or build descriptor → write minimal: `Purpose: Unknown`

## Phase 3B — Update Existing

- LOOP: each in Existing list
  - DO: read current `SNAPSHOT.md`
  - DO: apply change consistently (same position, rename/remove everywhere)
  - DO: preserve content not mentioned

## Structure

```md
# SNAPSHOT: <repo-name>

## Purpose
1–2 sentences: what this does and who uses it.

## Tech Stack
- Language / Framework / Build tool / Runtime / Database / Lint

## Key Commands
| Action | Command |
|--------|---------|
| test | `<cmd>` |
| lint | `<cmd>` |
| build | `<cmd>` |
| run | `<cmd>` |

## Source Structure
<top-level dirs + purpose — max 10 lines>

## Notes
- Non-obvious setup, credentials, inter-repo deps only. Omit if nothing.
```

## Constraints

- Never include API endpoints, function names, DB schema, or business logic
- Never include anything that changes during normal feature work
- Keep brief — for agent orientation, not human docs
- Do NOT read `src/` or source directories

## Done When

- No repo missing `SNAPSHOT.md`
- IF: update requested → all existing reflect change consistently
- EMIT: count created, updated, skipped
