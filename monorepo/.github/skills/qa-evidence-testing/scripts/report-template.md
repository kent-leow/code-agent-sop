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

**Verdict: PASS | FAIL | BLOCKED** — <one line>.

## Results — BEFORE (default branch) vs AFTER (MR)

| TC | AC (Jira) | Steps | BEFORE actual (timestamps) | AFTER actual (timestamps) | Δ | Result | Evidence |
|---|---|---|---|---|---|---|---|
| TC-01 | Baseline | | | | unchanged | ✅ | `TC-01-BEFORE-*`, `TC-01-AFTER-*` (`.mp4`, `stepN-*.png`, `log-evidence.png`) |
| TC-02 | **AC1** <text> | | <bug reproduces / old behaviour> | | fixed / new-behaviour | ✅/❌ | |
| TC-0N | Regression: <flow> | | | | unchanged / **regressed** | ✅/❌ | |
| — | AC<n> <text> | — | — | N/A: <reason> | n/a | ⏭ | — |

Δ: `fixed` · `new-behaviour` · `unchanged` · `regressed` (→ FAIL) · `n/a`.

## Observations

| # | Severity | Observation | Evidence |
|---|---|---|---|

## Environment incidents during testing

- <overwrites, redeploys, blocked jobs, flaky deps — with times and who/which MR>
- End state of test data: <what was left changed; how to revert>

## Artifacts

`test-artifacts/` — per TC id (`TC-NN-BEFORE` / `TC-NN-AFTER`): `.mp4` recording, `stepN-*.png` screenshots, `*-log-evidence.png` (rendered backend lines, key lines highlighted, with `_index/_id`), raw `*-logs.json`, `.start/.end` UTC windows, `steps.tsv` (observed value per step).
