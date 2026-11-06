---
name: integration-health
description: "One-shot readiness check for every investigation integration (Jira, GitLab, Figma, OpenSearch, APEX, Postgres, AWS SSO, Slack): offline = credentials/config present (booleans only), --net = live read-only probes in parallel (~2s). Never prints secret values. Use when: preflight, health check, are integrations working, token expired, VPN connected, sso expired, before investigating."
argument-hint: "[--net] [--only jira,gitlab,opensearch,...]"
metadata:
  category: operations
  tier: standard
  status: active
  invocation: explicit
---

# Integration Health

**Input**: optional subset → **Output**: table `Integration | Config | Live | Note`; exit `0` all required OK · `2` a required integration is missing/failing · `1` bad input.

`S=.github/skills/integration-health/scripts` — stdlib Python 3. `source ~/.zshenv` first. `--net` needs network + unsandboxed (VPN for OpenSearch/Postgres).

| Command | Use |
|---|---|
| `python3 $S/health.py` | Offline — instant; safe at session start |
| `python3 $S/health.py --net` | Live probes before gathering evidence |
| `python3 $S/health.py --net --only opensearch,postgres,aws` | Only what this investigation needs |
| `... --json` | Machine-readable |

## Probes (all read-only)

| Integration | Config check | Live probe | Required |
|---|---|---|---|
| jira | `JIRA_EMAIL` `JIRA_TOKEN` `JIRA_BASE_URL` | `GET /rest/api/3/myself` | ✓ |
| gitlab | `GITLAB_TOKEN` | `GET /api/v4/user` | ✓ |
| figma | `FIGMA_TOKEN` | `GET /v1/me` | optional |
| opensearch | `OPENSEARCH_URL_NONPROD` `OPENSEARCH_URL_PROD` | `GET /_cluster/health` both | ✓ |
| apex | `APEX_LOG_TOKEN_STAGING` `APEX_LOG_TOKEN_PROD` | `_count` on `apigw-traffic-summary*` | optional |
| postgres | `pg_query.py check` (count of ready db×env) | `pg_query.py check --db licence --env stg --connect` | ✓ |
| aws | `~/.aws/config` has `staging` + `prod-elevated` | `aws_ro.sh preflight --env staging` | ✓ |
| slack | `SLACK_TOKEN` | `auth.test` | optional |

## On failure

| Live result | Action |
|---|---|
| `unreachable … VPN/network?` (OpenSearch, Postgres) | Ask user to connect VPN, re-run with `--only` |
| `HTTP 401/403` | Token expired/revoked → user regenerates in `~/.zshenv`; never work around |
| `⚠️ expired` (aws) | Run `aws sso login --profile staging` **async**, hand user URL + code (aws-access Login) |
| Optional integration failing | Continue; note the evidence gap in the report |

Never print, echo, or log token values — the script reports booleans and HTTP codes only.
