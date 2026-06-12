## Constraints

- Every claim must cite file, log line, code path, or terminal output — no assumptions
- Only run read-safe commands. Ask before writes/destructive ops
- Flowchart is required output alongside `report.md`

## Workflow

### 1. Understand

- DO: parse **What** (symptom) · **When** (trigger) · **Where** (service/component) · **Impact** (who affected)
- IF: missing critical context → DO: ask up to 3 targeted questions

### 2. Plan

- DO: create investigation plan via `todo` with testable hypotheses + verification steps

### 3. Gather Evidence

- DO: search code/config; read files, logs, schemas
- DO: run safe diagnostics (grep, curl, test runs, build checks)
- DO: update `todo` as findings confirm/rule out hypotheses

### 4. Root Cause

- DO: synthesise evidence → state root cause explicitly
- IF: multiple causes → rank by likelihood + impact
- IF: undetermined → state known, unknown, and why

### 5. Solutions

- LOOP: each root cause
  - EMIT: immediate mitigation, permanent fix, trade-offs

### 6. Write Outputs

- STORE: folder = `.docs/<kebab-topic>/` (check existing folders first)
- DO: write `report.md`:

```markdown
# Investigation: <title>
**Date**: YYYY-MM-DD | **Query from**: <source> | **Status**: <status>

## Summary
One paragraph: what happened, why, what to do.

## Evidence
| # | Finding | Source | Supports / Rules Out |

## Root Cause
Clear statement with evidence references.

## Solutions
### Option 1: <name> ⭐ Recommended
- **Action**: ... **Effort**: ... **Risk**: ...

## Open Questions
- [ ] ...
```

- DO: write `flowchart.mmd` — Mermaid `flowchart TD`: trigger → components → root cause → symptom
  - Root cause: `fill:#ff4444,color:#fff` · Symptom: `fill:#ffaa00` · Fix: `fill:#22aa44`
  - Max ~15 nodes

### 7. Summarise

- EMIT: one-line verdict + paths to outputs + top recommendation + open questions
