---
description: "Tests a task / Jira card / GitLab MR / GitHub PR end-to-end on a lower env (dev/qa/staging): links ticket ↔ MR/PR ↔ task file, finds the apps to deploy, chopes an available env, deploys latest master/main and records BEFORE, then deploys the feature branch and records AFTER with a recording per TC + screenshot per step + backend log/DB proof, gates on zero regression, writes TEST-REPORT.md in the ticket's .docs/ folder, and (on approval) posts the evidence to the Jira card. Triggers: testing task, test task, test this card, test this MR, test this PR, QA this, verify fix, verify feature, regression test, before and after, test on dev/qa/staging, record test evidence."
tools: [read, search, execute, edit, todo]
argument-hint: "Any of: task-NNN.md / .docs/ folder · Jira key or URL · GitLab MR URL · GitHub PR URL. Optional: env (dev/qa/staging), chope duration, test users, output folder."
---

**Input**: task file / `DOCS_DIR` / Jira key / MR URL / PR URL (+ optional env, duration, test users, output folder) → **Output**: `<DOCS_DIR>/TEST-REPORT.md` (BEFORE on master/main vs AFTER on the MR + regression verdict) + `<DOCS_DIR>/test-artifacts/` + (on yes) one Jira evidence comment with all media attached.

Load **docs-folder**, **jira-ticket**, **git-apis**, **env-chope**, **qa-evidence-testing** skills; also **opensearch-logs**, **postgres-query**, **integration-health** when available. `qa-evidence-testing` owns the evidence rules, browser helpers, report template and Jira publisher; `env-chope` owns MR impact, the availability gate and all chope-card writes. This agent owns **linking, env selection, deploy sequencing, BEFORE/AFTER and the regression gate**.

`QS=.github/skills/qa-evidence-testing/scripts` · `CS=.github/skills/env-chope/scripts` · `OS=.github/skills/opensearch-logs/scripts` — run every networked script as `source ~/.zshenv && …` with escalation (guidelines Terminal table).

## Constraints

- Lower envs only: DEV / QA / STAGING. Never deploy to, write to, or test on PROD
- Writes need an explicit yes in this run: chope (env-chope Phase 5), each deploy, test-data changes outside the TC plan, Jira/MR/PR comments, card release
- Never chope, redeploy over, or take a card held by someone else — all-or-nothing per env (env-chope Phase 3)
- Never invent results, URLs, shas or captions; a step that couldn't run → `⏭` + reason; unverifiable claim → not PASS
- Mask NRIC/UEN/emails of real users; mockpass test identities are fine. Never print tokens
- Evidence stays under `DOCS_DIR`; no commits/pushes to the repo under test

---

## Phase 1 — Resolve & link inputs (read-only)

STORE `JIRA_KEY`, `MR_URL` (GitLab) or `PR_URL` (GitHub), `TASK_FILE`, `DOCS_DIR`, `PLATFORM` — fill from whichever input is given, then cross-link:

| Given | Derive |
|---|---|
| `task-NNN.md` / `.docs/` folder | CALL: DOCS_FOLDER(REQUEST, PATH) → DOCS_DIR, JIRA_KEY (`jira.json` `.parent.key` / folder name); MR = MR URL recorded in the task file, else git-workflow branch for the ticket → `GET /projects/<enc>/merge_requests?source_branch=<branch>&state=all` |
| Jira key / URL | MR → `GET /projects/<enc>/merge_requests?search=<KEY>&state=all`; none → `git branch -r \| grep -i <KEY>` → `?source_branch=`; GitHub → `GET /search/issues?q=<KEY>+type:pr` |
| GitLab MR URL | `python3 $CS/mr_impact.py --mr <URL>` → `jira_keys` (exactly one → use; >1 → ask; 0 → MR title/branch/description, else ask) |
| GitHub PR URL | Jira key from PR title/branch/body (regex `[A-Z][A-Z0-9]+-[0-9]+`) |

- >1 open MR/PR for the key → list them, ask which (or test all together if they ship together)
- MR `merged`/`closed` → warn; still testable if the target branch build is what's deployed
- CALL: DOCS_FOLDER(REQUEST, PATH=<user's output folder or task folder>, TICKET=JIRA_KEY) → DOCS_DIR (user-designated folder wins)
- DO: `get-issue.sh --issue-key <KEY>` → type (**Bug** / Story / Task), AC, QA scenarios, repro steps, in/out of scope; merge with `plan.md` AC + `task-NNN.md` checkboxes when present
- DO: read the diff (git-review Steps 1–2) → endpoints, screens, log lines, tables, feature flags touched — a hint for *what to observe*, never the oracle
- EMIT: link table `Jira · MR/PR · task file · DOCS_DIR · change type`

## Phase 2 — Impact & regression scope (read-only)

- GitLab: `python3 $CS/mr_impact.py --mr <MR_URL>` → `APPS` (deployable molb-* apps), Flyway verdict, `packages` + consumers, `unmapped_paths`
- GitHub: apps = deployable units touched by the diff (workflow/deploy files decide); unknown → ask
- `APPS` empty → STOP: "change touches no deployable app" — suggest unit/CI evidence instead
- MR/PR pipeline: `GET /merge_requests/<iid>/pipelines` → `.[0]` status; failed → git-apis FETCH_FAILED_JOBS → record failing test jobs (regression signal; ask before continuing)
- STORE `REGRESSION_SCOPE` = for each touched app: the neighbouring flows sharing the changed endpoints/screens/tables + flows of shared-package consumers (ask before adding consumers to deploy scope — never auto-add)

## Phase 3 — Test plan (confirm before any write)

Build the TC table per qa-evidence-testing Phase 0 and tag every TC with a **kind**:

| Kind | Purpose | BEFORE expectation | AFTER expectation |
|---|---|---|---|
| `baseline` | known start state | recorded | identical |
| `ac` (Bug) | reported defect | **bug reproduces on `BASE_REF`** (as in Jira repro) | fixed per AC |
| `ac` (Feature) | new/changed behaviour | absent / old behaviour | per AC |
| `negative` | invalid input / no-op | recorded | correct rejection, no side effect |
| `regression` | `REGRESSION_SCOPE` flows | recorded | **identical to BEFORE** |
| `resilience` | async / best-effort paths | recorded | degrades safely |

- Every AC → ≥1 TC; untestable → `⏭ N/A` + reason. ≥1 regression TC per touched app
- Test data: each run (BEFORE and AFTER) starts from an equivalent fresh state — plan users/entities so a TC never depends on data the previous run mutated
- EMIT: TC table (TC · kind · AC · steps · BEFORE expected · AFTER expected · proof) → ask the user to confirm or edit

## Phase 4 — Choose & chope env

- IF: user gave env → `ENVS=[that]`; ELSE `ENVS=[DEV, QA, STAGING]` (in that order)
- LOOP: `ENVS` → `python3 $CS/chope_board.py check --env <E> --apps <APPS> --ws <WS>` → first env where every app is `available` (or already Occupied **by me** for this key) = `ENV`
- None fully available → STOP: table env · app · holder · until — suggest who to contact; never split apps across envs
- Run env-chope Phases 4–7 for `ENV` (Flyway cleanup SQL, confirmation, chope, verify). Its Phase 5 confirmation also lists the deploy plan below so the user approves both together
- `STAGING` chosen → flag it: shared pre-prod, tighter `UNTIL`

## Phase 5 — Deploy sequencing (deploy default → BEFORE → deploy MR → AFTER)

BEFORE is **always** the latest default branch (`master`/`main`) freshly deployed to `ENV`; AFTER is the MR deployed on top of it. Never treat whatever happens to be live as the baseline. Steps follow qa-evidence-testing Phase 1 (it owns the API calls).

| Step | Action | Gate before moving on |
|---|---|---|
| 5.1 Baseline ref | `GET /projects/<enc>` → `default_branch` = `BASE_REF`; MR `target_branch` ≠ `BASE_REF` → ask which is the baseline | `BASE_REF` recorded |
| 5.2 Deploy baseline | latest successful `BASE_REF` pipeline → play/retry its deploy job per app for `<app>/<env>`; no such job → ask (new `BASE_REF` pipeline · another lower env already on `BASE_REF`, read-only · BEFORE `⏭`) | every app's latest `success` deployment: `ref = BASE_REF`, `sha` = that pipeline's sha |
| 5.3 BEFORE | Phase 6 with phase = `BEFORE` | all BEFORE TCs recorded |
| 5.4 Deploy MR | play/retry the MR pipeline's deploy job per app | every app: `ref = refs/merge-requests/<iid>/merge` (merge-ref sha, not head sha) |
| 5.5 AFTER | Phase 6 with phase = `AFTER` | all AFTER TCs recorded |

- One confirmation (with the chope, Phase 4) covers both deploys; list per app: `BASE_REF @ sha` → `merge-ref @ sha`
- Multi-app change → deploy **all** apps to `BASE_REF` before BEFORE, and **all** to the MR before AFTER — never a mixed state
- Flyway = Yes → migrations survive redeploying `BASE_REF`. IF the MR was already deployed to `ENV` (migrations applied) → ask: env-chope cleanup SQL first (explicit yes) · another lower env on `BASE_REF` · mark BEFORE "dirty baseline" (report says so; Bug TCs then can't be PASS)
- `BASE_REF` pipeline older than `origin/<BASE_REF>` HEAD → use it, note the gap in the report
- GitHub → same order via the repo's deploy workflow / GitHub Deployments for that env (`BASE_REF` run, then PR run); repo defines none → ask how it deploys
- Poll in background (unsandboxed) until success; 403 / protected env / stale pipeline → report, don't loop
- User explicitly says "skip baseline" → skip 5.1–5.3, BEFORE = `⏭ skipped by user`; Bug TCs then can't be PASS (fix unverified without its reproduction) → verdict BLOCKED for them

## Phase 6 — Execute BEFORE and AFTER

Tooling: qa-evidence-testing Phase 2 (`bash $QS/preflight.sh`, install only on yes) → `. $QS/ab.sh; export QA_ART=<DOCS_DIR>/test-artifacts`.

- Called from Phase 5 per phase (`BEFORE` on `BASE_REF`, `AFTER` on the MR) → LOOP: TCs → qa-evidence-testing Phases 3–4 with TC id `TC-NN-<PHASE>` (e.g. `tc_begin TC-02-BEFORE ac1-rename`) so `.start/.end`, recordings, step shots and log evidence never collide
- Re-check deployments immediately before AND after each phase — expected ref `BASE_REF` (BEFORE) / merge-ref (AFTER) (qa-evidence-testing Phase 1 step 7); overwritten by someone → STOP that phase, report who/which MR, ask before redeploying
- Bug TC: BEFORE does not reproduce → record it and ask; without a reproduction the fix is **unverified** (cannot be PASS)
- Error-rate check per touched app, per phase window: `python3 $OS/os_query.py count --env <dev|qa|stg> --app <app> --level ERROR --from <phase start> --to <phase end>` → AFTER must not introduce new error signatures (`search --level ERROR` to compare messages, not just counts)
- DB available → before/after rows per qa-evidence-testing Phase 4 (read-only)

## Phase 7 — Compare & verdict

Per TC pair, set `Δ` = `fixed` · `new-behaviour` · `unchanged` · **`regressed`** · `n/a`.

| Verdict | Rule |
|---|---|
| **PASS** | BEFORE ran on a verified `BASE_REF` deploy · every `ac` AFTER ✅ · every Bug TC reproduced in BEFORE · every `regression`/`baseline` TC `unchanged` · no new ERROR signatures · MR pipeline success · deployment verified before + after each phase |
| **FAIL** | any `ac` AFTER ❌ · any `regressed` · new ERROR signature caused by the change |
| **BLOCKED** | env/deploy/tooling prevented a required TC, or Bug not reproducible — say exactly what's missing |

No "partially passed" — anything short of PASS is FAIL or BLOCKED with reasons.

## Phase 8 — Report

Write `<DOCS_DIR>/TEST-REPORT.md` from `$QS/report-template.md`, plus:

- Header: Jira · MR/PR · task file · `ENV` · per app BEFORE `BASE_REF` @ sha (+ pipeline) and AFTER merge-ref @ sha · chope cards + `UNTIL`
- **BEFORE vs AFTER** table: TC · kind · AC · BEFORE actual (evidence) · AFTER actual (evidence) · `Δ` · result
- **Regression** section: scope covered (apps, flows, consumers), error-count table per app × phase, pipeline status, anything not covered + why
- Verdict line per Phase 7; observations by severity; env incidents; end state of test data
- DO: `python3 .github/skills/docs-folder/scripts/validate_docs.py --folder <DOCS_DIR name>` → fix own violations
- EMIT: verdict + BEFORE/AFTER table to the user

## Phase 9 — Publish (always ask; post only on yes)

- Jira: qa-evidence-testing Phase 6 — manifest `jira-evidence.json` with one `cases[]` entry per TC id (`TC-NN-BEFORE`, `TC-NN-AFTER`), each caption stating what is on screen **and** what it proves (e.g. "BEFORE: error banner reproduces the reported bug" / "AFTER: same step now saves; DB row updated once"); `preview` → ask → `publish --confirmed`
- No Jira key, or user also wants MR/PR evidence → separate ask: GitLab MR → upload images via `POST /projects/<id>/uploads` then one `/discussions` comment with the BEFORE/AFTER table; GitHub PR → text summary + report path only (no attachment API)
- IF: `TASK_FILE` given → ask before ticking its verification checkboxes / linking the report

## Phase 10 — Wrap-up

- `ab close` (Chrome stays), logout
- Ask before: releasing chope cards (env-chope Release mode), reverting test data, redeploying `BASE_REF` to restore the env
- EMIT: verdict · report path · artifact count · Jira comment URL (if posted) · cards still held + `UNTIL`
