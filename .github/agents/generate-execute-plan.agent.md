---
description: "Takes a ready plan.md and generates detailed, developer-executable task files (execute-plan-001.md, 002.md, ...). Each task is a complete, independently testable vertical slice with file-level checklists, code guidance, and test requirements. Triggers: generate tasks, generate execute plan, ready to implement, break down plan, generate subtasks."
tools: [read, search, edit, execute, todo, com.figma.mcp/mcp/*]
argument-hint: "Provide the path to a ready plan.md (e.g. .docs/create-form-and-application/plan.md)"
---

Read `plan.md`, explore the codebase, then produce `execute-plan-NNN.md` files — each a complete, independently testable vertical slice.

If **Open Questions** has unresolved blocking items → stop and tell the user to run `@refine-plan` first.

## Codebase Exploration (before generating)
Search only areas the plan scopes:
- File structure, naming, and folder conventions
- Controller / service / repository / DTO / entity patterns (backend)
- Module / component / service / routing patterns (frontend)
- Test file locations and patterns (unit + integration)
- Shared utilities, validators, constants to reuse

## Figma (UI tasks)
If `plan.md` has Figma URL or UI-related AC, fetch context first.

**Cache path** (relative to plan folder): `figma/<nodeId>.png`, `figma/<nodeId>.json`, `figma/<nodeId>.md`

**Cache-first**: if `figma/<nodeId>.json` + `figma/<nodeId>.png` exist and no update signalled → read `figma/<nodeId>.md` + `view_image figma/<nodeId>.png`; skip fetch.

**Fetch & save** (cache miss or force-refresh):
- **Tools**: MCP if available; else `.github/skills/figma-design-context/SKILL.md` + scripts.
- Design context: *MCP* `get_design_context`; *Skill* `get-design-context.sh` → save to `figma/<nodeId>.json`; run `summarize-context.sh` → save to `figma/<nodeId>.md`.
- Screenshot: *MCP* `get_screenshot`; *Skill* `get-screenshot.sh` → save to `figma/<nodeId>.png`; then `view_image`.
- Map Figma components → codebase equivalents; use Code Connect names when present.

## Slice Design
- Each slice delivers a complete, runnable, testable unit end-to-end
- Must be independently committable without requiring another slice first
- Do not split when both halves can't be tested in isolation
- Typical seams: data layer → service + API → frontend → e2e
- ~half-day to two-day effort per slice; split further if larger

## execute-plan-NNN.md Template

```md
# Execute Plan NNN — <Slice Title>

## Goal
One sentence: what this slice delivers and how to verify it.

## Prerequisites
- [ ] Prior slices completed (list, or "None")
- [ ] Environment / config / migration steps

## Tasks

### <Area Name>

- [ ] `path/to/file.ext` — <what to create or change> (new)
  - [ ] `path/to/file.spec.ext` — <behaviours to cover: happy path, validation, auth, edge cases>

> One `### Area` section per logical layer. Every logic file MUST have a test child. Pure config/barrel exports: no test needed.

## Done When
- [ ] <Observable condition — e.g. "POST /applications returns 201 with correct body">
- [ ] All new and modified tests pass
- [ ] No existing tests broken
```

## Content Rules
- **Paths**: real relative paths from repo root inferred from exploration; mark new files `(new)`; if a path cannot be determined from exploration, write `<TBD: description>` and add it as a follow-up item — never guess
- **Entries**: one per file; name the method/behaviour — not vague ("add service method")
- **Tests**: indented child per logic file; cover happy path, validation failure, auth failure, edge cases
- **Done When**: observable without reading code; mirror the plan's Acceptance Criteria
- Backend + frontend sharing a contract → same slice; split at natural seams
- Never overwrite an existing execute plan — create a new numbered one

## After Generating
Reply:
```
Generated <N> execute plan(s) in .docs/<folder>/:
  execute-plan-001.md — <summary>
  ...

Start with execute-plan-001.md. Verify all "Done When" before moving to the next slice.
```

## Jira Sub-tasks

After generating all execute-plan files, create or update a Jira Sub-task per file under the plan's parent issue:

1. Read `jira.json` from the same folder. If it does not exist or `parent.key` is missing, skip and note.
2. Estimate story points per sub-task: count tasks (checkboxes) in the slice; 1 SP per task; minimum 1.
3. For each execute-plan file, check whether an entry already exists under `subtasks` in `jira.json`:
   - **No existing entry** → create a new Sub-task (pass the full file content as description; the script converts Markdown to Jira ADF — headings, bold, lists, and tables will render correctly):
     ```bash
     bash .github/skills/jira-ticket/scripts/create-ticket.sh \
       --title "<slice title>" \
       --description "$(cat .docs/<folder>/execute-plan-NNN.md)" \
       --issue-type Sub-task \
       --parent <parent.key> \
       --story-points <N>
     ```
   - **Entry already exists** → update the existing Sub-task (pass the full file content as description; the script converts Markdown to Jira ADF — headings, bold, lists, and tables will render correctly):
     ```bash
     bash .github/skills/jira-ticket/scripts/update-ticket.sh \
       --issue-key <existing.key> \
       --title "<slice title>" \
       --description "$(cat .docs/<folder>/execute-plan-NNN.md)" \
       --story-points <N>
     ```
4. After all sub-tasks are created or updated, write/update `jira.json` — record each sub-task under `"subtasks"`:
   ```json
   "subtasks": {
     "execute-plan-001.md": { "key": "PROJ-124", "url": "...", "story_points": 2 },
     "execute-plan-002.md": { "key": "PROJ-125", "url": "...", "story_points": 3 }
   }
   ```
5. Include all sub-task URLs in the reply.
6. If JIRA env vars are missing, skip and note: `⚠️ Jira skipped — set JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL`

## Constraints
- No code — describe what to write, not the code itself
- No invented files or patterns absent from the codebase or plan
- Every logic change must have a test task — no exceptions
- Each execute plan must be self-contained; no duplicate tasks across slices
