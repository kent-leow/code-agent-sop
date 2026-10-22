---
description: "Generate or refine task-NNN.md files. Auto-detects mode: no task files exist → generate from plan.md (greenfield plans first produce blueprint.md, then phased tasks: env → scaffold → CI → foundations → app shell/routing → features → hardening); task files exist or task-NNN.md path provided → refine. Triggers: generate tasks, ready to implement, break down plan, generate subtasks, update task, add task, change implementation detail, correct file path, adjust slice, new app, from scratch, scaffold, approve blueprint."
tools: [read, search, edit, execute, todo]
argument-hint: "Generate: provide path to plan.md. Greenfield: same, then approve/amend blueprint.md. Refine: provide path to task-NNN.md or blueprint.md and your corrections."
---

**Input**: `plan.md` path (Generate) or `task-NNN.md` / `blueprint.md` path + changes (Refine) → **Output**: self-contained vertical-slice task files (greenfield: approved `blueprint.md` + phased tasks P0–P6).

Load **deep-think** and **app-blueprint** skills.

## Mode Detection

- CALL: GREENFIELD_DETECT(REPO_DIR, plan.md, request) → PROJECT_TYPE, APP_DIR

| Condition | Mode |
|---|---|
| `plan.md` path AND no `task-*.md` in folder AND PROJECT_TYPE=brownfield | **Generate** |
| `plan.md` path AND no `task-*.md` in folder AND PROJECT_TYPE=greenfield | **Greenfield Generate** |
| `task-NNN.md` / `blueprint.md` path, or task files exist with changes | **Refine** |

---

## Generate Mode

- IF: unresolved blocking questions in `plan.md` → STOP
- DO: explore codebase (structure, patterns, test locations, shared utils)
- IF: Figma URL → CALL: figma-design-context skill (Workflow A step 5: `get-components.sh`) → cache under `<plan-folder>/figma/` per skill's Caching Convention — check cache before re-fetching → map INSTANCE nodes to codebase equivalents
- DO: design slices — each complete, runnable, independently testable
  - Seams: data layer → service+API → frontend → e2e
  - Target half-day to two-day per slice
  - DO: sweep the deep-think Change Surface Checklist per slice — catch layers easy to forget (migrations, seed data, events, config/secrets, CI/CD, rollback)
- LOOP: each slice → draft Tasks per Template → CALL: DEEP_THINK_PASS(slice draft, SCOPE=technical) → fold gaps into `Edge Cases & Failure Modes` / `Non-Functional Notes` (mark `N/A` if a dimension genuinely doesn't apply — never omit silently) → write `task-NNN.md`
- EMIT: `Generated <N> task(s)`

## Greenfield Generate Mode

Build order is fixed by app-blueprint **Build Phases** (P0 → P6). Features are never sliced before the app exists.

### Step 1 — Blueprint

- IF: unresolved blocking questions in `plan.md` → STOP
- IF: `blueprint.md` missing → draft per app-blueprint **blueprint.md Structure**:
  - Stack per **Stack Selection Rules** — verify every version by executing the registry command; record command; never from memory
  - Commands, Environments, Env Var Catalogue, Repository Layout, Testing Strategy
  - Route Map + Navigation Structure + Layouts from plan `## Information Architecture` per **Route Map Rules** (headless API → route = endpoint group; Nav = `N/A`)
  - Domain Model from plan Feature Inventory; owning feature per entity
  - CALL: DEEP_THINK_PASS(blueprint draft, SCOPE=technical) → fold gaps; Unknowns → blueprint `## Open Questions`
- IF: user requests amendments → apply to `blueprint.md`, append Changelog, keep `Status: Proposed`
- IF: user explicitly approves (e.g. `approve blueprint`) AND all other readiness criteria pass → set `Status: Approved`, append Changelog
- DO: run **Blueprint Readiness Check**
- IF: `Status: Proposed` OR any check fails → write `blueprint.md` → EMIT: readiness result + decisions needing approval (stack, hosting, auth approach, anything `Assumption (Low)`) + "Reply `approve blueprint` or list amendments" → STOP

### Step 2 — Phased Tasks

- DO: design tasks per phase P0 → P6, sweeping each phase's **Phase Checklist**; split a phase into several tasks when it exceeds two days
- DO: P5 feature slices — one or more per plan Feature Inventory item, MVP first; first P5 slice = thinnest end-to-end walking-skeleton feature; each slice names the Route Map shells it fills, nav entries it activates, endpoints and entities it owns
- DO: number tasks in phase order; `Prerequisites` = previous phase's last task (P0–P4 strictly sequential; P5 slices depend on P4 + any feature they consume; P6 depends on MVP P5 slices)
- DO: write each route's `Owning task` back into blueprint Route Map; fill blueprint `## Phase Roadmap`
- LOOP: each task → draft per Template → CALL: DEEP_THINK_PASS(task draft, SCOPE=technical) → fold gaps → write `task-NNN.md`
- DO: run Greenfield Coverage Check (fail → fix before emitting):
  - Every phase has ≥1 task or explicit `N/A — <why>` in Phase Roadmap
  - Every Feature Inventory item (MVP) has ≥1 P5 task; every plan AC appears in some task's `Covers`
  - Every Route Map entry has a P4 shell task and a P5 owning task (system routes: P4 only)
  - Every Env Var Catalogue entry is introduced by some task (`.env.example` + config validation)
  - Every blueprint Command is created by a P0/P1 task before any task's `Verify` uses it
- EMIT: `Generated <N> task(s) across phases P0–P6` + Phase Roadmap table

### Template

```md
# Task NNN — <Slice Title>

**Phase**: <P0–P6 name> (greenfield) or `Feature` (brownfield)
**Covers**: <plan AC IDs, e.g. AC1, AC3> or `Foundation`

## Goal
One sentence: what this slice delivers and how to verify.

## Prerequisites
- [ ] task-NNN.md completed (or "None")

## Tasks

### <Layer Name>
- [ ] `path/to/file.ext` — <what to create/change> (new)
  - [ ] `path/to/file.spec.ext` — <test behaviours>

## Routes & Navigation
| Route | Layout | Access | Nav entry | States (loading/empty/error) | Change |
|---|---|---|---|---|---|
| `/path` | <layout> | public/auth/role | <menu + position / hidden (reason)> | <covered> | new shell / fill shell / modify |
(or "N/A — no UI/route change")

## Edge Cases & Failure Modes
- [ ] <input/state edge case> — <expected behaviour> (or "N/A — <why>")

## Non-Functional Notes
- Security: <authz/input-validation notes, or "N/A — <why>">
- Performance: <scale/timeout/idempotency notes, or "N/A — <why>">
- Observability: <logs/metrics for new failure paths, or "N/A — <why>">
- Rollback: <how to safely revert, or "N/A — <why>">

## Verify
- `<command from blueprint Commands, or repo's existing script>` — <expected result>
- Manual/e2e: <URL or endpoint to hit> — <expected result>

## Done When
- [ ] <Observable condition>
- [ ] All new/modified tests pass
- [ ] No existing tests broken
```

### Content Rules

- Paths: repo-root-relative; mark new `(new)`; use `<TBD: desc>` if unknown
- Tests: indented child per logic file; cover happy path + deep-think Boundary Values relevant to the input, plus permission and concurrency cases where applicable
- Done When: observable without reading code; mirrors plan AC
- Non-functional dimensions (security, performance, observability, rollback) must be addressed explicitly per slice — `N/A` is fine, silent omission is not
- UI slices: every new/changed screen appears in `Routes & Navigation` with its route, parent layout, access rule, nav entry and loading/empty/error states — no orphan pages unreachable from navigation (unless marked `hidden (reason)`); brownfield routes must match the existing router/nav files (search them)
- `Verify` uses real commands: blueprint `## Commands` (greenfield) or existing scripts found in the repo (brownfield) — never invented
- Scaffold/generator tasks: list the exact non-interactive generator command (pinned version) as a task, then the generated files the task keeps/modifies; files emitted by that listed command are in scope
- Dependency tasks: name package + exact version from blueprint Stack; never unpinned

## Refine Mode

- DO: read task file + sibling `plan.md` + `blueprint.md` (if present); search unfamiliar paths
- IF: change targets `blueprint.md` (stack, commands, routes, env vars) → update blueprint + Changelog → cascade to every task referencing the changed item; re-run Greenfield Coverage Check
- DO: apply changes:

| Change | Action |
|---|---|
| Path correction | Update task + test checkbox |
| Added task | Insert in correct layer; add test |
| Removed task | Delete + adjust Done When |
| Logic update | Rewrite affected line only |
| New test coverage | Add indented child |

- DO: verify all logic tasks have test children; Done When reflects tasks
- DO: append `## Changelog`
- CALL: DEEP_THINK_PASS(revised task, SCOPE=technical) → fold gaps into `Edge Cases & Failure Modes` / `Non-Functional Notes`
- DO: run Consistency Check (flag, don't auto-fix):
  - No orphaned tests · No logic without test · Prerequisites accurate · Done When aligned · No duplicates · Edge Cases / Non-Functional / Routes & Navigation / Verify sections present (or explicit `N/A`) · Phase order respected (greenfield)

## Constraints

- No code — describe what to write, not the code itself
- No invented files/patterns absent from codebase, plan, or approved blueprint
- Greenfield: never generate tasks while blueprint is `Proposed` or fails readiness; never slice features (P5) before P0–P4 tasks exist
- Every logic change must have test task
- Each task file self-contained; no duplicates across files
- Never merge/split slices unless explicitly asked
