---
name: docs-folder
description: "Shared .docs/ work-folder resolver + naming convention: one folder per ticket/topic holding every artefact (plan, spike, blueprint, tasks, fixes, investigations, checklists, vulnerability reports, figma cache). gobiz profile requires a Jira key in the folder name. Load from every agent that writes under .docs/."
---

# docs-folder

**PROFILE: gobiz**

> `gobiz` = Jira key required in folder name. `general` = plain kebab title. broadcast-sync rewrites this line to `general` for `general/` destinations — never edit it by hand in destinations.

## Naming Convention

| Profile | Pattern | Example |
|---|---|---|
| gobiz | `.docs/<JIRA-KEY>-<kebab-title>/` | `.docs/GOBIZWKST2-324-create-form-and-application/` |
| general | `.docs/<kebab-title>/` | `.docs/create-form-and-application/` |

| Part | Rule |
|---|---|
| `JIRA-KEY` | Full Jira key, any project, uppercase as issued — regex `[A-Z][A-Z0-9]+-[0-9]+` (e.g. `GOBIZWKST2-324`, `MOLBLT-7759`) |
| `kebab-title` | `[a-z0-9]+(-[a-z0-9]+)*`, ≤ 6 words, ≤ 50 chars; from Jira summary (gobiz, when known) else from the request; drop filler words (`the`, `a`, `to`, `for`) |
| gobiz folder regex | `^[A-Z][A-Z0-9]+-[0-9]+-[a-z0-9]+(-[a-z0-9]+)*$` |

- One folder per ticket (gobiz) / per topic (general) — never two folders sharing a Jira key
- Every artefact for that ticket lives inside it (see Folder Layout) — never create standalone `.docs/fix-*`, `.docs/investigation-*`, `.docs/.vulnerability/` folders

## Folder Layout

```
.docs/<folder>/
├── plan.md                                # generate-plan
├── spike.md, spike-report.md              # spike-plan
├── blueprint.md                           # generate-task (greenfield)
├── jira.json                              # Jira story + sub-task keys
├── task-NNN.md                            # generate-task / execute-task
├── figma/                                 # figma-design-context cache
├── fixes/fix-{YYYYMMDD-HHMMSS}-{name}.md  # fix-task (one per issue batch)
├── investigation-<kebab-topic>/           # investigate → report.md, flowchart.mmd
├── investigation-<identifier>/            # investigate-apex → apex-report.md
├── cft-checklist[-<agency>].md            # cft-onboarding (suffix only when >1 agency)
└── vulnerability/vulnerabilities-{YYYYMMDD}.md  # fix-vulnerabilities
```

## DOCS_FOLDER

**Inputs:** `REQUEST` (raw text), `PATH` (optional — any file/folder under `.docs/`), `TICKET` (optional Jira key), `TITLE` (optional), `CAN_CREATE_JIRA` (default `false`) → **Outputs:** `DOCS_DIR`, `JIRA_KEY` (gobiz only)

1. IF: `PATH` given → STORE `DOCS_DIR` = its top-level `.docs/<name>/` → validate name against PROFILE:
   - Valid → step 6
   - gobiz AND name lacks a key (legacy) → resolve key via step 2 → STOP: ask user to confirm rename `<name>` → `<KEY>-<name>`; on confirm `git mv` (tracked) or `mv` (untracked) → EMIT old → new path; on decline → continue with legacy path and EMIT warning
2. gobiz — resolve `JIRA_KEY` (first hit):
   - `TICKET` → key regex or `/browse/<KEY>` URL in `REQUEST` → `jira.json` `.parent.key` in `PATH`'s folder
   - None → STOP: ask `Jira key for this work?` — IF `CAN_CREATE_JIRA` → also offer `create`: load **jira-ticket** skill → create Story (summary = title, description = request summary) → use returned key → write `jira.json` per jira-ticket Persist State
   - Validate against key regex; invalid → re-ask (never invent a key)
3. gobiz — glob `.docs/<JIRA_KEY>-*/`:
   - 1 hit → reuse as `DOCS_DIR` (keep existing title) → step 6
   - >1 hit → STOP: ask which to use (never merge silently)
   - 0 hits → step 4
4. Title: `TITLE` → Jira summary (when already fetched by caller) → derive from `REQUEST` → kebab per Naming Convention
5. STORE: `DOCS_DIR` = `.docs/<JIRA_KEY>-<kebab-title>/` (gobiz) or `.docs/<kebab-title>/` (general)
   - general AND folder exists with unrelated content → STOP: ask reuse or new title
6. DO: `mkdir -p "${DOCS_DIR}"`
   - gobiz AND no `jira.json` → write `{ "parent": { "key": "<JIRA_KEY>", "url": "${JIRA_BASE_URL}/browse/<JIRA_KEY>" } }` (omit `url` if `JIRA_BASE_URL` unset)
7. EMIT: `DOCS_DIR` (and `JIRA_KEY`)

## Constraints

- Never invent a Jira key or reuse one from unrelated work (no guessing from current branch)
- Never write `.docs/` artefacts outside `DOCS_DIR`
- Never rename/move a folder without user confirmation
- Callers that are read-only towards Jira (e.g. cft-onboarding) pass `CAN_CREATE_JIRA=false`
