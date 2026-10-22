---
name: app-blueprint
description: "Shared greenfield framework for building an app from scratch: detects greenfield, defines blueprint.md (stack, environments, env vars, commands, route map, navigation), and the phased build order (env → scaffold → CI → foundations → app shell/routing → features → hardening). Load from generate-plan, generate-task, execute-task."
---

# app-blueprint

> Greenfield = no running app exists yet. Features cannot be sliced until the environment, backbone, delivery pipeline and app shell exist. This skill defines that order and the `blueprint.md` contract every downstream agent reads.

## GREENFIELD_DETECT

**Inputs:** `REPO_DIR`, `PLAN` (optional), `REQUEST` → **Outputs:** `PROJECT_TYPE` (`greenfield` | `brownfield`), `APP_DIR`

| Signal (first hit wins) | Result |
|---|---|
| `plan.md` contains `**Project Type**: Greenfield` | greenfield |
| `plan.md` contains `**Project Type**: Brownfield` | brownfield |
| `REQUEST` asks for a new app/service/product "from scratch" | greenfield |
| `REPO_DIR` (or target sub-folder) has no app manifest (`package.json`, `pyproject.toml`, `requirements.txt`, `go.mod`, `pom.xml`, `build.gradle*`, `Cargo.toml`, `*.csproj`, `Gemfile`, `composer.json`, `pubspec.yaml`) and no source dirs | greenfield |
| Otherwise | brownfield |

- New app inside an existing monorepo/workspace → greenfield for `APP_DIR` only; reuse workspace-level tooling (package manager, lint config, CI) instead of re-creating it — read it first.
- STORE: `APP_DIR` = repo root, or the sub-folder the new app lives in.

---

## Build Phases

Every greenfield app is built in this order. Each phase = ≥1 `task-NNN.md`; each phase's exit gate must pass before the next phase's tasks start (enforced via `Prerequisites`).

| Phase | Name | Delivers | Exit gate (observable) |
|---|---|---|---|
| P0 | Environment & Toolchain | Runtime pins, package manager, repo hygiene, lint/format/typecheck, env template, setup docs | Fresh clone → documented setup → `install`, `lint`, `typecheck` pass |
| P1 | Backbone Scaffold | Framework init via official generator, folder structure, config loader + validation, logger, error-handling base, health/readiness, test harness (unit + e2e) with smoke tests, local deps (DB/cache via containers), migration tooling | `dev` boots; health check OK; `test` + `e2e` smoke pass |
| P2 | Delivery Pipeline | CI running every quality gate, build artifact, (if in scope) deploy of the skeleton to the first non-local environment | CI green on the skeleton; deployed URL responds (or `N/A — <why>`) |
| P3 | Cross-cutting Foundations | Design tokens + base UI components, data-access layer / API client, state management, auth & session (if in scope), i18n/a11y baseline, shared error/empty/loading components | Each foundation has tests; consumed by ≥1 smoke usage |
| P4 | App Shell, Routing & Navigation | Root layout(s), main page, every route from the Route Map as a route shell, primary/secondary nav, user menu, breadcrumbs, guards/redirects, 404 / error / unauthorised pages | e2e visits every route; nav links resolve; guards redirect; deep-link refresh works |
| P5 | Features | Vertical feature slices that fill route shells; first slice = thinnest end-to-end "walking skeleton" feature | Per-slice Done When; plan AC covered |
| P6 | Hardening & Release | Security headers/CSP, rate limits, performance budget, observability (metrics/alerts/dashboards), backups, a11y audit, runbook, release checklist | Release checklist all green or explicitly deferred with owner |

Rules:
- Order is fixed; a phase may be `N/A — <why>` (e.g. P4 for a headless API — then P4 = API routing/versioning/OpenAPI shell) but never silently skipped.
- Keep the app runnable after every task — no task may leave `dev`/`build`/`test` broken.
- Phases P0–P4 are technical and carry no plan AC; tag them `**Covers**: Foundation`.

### Phase Checklists

Sweep the relevant list when drafting each phase's tasks; mark `N/A — <why>`, never omit.

| Phase | Checklist |
|---|---|
| P0 | runtime version file (`.nvmrc` / `.tool-versions` / `.python-version` …) · package manager + lockfile · `.gitignore` · `.editorconfig` · formatter · linter · typechecker · pre-commit hooks · `.env.example` (from Env Var Catalogue) · `README` setup section · license (if stated) |
| P1 | generator command (non-interactive, pinned version) · folder layout per blueprint · config module validating required env vars at boot (fail fast) · structured logger · global error handler + error envelope · health/readiness endpoint · unit test runner · e2e runner · smoke tests · container compose for local deps · DB connection + migration tool + first migration · seed script |
| P2 | CI workflow: install (cached) → lint → typecheck → test → build → e2e · branch protection notes · build artifact/image · secrets injection strategy · deploy target + env config · dependency/CVE audit step |
| P3 | design tokens (colour, type, spacing, radius, breakpoints) · base components (button, input, form field, modal, toast, table/list, skeleton) · layout primitives · API client (base URL from config, auth header, error mapping, timeout, retry policy) · state/query cache · auth provider + session storage + token refresh (if in scope) · i18n setup · a11y lint rules |
| P4 | root layout · authenticated vs public layouts · main/home page · every Route Map entry as a shell · nav (primary, secondary, user menu, mobile) · active-link state · breadcrumbs · route guards + redirect-after-login · 404 · error boundary page · unauthorised page · loading states per route · page titles/meta · deep-link refresh |
| P6 | security headers/CSP/CORS · rate limiting · input size limits · perf budget + measurement · caching headers · metrics + alerts + dashboard · log retention/PII scrub · backups/restore test · a11y audit · runbook · release/rollback checklist · versioning/changelog |

---

## Stack Selection Rules

- User-stated stack/hosting/constraints in `plan.md` always win — record as `Known fact`.
- Anything unstated → propose one option with rationale + rejected alternatives; log as `Assumption (Low)`; set blueprint `Status: Proposed` → requires user approval before tasks are generated.
- Versions: never from memory. Verify the current stable/LTS version with the ecosystem's registry command (e.g. `npm view <pkg> version`, `pip index versions <pkg>`, `go list -m -versions <mod>`, Maven Central search) or official docs; record the exact version and the command used; pin exactly.
- Run the ecosystem's vulnerability check for every chosen dependency (`npm audit`, `pip-audit`, `osv-scanner`, …) once installed; record findings.
- Prefer the framework's official generator over hand-written boilerplate; record the exact non-interactive command with all flags.
- Minimise dependencies — each one needs a one-line justification in the Stack table.

## Route Map Rules (UI apps)

- Every screen in `plan.md` `## Information Architecture` appears exactly once in the Route Map.
- Every route has: path, page name, layout, access (public | authenticated | role), nav placement, owning task.
- System routes are mandatory: `/` (main page), 404, error, unauthorised (if any guarded route), login/logout (if auth in scope).
- A route shell (layout + page title + heading + empty state) created in P4 is **not** a placeholder violation — it is legitimate only while the Route Map names the P5 task that fills it. A shell with no owning task is a gap.
- Nav structure and Route Map must agree: no nav link to a missing route; no reachable route missing from nav unless marked `hidden (reason)`.

---

## blueprint.md Structure

Lives at `.docs/<plan-folder>/blueprint.md`. Single source of truth for technical decisions; `plan.md` stays business-only.

```md
# Blueprint — <App Name>

**Status**: Proposed | Approved
**App Dir**: <repo-root-relative path>
**Plan**: ./plan.md

## Stack
| Layer | Choice | Version (verified) | Verified via | Rationale | Rejected alternatives |

## Repository Layout
<tree of top-level folders with one-line purpose each>

## Environments
| Env | Purpose | URL | Config source | Data |
|-----|---------|-----|---------------|------|
| local | dev | http://localhost:<port> | `.env` | seed |

## Env Var Catalogue
| Name | Required | Default | Secret | Used by | Description |

## Commands
| Purpose | Command |
|---|---|
| install | |
| dev | |
| build | |
| lint | |
| format | |
| typecheck | |
| test | |
| e2e | |
| migrate | |
| seed | |

## Route Map
| Path | Page | Layout | Access | Nav placement | Data deps | Owning task |

## Navigation Structure
- Primary: ...
- Secondary / user menu: ...
- Breadcrumb rules: ...

## Layouts
| Layout | Used by | Regions (header/sidebar/footer) |

## Domain Model
| Entity | Key fields | Relations | Owning feature |

## API Conventions
Base path · versioning · auth · error envelope · pagination · validation · idempotency

## Cross-cutting Conventions
Folder-per-feature rule · naming · config access · logging fields · error codes · i18n keys

## Testing Strategy
| Level | Tool | Location | What it covers | Gate |

## Phase Roadmap
| Phase | Task files | Exit gate |

## Decisions
| # | Decision | Why | Date |

## Assumptions
| # | Assumption | Confidence |

## Open Questions
| # | Question | Impact if unresolved |

## Changelog
- YYYY-MM-DD: <summary>
```

### Blueprint Readiness Check

| Criterion | Pass if |
|---|---|
| Stack resolved | Every layer has a choice + verified version, or `N/A` |
| Commands defined | install/dev/build/lint/typecheck/test present (others or `N/A`) |
| Env vars catalogued | Every config value referenced anywhere is listed |
| Route Map complete | Every plan IA screen mapped; system routes present; every route owned |
| Nav consistent | Nav ↔ Route Map agree |
| No blocking questions | Open Questions all non-blocking |
| Approved | `Status: Approved` (set by user or on explicit user approval) |

- All pass → `✅ Blueprint ready` · Any fail → `⚠️ Blueprint gaps: [criteria]` → do not generate tasks.
