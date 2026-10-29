---
name: postgres-query
description: "Query MOLB / GoBusiness PostgreSQL databases (licence, agency-portal, formbuilder, onboarding-portal) in dev, qa, stg, prod via psql: list tables, describe columns, run SQL to verify data state as investigation evidence. PROD is strictly read-only; DEV/QA/STG writes only with --write after explicit user approval. Requires DB_<DB>_<ENV>_{HOST,PORT,NAME,USER,PASSWORD,ROLE} in ~/.zshenv and VPN. Use when: check db, query database, data issue, record state, verify row, sql, postgres, dbeaver."
argument-hint: "db (licence|agency-portal|formbuilder|onboarding-portal) + env (dev|qa|stg|prod) + what to verify"
metadata:
  category: operations
  tier: standard
  status: active
  invocation: explicit
---

# Postgres Query

**Input**: db + env + question → **Output**: query results (aligned or CSV) used as cited evidence.

## Credentials (`~/.zshenv`)

`DB_<DB>_<ENV>_<FIELD>` — filled by the user from DBeaver; never print values.

| Part | Values |
|---|---|
| `<DB>` | `LICENCE` · `AGENCY_PORTAL` · `FORMBUILDER` · `ONBOARDING_PORTAL` |
| `<ENV>` | `DEV` · `QA` · `STG` · `PROD` |
| `<FIELD>` | `HOST` · `PORT` (default 5432) · `NAME` (database) · `USER` · `PASSWORD` · `ROLE` (session role, optional) |

Placeholder block: `python3 $S/pg_query.py env-template`. CLI aliases: `licence`/`ls` · `agency-portal`/`ap` · `formbuilder`/`fb` · `onboarding-portal`/`op`; `stg`/`staging`.

| Env | Access |
|---|---|
| DEV · QA · STG | read (default) · write only with `--write` **after explicit user approval** |
| PROD | read-only — enforced (`BEGIN READ ONLY` + client-side SQL screen); `--write` refused |

## Scripts

`S=.github/skills/postgres-query/scripts` — Python 3 wrapper over `psql` (`brew install libpq` if missing). Errors → `ERROR:` on stderr, non-zero exit; the password is passed via `PGPASSWORD`, never on the command line.

| Command | Purpose | Writes? |
|---|---|---|
| `python3 $S/pg_query.py check [--db D] [--env E] [--connect]` | which vars are set (booleans only); `--connect` logs in and shows `current_user`, role, `read_only` | no |
| `python3 $S/pg_query.py tables --db D --env E [--schema S] [--like '%licen%']` | list tables/views | no |
| `python3 $S/pg_query.py describe --db D --env E --table [schema.]table` | columns, types, nullability, defaults | no |
| `python3 $S/pg_query.py query --db D --env E --sql "…" [--csv] [--timeout 60]` | run read SQL (`SELECT` / `WITH` / `EXPLAIN` / `SHOW` / `TABLE` / `VALUES`) | no |
| `python3 $S/pg_query.py query … --file F.sql` | same, SQL from file | no |
| `python3 $S/pg_query.py query --db D --env E --sql "…" --write --rollback` | **preview** a write: runs then rolls back, prints affected rows | no (rolled back) |
| `python3 $S/pg_query.py query --db D --env E --sql "…" --write` | apply a write in one transaction (DEV/QA/STG only) | **yes** |

Every session: `BEGIN [READ ONLY]` → `SET LOCAL statement_timeout` (60s) + `lock_timeout` (5s) → `SET LOCAL ROLE <ROLE>` (if set) → SQL → `ROLLBACK`/`COMMIT`. `application_name = code-agent-investigate`.

Read mode rejects: non-read leading keyword, nested `INSERT/UPDATE/DELETE/MERGE/…`, `SELECT … INTO`, `FOR UPDATE/SHARE`, side-effect functions (`set_config`, `pg_terminate_backend`, `nextval`, `dblink`, …), psql `\` meta-commands.

## Procedure

1. DO: `source ~/.zshenv`; `check --db D --env E`
   - IF: `ready: false` → STOP: list the missing variable names; ask user to fill them in `~/.zshenv` (never ask them to paste secrets in chat)
2. DO: `check --db D --env E --connect`
   - IF: `HINT: cannot reach` / timeout → STOP: tell user **"Connect to the VPN, then retry"**
   - IF: auth failure → ask user to verify the `DB_<DB>_<ENV>_*` values against DBeaver
3. DO: discover schema — `tables --like` → `describe` — before writing queries; never guess column names
4. DO: read queries with explicit columns + `LIMIT` (≤ 100 default) + narrow `WHERE` (id, UEN, ref no, time range)
5. IF: a write is genuinely needed (DEV/QA/STG only, e.g. reproduce/repair test data)
   - DO: show the exact SQL + target db/env + `--write --rollback` preview row count
   - ASK: explicit user approval for that statement → only then run with `--write`
   - NEVER: write to PROD; never run DDL/`TRUNCATE`/unbounded `UPDATE`/`DELETE` without a `WHERE`
6. DO: cite each finding as `db · env · query · result excerpt`

## Constraints

- Never print, log, or echo credential values; never put them in reports or commits
- PROD: read-only, minimal columns, avoid heavy scans (use indexed predicates + `LIMIT`; `EXPLAIN` first if unsure)
- Mask personal data (NRIC, names, emails, phone, addresses) in reports
- Prefer one statement per `query` call so each result maps to one cited finding
