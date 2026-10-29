---
name: opensearch-logs
description: "Search MOLB / GoBusiness application logs in OpenSearch (dev, qa, staging, prod) by keyword, log level, trace/correlation ID, app and time window; count, aggregate (terms / histogram), follow a trace across services, or run OpenSearch SQL. Read-only. No auth — requires VPN. Requires OPENSEARCH_URL_NONPROD, OPENSEARCH_URL_PROD. Use when: investigate logs, search logs, error spike, trace id, correlation id, what happened in staging/prod, opensearch, kibana, log evidence."
argument-hint: "env (dev|qa|stg|prod) + app (e.g. ap-backend) + keyword / level / trace id / time window"
metadata:
  category: operations
  tier: standard
  status: active
  invocation: explicit
---

# OpenSearch Logs

**Input**: env + app + filters → **Output**: JSON hits / counts / buckets used as cited evidence.

## Constants (verified live)

| Env | Cluster env var | Index prefix | Dashboards (for humans) |
|---|---|---|---|
| dev · qa · stg | `OPENSEARCH_URL_NONPROD` (`https://vpc-staging-u5zne67sofr6wcvcevees6ebre.ap-southeast-1.es.amazonaws.com`) | `dev-` · `qa-` · `staging-` | `$OPENSEARCH_URL_NONPROD/_dashboards` |
| prod | `OPENSEARCH_URL_PROD` (`https://opensearch.molbproject.io`) | `prod-` | `$OPENSEARCH_URL_PROD/_dashboards` |

- API = domain root (OpenSearch REST, engine 2.x / compat `7.10.2`); Dashboards UI is the same host under `/_dashboards` — never query the UI path
- No auth; reachable **only on VPN**
- Index naming: `<prefix>-<app>.YYYY.MM` (prod older months: `…_shrunken`); archived months also in `uw-reindex-<prefix>-<app>-YYYY-MM` — the script includes both automatically
- Time field `@timestamp` (UTC); script prints `ts_sgt` (UTC+8)

### Common apps (index `<app>` segment)

| Area | Apps |
|---|---|
| Licence | `licence-service` (HTTP access logs), `licence-backend`, `licence-web`, `licensing`, `status-polling-job-licence`, `status-update-job` |
| Agency portal | `ap-backend` (service `molb-agency-portal-backend`), `ap-web` |
| Formbuilder | `formbuilder-backend`, `formbuilder-ng-web` |
| Onboarding / CMS | `op-cms`, `dashboard-backend`, `dashboard-cms`, `dashboard-web`, `task-definition`, `task-definition-cms` |
| Shared | `authentication`, `notification`, `document`, `file-service`, `payment-backend`, `company-profile`, `individual-profile`, `cloudconfig-service`, `sftp-*-job`, `application-retry-job` |

Unsure of the name → `indices --env E --app '<partial>*'`.

### Key fields

| Field | Notes | Exact (filter/agg) |
|---|---|---|
| `message` / `@message` | log line (some apps only have raw `@message`) | full-text |
| `log_level` | `DEBUG` `INFO` `WARN` `ERROR` (absent on raw-only apps → use `--q`) | `log_level.keyword` |
| `trace_id`, `span_id` | OTel trace | `trace_id.keyword` |
| `correlation_id` / `correlation.id` | request correlation (field differs per app) | `.keyword` |
| `molb_service_name`, `@log_group` | service / log group | `.keyword` |
| `logger_name`, `stack_trace`, `thread`, `mdc` | Java backends | — |
| `method`, `uri`, `status` (long), `duration`, `clientIP` | `licence-service` HTTP logs | `status` numeric |
| `baggage.uen`, `baggage.hashed_user_id`, `baggage.login_type` | request baggage | `.keyword` |

Fields per app vary → `fields --env E --app A`.

## Scripts

`S=.github/skills/opensearch-logs/scripts` — stdlib Python 3, JSON on stdout, `ERROR:` on stderr + exit 1. All commands are read-only (`raw` allow-lists read endpoints only).

| Command | Purpose |
|---|---|
| `python3 $S/os_query.py ping --env E` | reachability + cluster health (run first) |
| `python3 $S/os_query.py indices --env E [--app 'lic*']` | index families, doc counts, latest month |
| `python3 $S/os_query.py fields --env E --app A` | field list + `.keyword` variants |
| `python3 $S/os_query.py search --env E [--app A] [filters] [--size 50] [--sort desc\|asc] [--max-chars 500] [--stack] [--raw]` | matching log lines (summarised; `--raw` = full `_source`) |
| `python3 $S/os_query.py count --env E [--app A] [filters]` | hit count |
| `python3 $S/os_query.py agg --env E [--app A] [filters] --field F [--top 20] [--exact]` | top values (`.keyword` auto-appended; `--exact` for numeric e.g. `status`) |
| `python3 $S/os_query.py agg --env E [--app A] [filters] --interval 5m` | histogram (SGT buckets) — spot spikes / start time |
| `python3 $S/os_query.py trace --env E --id ID [--app A] [--from now-7d]` | every line for a trace/correlation ID across all apps, ascending |
| `python3 $S/os_query.py sql --env E --query "SELECT …"` | OpenSearch SQL (SELECT/SHOW/DESCRIBE); backtick index + `@` fields |
| `python3 $S/os_query.py raw --env E --path /<idx>/_search --body '<json>'\|@file` | full Query DSL when filters aren't enough |

**Filters**: `--q '<Lucene query_string>'` (AND default) · `--level ERROR,WARN` · `--trace <id>` · `--from now-1h` (default) · `--to now` (date math or ISO `2026-10-29T01:00:00Z`).

### Query recipes

| Need | Command |
|---|---|
| Errors in last 2h | `search --env stg --app ap-backend --level ERROR --from now-2h` |
| Keyword phrase | `--q 'message:"Licence code 1052"'` |
| Exclude noise | `--q 'timeout AND NOT message:healthcheck'` |
| Wildcard / field | `--q 'logger_name:*SessionService AND message:no_session'` |
| HTTP 5xx on licence-service | `search --env prod --app licence-service --q 'status:[500 TO 599]' --from now-1d` |
| Slow requests | `--q 'duration:>5000'` |
| By UEN | `--q 'baggage.uen:"201912345K"'` |
| Error trend | `agg --env prod --app ap-backend --level ERROR --interval 15m --from now-24h` |
| Which services erroring | `agg --env stg --level ERROR --field molb_service_name --from now-6h` |
| Exact window | `--from 2026-10-29T01:00:00Z --to 2026-10-29T02:00:00Z` (UTC; SGT − 8h) |
| SQL group-by | ``sql --env stg --query "SELECT log_level, count(*) FROM `staging-ap-backend*` WHERE `@timestamp` > '2026-10-29 00:00:00' GROUP BY log_level"`` |

## Procedure

1. DO: `source ~/.zshenv`; `ping --env E`
   - IF: `cannot reach` → STOP: tell user **"Connect to the VPN, then retry"**
   - IF: `… is not set` → STOP: name the variable
2. DO: confirm app via `indices` when unsure; `fields` when filtering on an unfamiliar field
3. DO: start broad (`count` / `agg --interval`) → narrow (`search` with `--q` / `--level`) → follow `trace_id` / `correlation_id` with `trace`
4. IF: 0 hits → widen `--from`, drop `--level` (raw-only apps), check app name / env prefix
5. DO: cite each finding as `env · _index · _id · ts_sgt` + the relevant message excerpt

## Constraints

- Read-only — never call write/admin endpoints (`_delete_by_query`, `_update`, `_bulk`, settings, index ops)
- Keep `--size` ≤ 200 unless needed (hard cap 1000); prefer `count`/`agg` for volume questions
- Prod logs contain personal data (emails, NRIC/UEN, names) — quote only what's needed; mask in reports
- Default env = the one the user names; IF none and evidence needed → ask (don't assume prod)
