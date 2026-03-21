---
description: "Creates SNAPSHOT.md for any repo that is missing one, or updates all existing SNAPSHOT.md files based on user-provided changes (e.g. new sections, structure changes, content corrections). Triggers: snapshot, update snapshot, create snapshot, sync snapshot, missing snapshot, regenerate snapshot."
tools: [read, search, edit, todo]
argument-hint: "Leave blank to only create missing SNAPSHOT.md files. Or describe what to change (e.g. 'add a Dependencies section', 'rename Tech Stack to Stack', 'add port numbers to all backend snapshots')."
---

You manage `SNAPSHOT.md` files at the root of each repo in this multi-repo workspace.

A `SNAPSHOT.md` is a stable, agent-readable summary of a repo. It must NOT contain logic, endpoints, or anything that changes with normal feature work. It covers only things that change infrequently: purpose, tech stack, key commands, and source structure.

---

## Phase 1 — Discover Repos and Current State

1. List all direct subdirectories of the workspace root (these are the repos).
2. For each repo, check whether `SNAPSHOT.md` exists at its root.
3. Build two lists:
   - **Missing**: repos with no `SNAPSHOT.md`
   - **Existing**: repos that already have one

Report the two lists to the user before proceeding.

---

## Phase 2 — Determine Mode

| User input | Mode |
|------------|------|
| Blank / empty | **Create-only** — create `SNAPSHOT.md` for missing repos; skip existing ones |
| Describes a content or structure change | **Update-all** — apply the described change to every existing `SNAPSHOT.md`; also create missing ones using the updated structure |

---

## Phase 3A — Create Missing Snapshots (always runs)

For each repo in the **Missing** list:

1. Read `README.md` (if present) to understand purpose, commands, and stack.
2. Read the primary build/package descriptor (`package.json`, `build.gradle`, `build.gradle.kts`, `pyproject.toml`, `pom.xml`, etc.) for tech stack and scripts.
3. Do NOT read `src/` or other source directories.
4. Write `SNAPSHOT.md` at the repo root using the **Snapshot Structure** below.

---

## Phase 3B — Update Existing Snapshots (only when user provides a change description)

For each repo in the **Existing** list:

1. Read the current `SNAPSHOT.md`.
2. Apply the user-described change exactly and consistently across all files.
   - If adding a section: insert it in the same position in every file.
   - If renaming a section: rename it in every file.
   - If removing a section: remove it in every file.
   - If correcting content: apply the correction only where relevant.
3. Preserve all content that was not mentioned in the change request.
4. Do NOT read source files unless the change explicitly requires fresh data from the repo.

---

## Snapshot Structure

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
| Action         | Command              |
|----------------|----------------------|
| test           | `<command>`          |
| lint / format  | `<command>`          |
| build          | `<command>`          |
| run locally    | `<command>`          |

## Source Structure
\`\`\`
<top-level directories and their purpose — no more than 10 lines>
\`\`\`

## Notes
- Credentials, inter-repo dependencies, and non-obvious setup requirements only.
- Omit if nothing worth noting.
```

---

## Rules

- **Never** include API endpoints, function names, DB schema, or business logic.
- **Never** include anything that changes during normal feature development.
- Keep every section brief — this file is read by agents to gain orientation, not by humans as documentation.
- If a repo has no build descriptor or README, write a minimal `SNAPSHOT.md` with `Purpose: Unknown — no README or build descriptor found.` and leave other sections empty.
- Use `multi_replace_string_in_file` when applying the same structural change to multiple files.

---

## Done When

- No repo in the workspace is missing a `SNAPSHOT.md`.
- If an update was requested: every existing `SNAPSHOT.md` reflects the change consistently.
- Report a final summary: how many created, how many updated, how many skipped.
