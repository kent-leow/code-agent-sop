---
name: qa-evidence-testing
description: "Test a Jira card / GitLab MR end-to-end on a lower env (dev/qa/staging) with proof for every step and AC: maps ACs → test cases, deploys the latest default branch (master/main) to record BEFORE, then deploys the MR to record AFTER, drives a real browser (agent-browser) with a video recording per test case + a screenshot per step, pulls backend proof from OpenSearch (and Postgres when available) rendered as highlighted screenshots, writes TEST-REPORT.md, then asks whether to post the results as a Jira comment with every screenshot/recording attached and explained (posts only on yes). Use when: test this card, QA this ticket, start testing MR, verify AC on dev/qa/staging, record test evidence, screenshot proof."
argument-hint: "Jira key/URL and/or MR URL + env (default dev)"
metadata:
  category: qa
  tier: standard
  status: active
---

# qa-evidence-testing

**Input**: Jira card and/or MR + env → **Output**: `<DOCS_DIR>/TEST-REPORT.md` + `<DOCS_DIR>/test-artifacts/` (per TC id `TC-NN-BEFORE` / `TC-NN-AFTER`: `.mp4`, `stepN-*.png`, `*-log-evidence.png`, raw `*-logs.json`, `.start/.end`) + (on user approval) one Jira evidence comment with all media attached.

`S=.github/skills/qa-evidence-testing/scripts` · `DOCS_DIR` from **docs-folder** skill (`.docs/<JIRA-KEY>…/`).

## Evidence rule (non-negotiable)

| Every… | Must have |
|---|---|
| test case (TC) | one video `TC-NN-<slug>.mp4` covering login → steps → logout |
| UI step | screenshot `TC-NN-stepN-<what>.png` taken **after** the result is visible |
| backend assertion (DB write, API call, no-call) | OpenSearch/DB rows saved as JSON **and** rendered to `TC-NN-log-evidence.png` with the key lines highlighted |
| AC | ≥1 TC row in the report citing its artifacts; AC not testable → `⏭ N/A` + reason (never silently dropped) |

UI that is computed from the request (e.g. "show live value") can't prove persistence → assert on backend evidence.

## Phase 0 — Scope (read-only)

1. Jira: `jira-ticket` `get-issue.sh --issue-key <KEY>` → AC / QA scenarios / in/out of scope.
2. MR: search `GET /projects/<enc>/merge_requests?search=<KEY>`; IF none → `git branch -r | grep -i <KEY>` → `?source_branch=<branch>&state=all`. Read diff (`git-review` Steps 1–2) to learn *what to observe* (endpoints, log lines, tables) — the diff is a hint, not the oracle.
3. EMIT TC table → confirm with user before executing:

| TC | AC | Steps | BEFORE expected (default branch) | AFTER expected (MR) | Proof (video / screenshots / logs / DB) |
|---|---|---|---|---|---|

BEFORE expectation: Bug → the defect reproduces; feature → old/absent behaviour; unaffected/regression path → same as AFTER. Include a baseline TC (known starting state), each AC, one negative/no-op TC, one "unaffected path" TC, and a resilience TC if the change is best-effort/async.

## Phase 1 — Environment (BEFORE = default branch, AFTER = MR)

Every TC runs twice on the **same env and test-data setup**: `BEFORE` on the latest default branch (`master`/`main`), then `AFTER` on the MR. Order is fixed: **deploy default → BEFORE → deploy MR → AFTER**. Book cards with `env-chope` first; each deploy needs the user's yes (one confirmation may cover both).

GitLab Environments are the truth (`git-review` Step 2B). Per app: `GET /deployments?environment=<app>/<env>&order_by=created_at&sort=desc&per_page=5` → latest `success` = what's live.

1. **Baseline ref** — `GET /projects/<enc>` → `default_branch` = `BASE_REF`. IF MR `target_branch` ≠ `BASE_REF` → ask which to use as baseline (record the choice).
2. **Deploy baseline** — `GET /projects/<enc>/pipelines?ref=<BASE_REF>&status=success&order_by=id&sort=desc&per_page=1` → `BASE_PIPELINE` (record its `sha`; IF it's older than `origin/<BASE_REF>` HEAD → say so in the report). `GET /pipelines/<id>/jobs?per_page=100` → the deploy job for `<app>/<env>` (same job name as in the MR pipeline) → play/retry (step 4).
   - No deploy job for that env in the default-branch pipeline → ask: trigger a new pipeline `POST /projects/<enc>/pipeline` with `ref=<BASE_REF>` (write, needs yes) · or another lower env already on `BASE_REF` (read-only checks only) · or `BEFORE = ⏭` + reason. Never test BEFORE on a build that isn't `BASE_REF`.
   - Verify: latest `success` deployment `ref = <BASE_REF>` and `sha = BASE_PIPELINE.sha` → then run all BEFORE TCs (Phases 3–4).
3. **Deploy MR** — play/retry the MR pipeline's deploy job for `<app>/<env>` → verify latest `success` has `ref = refs/merge-requests/<iid>/merge` (MR pipelines deploy the **merge-ref sha**, not the MR head sha) → run all AFTER TCs.
4. Play = `POST /jobs/<id>/play` (`manual`) or `POST /jobs/<id>/retry` (already ran). 403 on play = env protection / stale pipeline → report, don't loop; a fresh pipeline (e.g. rebase) often clears it.
5. **Flyway** (`env-chope` `mr_impact.py` verdict Yes) — redeploying the baseline does **not** roll migrations back. IF the MR's migrations are already applied on the env (MR deployed earlier) → BEFORE is not a true baseline: ask → run the env-chope cleanup SQL first (lower env, `postgres-query --write`, explicit yes) · or another lower env on `BASE_REF` · or mark BEFORE "dirty baseline" in the report.
6. Poll with `run_in_background` Bash (unsandboxed). **Not** the Monitor tool — it runs sandboxed (no network, no `~/.zshenv`) and stays silent.
7. **Re-check deployments immediately before AND after each phase** (expected ref: `BASE_REF` for BEFORE, merge-ref for AFTER) — others overwrite shared envs despite chope. Symptom: 405/404 on the new endpoint. Overwritten → STOP, report who/which MR, ask before redeploying.
8. Test data: BEFORE and AFTER each start from an equivalent fresh state (separate users/entities or reset between phases) — AFTER must never depend on data BEFORE mutated.
9. Only an AFTER run is wanted (user says "skip baseline") → skip steps 1–2, record `BEFORE = ⏭ skipped by user` in the report.

## Phase 2 — Tooling preflight

`bash $S/preflight.sh` (read-only) → lists missing pieces. IF any missing → ask user → `bash $S/install.sh` (unsandboxed; pinned: Node 24 via nvm, `agent-browser@0.39.1`, Chrome for Testing, `imageio-ffmpeg==0.6.0` → ffmpeg with libx264/libvpx). Never approve npm install-scripts silently (agent-browser works without its postinstall).

Then: `. $S/ab.sh` (sets PATH incl. ffmpeg **before** the agent-browser daemon starts; if `record start` says "ffmpeg not found" → `ab close` then retry — Chrome on :9222 survives).

## Phase 3 — Execute (per TC, once per phase)

TC id carries the phase — `TC-NN-BEFORE` (default-branch deploy) / `TC-NN-AFTER` (MR deploy) — so `.start/.end`, recordings, shots and log evidence never collide. Run **all** BEFORE TCs, then switch deploy (Phase 1 step 3), then all AFTER TCs with identical steps.

```bash
. $S/ab.sh; export QA_ART=<DOCS_DIR>/test-artifacts
ensure_logged_out                       # clean state; a stale session silently skips the login steps
tc_begin TC-02-AFTER ac1-rename-new-name   # writes TC-02-AFTER.start (UTC) + starts video
login_cp "<mockpass dropdown label>"   # GoBiz dashboard Corppass helper; write your own for other apps
step TC-02-AFTER 1 dashboard "$(header)"   # screenshot + echo observed value
ab open "$DASHBOARD_URL/profile" >/dev/null; idle
step TC-02-AFTER 2 profile "$(field 'Official Company Name')" --full
logout_ui; step TC-02-AFTER 3 logged-out "$(ab get url)"
tc_end TC-02-AFTER                      # stops video, writes TC-02-AFTER.end
```

- Verify each step actually happened (URL/text changed) before screenshotting; a helper that "succeeds" on a missing ref is a false pass.
- Prefer UI actions; `eval` only to READ (web-exploration rules). App quirks: monorepo `skills/web-exploration/testing-context/<host>.md`.
- One user per tab; never reuse a test user someone else may be on (DUPLICATE_USER).

## Phase 4 — Backend proof (per TC window)

```bash
python3 <opensearch-logs>/os_query.py search --env dev --app <app> --q '<entity/key>' \
  --from "$(cat $QA_ART/TC-02-AFTER.start)" --to "$(cat $QA_ART/TC-02-AFTER.end)" --size 200 --sort asc --max-chars 400 \
  > $QA_ART/TC-02-AFTER-<app>-logs.json      # wait ~15s after tc_end for ingestion
python3 $S/log_evidence.py $QA_ART/evidence-html/TC-02-AFTER.html "TC-02-AFTER / AC1 — <title>" "<env · index · window>" '<highlight regex>' $QA_ART/TC-02-AFTER-*-logs.json
ab open "file://$QA_ART/evidence-html/TC-02-AFTER.html" >/dev/null; shot TC-02-AFTER-log-evidence --full
```

- Assert counts, not vibes: "Synced ×1", "PATCH 200 ×2, Synced ×0", "0 calls for UEN X".
- DB available (`postgres-query`, read-only) → also save the row before/after as JSON + rendered screenshot.

## Phase 5 — Report

Write `<DOCS_DIR>/TEST-REPORT.md` from `$S/report-template.md`: header (ticket, MR head, pipeline, env, **BEFORE** `BASE_REF` @ deployed sha, **AFTER** merge-ref @ deployed sha, chope cards, tool versions, test users), **Verdict**, BEFORE vs AFTER results table (TC · AC · Steps · BEFORE actual · AFTER actual · Δ `fixed`/`new-behaviour`/`unchanged`/`regressed` · ✅/❌/⏭ · artifacts of both runs), observations (severity), environment incidents, end-state of test data. A Bug whose BEFORE didn't reproduce → not ✅ (unverified). Any `regressed` → FAIL. EMIT the table to the user.

## Phase 6 — Publish to Jira (ALWAYS ask; post only on yes)

1. Write `<DOCS_DIR>/jira-evidence.json` (manifest; schema in `$S/jira_publish.py` docstring):
   - `run_id` = `<KEY>-<env>-<YYYYMMDDTHHMM>` (duplicate guard), `title`, `header` rows (MR, pipeline, env, BEFORE `BASE_REF` @ sha, AFTER merge-ref @ sha, tested window, test users), `verdict` + `verdict_note`
   - one `cases[]` entry per TC id of the report (`TC-NN-BEFORE`, then `TC-NN-AFTER`; incl. `NA` ACs with the reason in `summary`), in report order; BEFORE `summary` names the default-branch sha, AFTER the merge-ref sha
   - `evidence[]` per TC, ordered **recording → step screenshots → log-evidence screenshot**; every file gets a `caption` in plain language for a PO/QA reader that says **what is on screen and what it proves**, e.g.
     - `TC-02-AFTER-ac1-rename-new-name.mp4` → "Recording of the full flow: log in as the renamed entity → dashboard → My Account → log out."
     - `TC-02-AFTER-step1-dashboard.png` → "Dashboard header after login shows the NEW Corppass name 'CMS-1530 New Foreign Co Pte Ltd'."
     - `TC-02-AFTER-log-evidence.png` → "company-profile logs (highlighted): 'Upserted … C99887766Z' + 'Synced entity name' at 14:46:53 = the DB was updated exactly once."
     - `TC-02-BEFORE-step1-dashboard.png` → "BEFORE (master @ 1a2b3c4d): dashboard header still shows the OLD name — reproduces the reported bug."
   - Never caption beyond what the file shows; no NRIC/UEN of real users; raw `*.json`/`.html` are not attached (screenshots of them are)
   - `observations` = report observations (severity first); `footer` = where the full report lives
2. `source ~/.zshenv && python3 $S/jira_publish.py preview --manifest <DOCS_DIR>/jira-evidence.json --art <DOCS_DIR>/test-artifacts` (read-only, network escalation) → fails on any missing file/caption; reports upload list, files already attached, >10 MB files, name conflicts, and whether this run was already posted.
3. Ask the user (AskUserQuestion) — question must stand alone: issue key, N files / X MB, verdict, and whether a comment already exists. Options: **Post comment + attach all** · **Show me the comment first** (print the rendered wiki markup, then ask again) · **Don't post**.
4. Yes → `python3 $S/jira_publish.py publish --manifest … --art … --confirmed` → uploads only missing attachments (sequential, POST never retried), posts ONE comment (wiki: thumbnails for images, attachment links for recordings, per-TC evidence tables), writes `jira-evidence.json.published.json`.
   - Partial failure → script prints what was uploaded; report it exactly; re-running `publish` skips attached files but refuses to post a 2nd comment for the same `run_id`.
   - Report the comment URL + attachment count to the user. No → say nothing was posted; artifacts stay local.
5. GitLab MR comment = a separate ask (not bundled with Jira).

## Phase 7 — Wrap-up

- Logout; `ab close` (keeps Chrome) — leave Chrome running unless asked.
- Ask before: releasing chope cards, reverting test data, updating tracked testing-context files.

## Constraints

- Read-only on Jira/GitLab/DB unless the user approves the specific write (deploy, chope, comment). The Jira evidence post is always offered (Phase 6) but never done without an explicit yes in the same run.
- Never invent results; a step that couldn't run is `⏭` with the reason.
- Mask NRIC/UEN of real users in reports; mockpass test identities are fine.
- Evidence files stay under `DOCS_DIR`; helper scripts never write into the repo under test.
