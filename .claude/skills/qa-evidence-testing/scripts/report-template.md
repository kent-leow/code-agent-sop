# <KEY> — Test Report: <ticket title>

| | |
|---|---|
| Ticket | [<KEY>](<jira url>) (<type> · <status>) |
| MR | [!<iid>](<mr url>) — head `<sha8>`, pipeline [<id>](<url>) <status> |
| Env | <env> (verified via GitLab Environments before + after each phase) |
| BEFORE build | `<BASE_REF>` (master/main) — <app> @ `<sha8>`, pipeline [<id>](<url>) |
| AFTER build | MR merge-ref — <app> @ `<merge-ref sha8>` |
| Chope | <cards> (<WS>, until <D MON hPM>) |
| Tested | <date> <HH:MM–HH:MM> SGT, headless Chrome <ver> via agent-browser <ver> |
| Test data | <users / entities, masked if real> |
| Backend proof source | <OpenSearch index / DB table> |

**Verdict: PASS | FAIL | BLOCKED** — <one line: N of M ACs proven>.

## AC summary

| AC | Source | Acceptance criterion (Then) | BEFORE (default branch) | AFTER (MR) | Result |
|---|---|---|---|---|---|
| AC1 | Jira | <expected outcome> | <bug reproduces / old behaviour / absent> | <new behaviour> | ✅ / ❌ / ⏭ |
| AC2 | plan.md | | skipped: <reason> | | |

## AC1 — <criterion title>

> **Given** <…> **When** <…> **Then** <…> _(source: Jira / plan.md)_

**How it was proven**: <user / data / steps, same for BEFORE and AFTER>

| | BEFORE — `<BASE_REF>` @ `<sha8>` | AFTER — merge-ref @ `<sha8>` |
|---|---|---|
| Observed | <what happened, with SGT time> | <what happened, with SGT time> |
| Recording | [AC1-BEFORE-<slug>.mp4](test-artifacts/AC1-BEFORE-<slug>.mp4) | [AC1-AFTER-<slug>.mp4](test-artifacts/AC1-AFTER-<slug>.mp4) |
| Backend proof | <log/DB fact, e.g. "0 sync calls"> | <log/DB fact, e.g. "Synced ×1 at 14:46:53"> |

**Screenshots**

| Step | BEFORE | AFTER |
|---|---|---|
| 1 <what> | ![AC1 BEFORE step 1](test-artifacts/AC1-BEFORE-step1-<what>.png) | ![AC1 AFTER step 1](test-artifacts/AC1-AFTER-step1-<what>.png) |
| Logs | ![AC1 BEFORE logs](test-artifacts/AC1-BEFORE-log-evidence.png) | ![AC1 AFTER logs](test-artifacts/AC1-AFTER-log-evidence.png) |

**Why this proves AC1**: <same steps + same data; BEFORE shows X, AFTER shows Y, backend confirms Z> → ✅ / ❌

<!-- repeat "## ACn" per AC, in AC order; untestable AC: criterion + "⏭ Not testable — <reason>" -->

## No regression

| Unchanged behaviour checked | BEFORE | AFTER | Evidence | Result |
|---|---|---|---|---|
| <neighbouring flow> | <observed> | <same> | `REG-<flow>-BEFORE-*`, `REG-<flow>-AFTER-*` | ✅ unchanged / ❌ regressed |
| New ERROR log signatures per app | <count> | <count, same messages> | `*-log-evidence.png` | ✅ / ❌ |

## Observations

| # | Severity | Observation | Evidence |
|---|---|---|---|

## Environment incidents during testing

- <overwrites, redeploys, blocked jobs, flaky deps — with times and who/which MR>
- End state of test data: <what was left changed; how to revert>

## Artifacts

`test-artifacts/` — per evidence id `AC<n>-BEFORE` / `AC<n>-AFTER` (and `REG-<flow>-…`): `.mp4` recording, `stepN-*.png` screenshots, `-log-evidence.png` (backend lines, key lines highlighted, with `_index/_id`), raw `--<app>-logs.json`, `.start/.end` UTC windows, `steps.tsv` (observed value per step).
