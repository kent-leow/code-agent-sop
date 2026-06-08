---
description: "Creates SNAPSHOT.md for any repo that is missing one, or updates all existing SNAPSHOT.md files based on user-provided changes (e.g. new sections, structure changes, content corrections). Triggers: snapshot, update snapshot, create snapshot, sync snapshot, missing snapshot, regenerate snapshot."
tools: [read, search, edit, todo]
argument-hint: "Leave blank to only create missing SNAPSHOT.md files. Or describe what to change (e.g. 'add a Dependencies section', 'rename Tech Stack to Stack', 'add port numbers to all backend snapshots')."
---

Manages `SNAPSHOT.md` at the root of each repo. Must NOT contain logic, endpoints, or anything that changes with normal feature work — only purpose, tech stack, key commands, source structure.

## Phase 1 — Discover

1. List all direct subdirectories of workspace root (these are repos).
2. For each, check if `SNAPSHOT.md` exists.
3. Report **Missing** and **Existing** lists before proceeding.

## Phase 2 — Mode

| User input | Mode |
|---|---|
| Blank | **Create-only** — create for missing; skip existing |
| Content/structure change | **Update-all** — apply change to all existing; also create missing |

## Phase 3A — Create Missing

For each in **Missing** list:
1. Read `README.md` (if present) for purpose, commands, stack.
2. Read primary build/package descriptor (`package.json`, `build.gradle`, `build.gradle.kts`, `pyproject.toml`, `pom.xml`) for stack and scripts.
3. Do NOT read `src/` or source directories.
4. Write `SNAPSHOT.md` using **Structure** below.

## Phase 3B — Update Existing

> Runs only when user provides a change description.

For each in **Existing** list:
1. Read current `SNAPSHOT.md`.
2. Apply change consistently: same position for new sections; rename everywhere; remove everywhere; content corrections only where relevant.
3. Preserve all content not mentioned. Don't read source files unless change requires fresh data.

## Structure

```md
# SNAPSHOT: <repo-name>

## Purpose
1–2 sentences: what this service/library/tool does and who uses it.

## Tech Stack
- Language: <language + version>
- Framework: <framework + version>
- Build tool: <tool>
- Java/Node: <version>
- Database: <if applicable>
- Lint: <tool>

## Key Commands
| Action        | Command         |
|---------------|------------------|
| test          | `<command>`     |
| lint / format | `<command>`     |
| build         | `<command>`     |
| run locally   | `<command>`     |

## Source Structure
\`\`\`
<top-level directories and purpose — max 10 lines>
\`\`\`

## Notes
- Credentials, inter-repo dependencies, non-obvious setup only.
- Omit if nothing worth noting.
```

## Rules
- Never include API endpoints, function names, DB schema, or business logic.
- Never include anything that changes during normal feature work.
- Keep every section brief — for agent orientation, not human docs.
- No build descriptor or README → write minimal file: `Purpose: Unknown — no README or build descriptor found.`
- Use `multi_replace_string_in_file` for same structural change across multiple files.

## Done When
- No repo missing `SNAPSHOT.md`.
- If update requested: all existing reflect change consistently.
- Report: how many created, updated, skipped.
