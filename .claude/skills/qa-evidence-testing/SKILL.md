---
name: qa-evidence-testing
description: "Test a Jira card / GitLab MR end-to-end on a lower env (dev/qa/staging) with proof for every step and AC: maps ACs → test cases, verifies the MR is (still) deployed, drives a real browser (agent-browser) with a video recording per test case + a screenshot per step, pulls backend proof from OpenSearch (and Postgres when available) rendered as highlighted screenshots, writes TEST-REPORT.md, then asks whether to post the results as a Jira comment with every screenshot/recording attached and explained (posts only on yes). Use when: test this card, QA this ticket, start testing MR, verify AC on dev/qa/staging, record test evidence, screenshot proof."
argument-hint: "Jira key/URL and/or MR URL + env (default dev)"
metadata:
  category: qa
  tier: standard
  status: active
---

# qa-evidence-testing

**Input**: Jira card and/or MR + env → **Output**: `<DOCS_DIR>/TEST-REPORT.md` + `<DOCS_DIR>/test-artifacts/` (per TC: `.mp4`, `stepN-*.png`, `*-log-evidence.png`, raw `*-logs.json`, `.start/.end`) + (on user approval) one Jira evidence comment with all media attached.

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

| TC | AC | Steps | Expected | Proof (video / screenshots / logs / DB) |
|---|---|---|---|---|

Include a baseline TC (known starting state), each AC, one negative/no-op TC, one "unaffected path" TC, and a resilience TC if the change is best-effort/async.

## Phase 1 — Environment

1. **Deployed?** — GitLab Environments are the truth (`git-review` Step 2B). Per app: `GET /deployments?environment=<app>/<env>&order_by=created_at&sort=desc&per_page=5` → latest `success` must have `ref = refs/merge-requests/<iid>/merge` (MR pipelines deploy the **merge-ref sha**, not the MR head sha).
2. Not deployed → ask → `env-chope` (book cards first) → play manual jobs: `POST /jobs/<id>/play` (`manual`) or `POST /jobs/<id>/retry` (already ran). 403 on play = env protection / stale pipeline → report, don't loop; a fresh pipeline (e.g. rebase) often clears it.
3. Poll with `run_in_background` Bash (unsandboxed). **Not** the Monitor tool — it runs sandboxed (no network, no `~/.zshenv`) and stays silent.
4. **Re-check deployments immediately before AND after executing** — others overwrite shared envs despite chope. Symptom: 405/404 on the new endpoint. Overwritten → STOP, report who/which MR, ask before redeploying.

## Phase 2 — Tooling preflight

`bash $S/preflight.sh` (read-only) → lists missing pieces. IF any missing → ask user → `bash $S/install.sh` (unsandboxed; pinned: Node 24 via nvm, `agent-browser@0.39.1`, Chrome for Testing, `imageio-ffmpeg==0.6.0` → ffmpeg with libx264/libvpx). Never approve npm install-scripts silently (agent-browser works without its postinstall).

Then: `. $S/ab.sh` (sets PATH incl. ffmpeg **before** the agent-browser daemon starts; if `record start` says "ffmpeg not found" → `ab close` then retry — Chrome on :9222 survives).

## Phase 3 — Execute (per TC)

```bash
. $S/ab.sh; export QA_ART=<DOCS_DIR>/test-artifacts
ensure_logged_out                       # clean state; a stale session silently skips the login steps
tc_begin TC-02 ac1-rename-new-name      # writes TC-02.start (UTC) + starts video
login_cp "<mockpass dropdown label>"   # GoBiz dashboard Corppass helper; write your own for other apps
step TC-02 1 dashboard "$(header)"      # screenshot + echo observed value
ab open "$DASHBOARD_URL/profile" >/dev/null; idle
step TC-02 2 profile "$(field 'Official Company Name')" --full
logout_ui; step TC-02 3 logged-out "$(ab get url)"
tc_end TC-02                            # stops video, writes TC-02.end
```

- Verify each step actually happened (URL/text changed) before screenshotting; a helper that "succeeds" on a missing ref is a false pass.
- Prefer UI actions; `eval` only to READ (web-exploration rules). App quirks: monorepo `skills/web-exploration/testing-context/<host>.md`.
- One user per tab; never reuse a test user someone else may be on (DUPLICATE_USER).

## Phase 4 — Backend proof (per TC window)

```bash
python3 <opensearch-logs>/os_query.py search --env dev --app <app> --q '<entity/key>' \
  --from "$(cat $QA_ART/TC-02.start)" --to "$(cat $QA_ART/TC-02.end)" --size 200 --sort asc --max-chars 400 \
  > $QA_ART/TC-02-<app>-logs.json      # wait ~15s after tc_end for ingestion
python3 $S/log_evidence.py $QA_ART/evidence-html/TC-02.html "TC-02 / AC1 — <title>" "<env · index · window>" '<highlight regex>' $QA_ART/TC-02-*-logs.json
ab open "file://$QA_ART/evidence-html/TC-02.html" >/dev/null; shot TC-02-log-evidence --full
```

- Assert counts, not vibes: "Synced ×1", "PATCH 200 ×2, Synced ×0", "0 calls for UEN X".
- DB available (`postgres-query`, read-only) → also save the row before/after as JSON + rendered screenshot.

## Phase 5 — Report

Write `<DOCS_DIR>/TEST-REPORT.md` from `$S/report-template.md`: header (ticket, MR head, pipeline, env + deployed sha, chope cards, tool versions, test users), **Verdict**, results table (TC · AC · Steps · Expected · Actual with timestamps · ✅/❌/⏭ · artifacts), observations (severity), environment incidents, end-state of test data. EMIT the table to the user.

## Phase 6 — Publish to Jira (ALWAYS ask; post only on yes)

1. Write `<DOCS_DIR>/jira-evidence.json` (manifest; schema in `$S/jira_publish.py` docstring):
   - `run_id` = `<KEY>-<env>-<YYYYMMDDTHHMM>` (duplicate guard), `title`, `header` rows (MR, pipeline, env + deployed sha, tested window, test users), `verdict` + `verdict_note`
   - one `cases[]` entry per TC row of the report (incl. `NA` ACs with the reason in `summary`), in report order
   - `evidence[]` per TC, ordered **recording → step screenshots → log-evidence screenshot**; every file gets a `caption` in plain language for a PO/QA reader that says **what is on screen and what it proves**, e.g.
     - `TC-02-ac1-rename-new-name.mp4` → "Recording of the full flow: log in as the renamed entity → dashboard → My Account → log out."
     - `TC-02-step1-dashboard.png` → "Dashboard header after login shows the NEW Corppass name 'CMS-1530 New Foreign Co Pte Ltd'."
     - `TC-02-log-evidence.png` → "company-profile logs (highlighted): 'Upserted … C99887766Z' + 'Synced entity name' at 14:46:53 = the DB was updated exactly once."
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
