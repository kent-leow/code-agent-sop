# <KEY> — Test Report: <ticket title>

| | |
|---|---|
| Ticket | [<KEY>](<jira url>) (<type> · <status>) |
| MR | [!<iid>](<mr url>) — head `<sha8>`, pipeline [<id>](<url>) <status> |
| Env | <env> — <app> @ `<deployed merge-ref sha8>` (verified via GitLab Environments before + after testing) |
| Chope | <cards> (<WS>, until <D MON hPM>) |
| Tested | <date> <HH:MM–HH:MM> SGT, headless Chrome <ver> via agent-browser <ver> |
| Test data | <users / entities, masked if real> |
| Backend proof source | <OpenSearch index / DB table> |

**Verdict: PASS | FAIL | BLOCKED** — <one line>.

## Results

| TC | AC (Jira) | Steps | Expected | Actual (with timestamps) | Result | Evidence |
|---|---|---|---|---|---|---|
| TC-01 | Baseline | | | | ✅ | `TC-01-<slug>.mp4`, `TC-01-step1..N*.png`, `TC-01-log-evidence.png` |
| TC-02 | **AC1** <text> | | | | ✅/❌ | |
| — | AC<n> <text> | — | — | N/A: <reason> | ⏭ | — |

## Observations

| # | Severity | Observation | Evidence |
|---|---|---|---|

## Environment incidents during testing

- <overwrites, redeploys, blocked jobs, flaky deps — with times and who/which MR>
- End state of test data: <what was left changed; how to revert>

## Artifacts

`test-artifacts/` — per TC: `.mp4` recording, `stepN-*.png` screenshots, `*-log-evidence.png` (rendered backend lines, key lines highlighted, with `_index/_id`), raw `*-logs.json`, `.start/.end` UTC windows, `steps.tsv` (observed value per step).
