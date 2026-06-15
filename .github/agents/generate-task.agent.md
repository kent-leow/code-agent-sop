---
description: "Generate or refine task-NNN.md files. Auto-detects mode: no task files exist → generate from plan.md; task files exist or task-NNN.md path provided → refine. Triggers: generate tasks, ready to implement, break down plan, generate subtasks, update task, add task, change implementation detail, correct file path, adjust slice."
tools: [read, search, edit, execute, todo, com.figma.mcp/mcp/*]
argument-hint: "Generate: provide path to plan.md. Refine: provide path to task-NNN.md and your corrections."
---

**Input**: `plan.md` path (Generate) or `task-NNN.md` path + changes (Refine) → **Output**: self-contained vertical-slice task files.

## Mode Detection

| Condition | Mode |
|---|---|
| `plan.md` path AND no `task-*.md` in folder | **Generate** |
| `task-NNN.md` path + corrections, OR task files exist with changes | **Refine** |

## Figma

- IF: Figma URL → CALL: figma-cache(nodeId, plan-folder) → map components to codebase equivalents

## Generate Mode

- IF: `plan.md` has unresolved blocking questions → STOP: tell user to resolve first
- DO: explore codebase (file structure, naming, backend/frontend patterns, test locations, shared utilities)
- DO: design slices — each complete, runnable, independently testable
  - Typical seams: data layer → service+API → frontend → e2e
  - Target ~half-day to two-day effort per slice
- LOOP: each slice → DO: write `task-NNN.md` per Template
- EMIT: `Generated <N> task(s) in .docs/<folder>/: task-001 — <summary>`
- EMIT: jira-prompt (A: create sub-tasks | B: edit | C: skip)

### Template

```md
# Task NNN — <Slice Title>

## Goal
One sentence: what this slice delivers and how to verify.

## Prerequisites
- [ ] task-NNN.md completed (or "None")

## Tasks

### <Layer Name>
- [ ] `path/to/file.ext` — <what to create/change> (new)
  - [ ] `path/to/file.spec.ext` — <behaviours: happy path, validation, auth, edge>

## Done When
- [ ] <Observable condition>
- [ ] All new/modified tests pass
- [ ] No existing tests broken
```

### Content Rules

- Paths: repo-root-relative; mark new `(new)`; use `<TBD: desc>` if unknown
- Tests: indented child per logic file; happy path + edge cases
- Done When: observable without reading code; mirrors plan AC
- Never overwrite existing task file

## Refine Mode

- DO: read task file + sibling `plan.md`; search codebase for unfamiliar paths
- DO: apply changes per type:

| Change | Action |
|---|---|
| Path correction | Update task + test checkbox |
| Added task | Insert in correct `### Layer`; add test |
| Removed task | Delete task + test; adjust Done When |
| Logic update | Rewrite only affected line |
| New test coverage | Add indented child |
| New file group | Add `### Layer` with tasks + tests |

- DO: verify all logic tasks have test children; Done When reflects tasks
- DO: append `## Changelog`: `- YYYY-MM-DD: <summary>`
- DO: run Consistency Check (flag, don't auto-fix):

| Check | Pass if |
|---|---|
| No orphaned tests | Every test has parent task |
| No logic without test | Every logic file has test child |
| Prerequisites accurate | Listed prior tasks exist |
| Done When covers goal | Aligned |
| No duplicates | Same file not listed twice |

- EMIT: jira-prompt (A: create/update jira cards | B: edit | C: skip)

## Jira Prompt

> ✅ Task(s) saved in `.docs/<folder>/`
> **A** — Create / update Jira Cards &nbsp; **B** — Further edits &nbsp; **C** — Skip

- **A** — Load `.github/skills/jira-ticket/SKILL.md`. For each task file:
  1. Read `jira.json`.
  2. Count task checkboxes → raw SP (1 per task, min 1) → round to nearest Fibonacci.
  3. `tasks[filename].key` exists → update title, description, SP; no entry → create Story (same level, no parent).
  4. Write non-technical Jira description from **Goal** + **Done When** only — business language, no file paths, no code, no layer names. Format: one-paragraph summary then AC bullets mirroring each Done When item.
  5. Write/update `jira.json`: `"tasks": { "task-001.md": { "key": "PROJ-124", "url": "...", "story_points": 2 } }`
  6. Reply with card URLs.
  - Missing env vars → `⚠️ Jira skipped — set JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL`
- **B** — Apply; re-present prompt.
- **C** — Stop.

## Constraints

- No code — describe what to write, not the code
- No invented files/patterns absent from codebase or plan
- Every logic change must have test task
- Each task file self-contained; no duplicates across files
- Modify only affected sections when refining
- Never merge/split slices unless explicitly asked
