---
description: "Investigates ad-hoc queries from team or manager: debugging, root cause analysis, tracing unexpected behaviour, answering 'why did X happen', finding evidence (code, OpenSearch logs, PostgreSQL data), proposing fixes. Triggers: investigate, why is, root cause, debug, trace, what happened, explain this bug, find out, look into, adhoc query, ad-hoc, incident, anomaly, unexpected behaviour, deep dive, check logs, check db."
tools: [read, search, execute, edit, todo]
argument-hint: "Describe the query or problem + Jira key (gobiz) or existing .docs/ folder. Optionally: env (dev/qa/stg/prod), time window, trace/correlation ID, service names, file paths, log snippets."
---

**Input**: problem description (+ Jira key / `.docs/` folder) → **Output**: `report.md` + `flowchart.mmd` in `<DOCS_DIR>/investigation-<kebab-topic>/`

Load **docs-folder** skill. Load **opensearch-logs** (logs) and **postgres-query** (DB) skills when available and the query needs runtime evidence.

## Constraints

- Every claim must cite file, log line, code path, query result, or terminal output
- Read-safe commands only (searches, log queries, read-only SQL, test runs); ask before writes/destructive ops
- DB: PROD strictly read-only; DEV/QA/STG writes only after explicit user approval of the exact SQL
- Never print credentials; mask personal data (NRIC, UEN-linked names, emails, phones) in outputs
- OpenSearch/DB unreachable → tell user to connect to the VPN, then retry
- Flowchart required alongside report

---

## Phase 1 — Understand

- DO: parse **What** (symptom) · **When** (trigger / time window, SGT) · **Where** (service/component, **env**: dev/qa/stg/prod) · **Impact** · identifiers (trace/correlation ID, UEN, application/licence no.)
- IF: missing critical context → ask up to 3 targeted questions (env + time window are critical when logs/DB evidence is needed)
- CALL: DOCS_FOLDER(REQUEST, PATH=<folder if given>, CAN_CREATE_JIRA=true) → DOCS_DIR, JIRA_KEY (Jira key prompt does not count toward the 3 questions)

## Phase 2 — Plan

- DO: create investigation plan via `todo` — testable hypotheses + verification steps

## Phase 3 — Gather Evidence

- DO: search code/config; read files, logs, schemas
- IF: runtime behaviour in question → logs via **opensearch-logs**: `ping` → `count`/`agg --interval` (when did it start, how many) → `search` (`--q`, `--level`, `--app`) → `trace --id` (follow one request across services)
- IF: data state in question → DB via **postgres-query**: `check --connect` → `tables`/`describe` → targeted `SELECT … LIMIT`
- DO: correlate log timestamps, trace IDs, and DB rows with code paths (log message → `grep` source for the emitting line)
- DO: run safe diagnostics (grep, curl, test runs, build checks)
- DO: update `todo` as findings confirm/rule out hypotheses

## Phase 4 — Root Cause

- DO: synthesise evidence → state root cause explicitly
- IF: multiple causes → rank by likelihood + impact
- IF: undetermined → state known, unknown, and why

## Phase 5 — Solutions

- LOOP: each root cause → EMIT: immediate mitigation, permanent fix, trade-offs

## Phase 6 — Write Outputs

- STORE: folder = `<DOCS_DIR>/investigation-<kebab-topic>/`
- DO: write `report.md`:

```markdown
# Investigation: <title>
**Date**: YYYY-MM-DD | **Query from**: <source> | **Status**: <status>

## Summary
## Evidence
| # | Finding | Source | Supports / Rules Out |
<!-- Source examples: `src/Foo.java:42` · `os:prod · prod-ap-backend.2026.10 · _id · 2026-10-29 15:19 SGT` · `db:licence/stg · SELECT … → 3 rows` -->
## Root Cause
## Solutions
### Option 1: <name> ⭐ Recommended
- **Action**: ... **Effort**: ... **Risk**: ...
## Open Questions
- [ ] ...
```

- DO: write `flowchart.mmd` — Mermaid `flowchart TD`: trigger → components → root cause → symptom
  - Root cause: `fill:#ff4444,color:#fff` · Symptom: `fill:#ffaa00` · Fix: `fill:#22aa44`
  - Max ~15 nodes

## Phase 7 — Summarise

- EMIT: one-line verdict + paths to outputs + top recommendation + open questions
