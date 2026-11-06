---
name: change-timeline
description: "What changed in an env + time window: one chronological SGT table of GitLab deployments to <app>/<env>, MRs merged, current Chope board occupants, and (optional) ECS deployments/events. Read-only. Requires GITLAB_TOKEN (+ JIRA_* for chope, AWS SSO for --ecs). Use when: what changed, what was deployed, who deployed, started failing since, regression after deploy, incident timeline, before/after deploy."
argument-hint: "env (dev|qa|stg|prod) + window (e.g. 6h, 2d, '2026-11-05 09:00') + optional app fragment"
metadata:
  category: operations
  tier: standard
  status: active
  invocation: explicit
---

# Change Timeline

**Input**: env + window (+ app) → **Output**: Markdown table of change events (cited as evidence; correlate with error onset from **opensearch-logs** `agg --interval`).

`S=.github/skills/change-timeline/scripts` — stdlib Python 3. `source ~/.zshenv` first; network + unsandboxed (calls sibling skills' scripts).

## Command

```bash
python3 $S/timeline.py --env stg --since 6h [--until "2026-11-06 14:00"] [--app licence-service] [--ecs] [--no-chope] [--all-statuses] [--project <group/path>] [--json]
```

| Flag | Notes |
|---|---|
| `--env` | `dev` · `qa` · `stg`/`staging` · `prod`/`production` |
| `--since` / `--until` | `30m` · `6h` · `2d` · ISO · `"YYYY-MM-DD HH:MM"` (naive = SGT); default last 24h → now |
| `--app` | substring of app/service (`licence-service`, `ap-backend`, `formbuilder`); filters deploys, chope, ECS; merged MRs filtered by diff paths (one extra API call per MR — keep windows short) |
| `--ecs` | adds ECS deployments + service events via **aws-access** `aws_ro.sh` (needs `--app` + valid SSO) |
| `--project` | GitLab project path, repeatable; default `wog/gvt/gobiz/molb-gobusiness/molb-monorepo` |
| `--all-statuses` | include `blocked` (manual gate not triggered), `created`, `skipped` deployments — off by default (mostly noise) |

## Sources (verified live 2026-11-06)

| Source | API | Notes |
|---|---|---|
| deploy | `GET /projects/:id/deployments?updated_after&updated_before&order_by=updated_at` | Environments are `<app>/<dev\|qa\|staging\|production>` (+ bare `production`); lower envs deploy MR refs (`!<iid>`) |
| merge | `GET /projects/:id/merge_requests?state=merged&updated_after` | Filtered to `merged_at` in window; Jira keys pulled from title + branch |
| chope | `env-chope/scripts/chope_board.py list --env E` | **Snapshot of now** (not historical); skipped for prod |
| ecs | `aws_ro.sh ecs list-clusters / list-services / describe-services` | Clusters matched by env name; steady-state events dropped |

Each source fails independently — the header line shows `ok (n)` or `FAILED: <reason>` per source. Report failed sources as evidence gaps; never present a partial timeline as complete.

## Reading the output

- Error onset right after a `deploy success` on the same app → prime suspect; open the MR (`!iid`) diff
- Deploy from an MR ref on stg/qa/dev + Chope occupant → someone's branch is on the env (not master)
- No deploy/merge near onset → look at data (**postgres-query**), infra (**aws-access** `health.sh`), upstream (APEX → **investigate-apex**)
