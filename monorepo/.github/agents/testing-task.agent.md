---
description: "Tests a task / Jira card / GitLab MR / GitHub PR end-to-end on a lower env (dev/qa/staging) against the Jira / plan.md acceptance criteria: builds an AC inventory, proves each AC with its own BEFORE vs AFTER evidence, links ticket ↔ MR/PR ↔ task file, finds the apps to deploy, chopes an available env, deploys latest master/main and records BEFORE, then deploys the feature branch and records AFTER with a recording per AC + screenshot per step + backend log/DB proof + why it proves the AC, gates on zero regression, writes TEST-REPORT.md with a per-AC verdict in the ticket's .docs/ folder, and (on approval) posts the evidence to the Jira card. Triggers: testing task, test task, test this card, test this MR, test this PR, QA this, verify fix, verify feature, regression test, before and after, test on dev/qa/staging, record test evidence."
tools: [read, search, execute, edit, todo]
argument-hint: "Any of: task-NNN.md / .docs/ folder · Jira key or URL · GitLab MR URL · GitHub PR URL. Optional: env (dev/qa/staging), chope duration, test users, output folder."
---

**Input**: task file / `DOCS_DIR` / Jira key / MR URL / PR URL (+ optional env, duration, test users, output folder) → **Output**: `<DOCS_DIR>/TEST-REPORT.md` (per-AC verdict from Jira / `plan.md` ACs, BEFORE on master/main vs AFTER on the MR, regression verdict) + `<DOCS_DIR>/test-artifacts/` + (on yes) one Jira evidence comment with all media attached.

Load **feature-flow** (stage 8 Test), **docs-folder**, **jira-ticket**, **git-apis**, **env-chope**, **qa-evidence-testing** skills; also **opensearch-logs**, **postgres-query**, **integration-health**, web-exploration (workspace) when available. `qa-evidence-testing` owns the evidence rules, browser helpers, report template and Jira publisher; `env-chope` owns MR impact, the availability gate and all chope-card writes. This agent owns **linking, env selection, deploy sequencing, BEFORE/AFTER and the regression gate**.

`QS=.github/skills/qa-evidence-testing/scripts` · `CS=.github/skills/env-chope/scripts` · `OS=.github/skills/opensearch-logs/scripts` — run every networked script as `source ~/.zshenv && …` with escalation (guidelines Terminal table).

## Constraints

- Lower envs only: DEV / QA / STAGING. Never deploy to, write to, or test on PROD
- Writes need an explicit yes in this run: chope (env-chope Phase 5), each deploy, test-data changes outside the AC proof plan, Jira/MR/PR comments, card release
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
- DO: `get-issue.sh --issue-key <KEY>` → type (**Bug** / Story / Task), AC, QA scenarios, repro steps, in/out of scope
- DO: read the diff (git-review Steps 1–2) → endpoints, screens, log lines, tables, feature flags touched — a hint for *what to observe*, never the oracle
- EMIT: link table `Jira · MR/PR · task file · DOCS_DIR · change type`

## Phase 1b — AC inventory (the test oracle)

ACs define PASS. The diff, task checkboxes and the agent's own reading never add or relax an AC.

| Source | Use |
|---|---|
| Jira AC (description table / AC field / "Acceptance Criteria" section) | primary when present — it's what the card is accepted against |
| `plan.md` `## Acceptance Criteria` | primary when Jira has none; else cross-check |
| Jira QA scenarios, Bug repro steps | extra conditions under the AC they prove; repro steps = Bug BEFORE steps |
| `task-NNN.md` Done When / Edge Cases | hints for invalid-input / edge conditions inside an AC, never new ACs |
| Neither has ACs | STOP: ask the user for the ACs (or approve ACs drafted from the Jira summary) — never test without an agreed oracle |

- DO: STORE `ACS[]` — one row per AC: `id` (Jira `AC<n>` / plan `AC<n>` / `F<n>-AC<m>`) · source · Given · When · Then (split prose ACs into Given/When/Then; keep the original wording quoted)
- IF: Jira and `plan.md` both have ACs → match by meaning: same → one row (both sources); only in one → keep, mark source; contradicting → list both, ask which wins before Phase 3
- IF: an AC is vague ("works correctly", "user-friendly") → propose a measurable Then and ask; unconfirmed → AC verdict `⏭ untestable as written`
- EMIT: AC inventory table (id · source · Given · When · Then)

## Phase 2 — Impact & regression scope (read-only)

- GitLab: `python3 $CS/mr_impact.py --mr <MR_URL>` → `APPS` (deployable molb-* apps), Flyway verdict, `packages` + consumers, `unmapped_paths`
- GitHub: apps = deployable units touched by the diff (workflow/deploy files decide); unknown → ask
- `APPS` empty → STOP: "change touches no deployable app" — suggest unit/CI evidence instead
- MR/PR pipeline: `GET /merge_requests/<iid>/pipelines` → `.[0]` status; failed → git-apis FETCH_FAILED_JOBS → record failing test jobs (regression signal; ask before continuing)
- STORE `REGRESSION_SCOPE` = for each touched app: the neighbouring flows sharing the changed endpoints/screens/tables + flows of shared-package consumers (ask before adding consumers to deploy scope — never auto-add)

## Phase 3 — AC proof plan (confirm before any write)

Per qa-evidence-testing Phase 0. One row per AC — no test-case numbering. Each AC's **Given** → setup + test data, **When** → steps, **Then** → what BEFORE and AFTER must show + proof type (screen, log line, DB row).

| AC | Given (setup + data) | When (steps) | BEFORE must show | AFTER must show | Proof |
|---|---|---|---|---|---|

- An AC with several conditions (valid + invalid input, two roles) → list each condition inside that AC's row; each gets its own run `AC<n>-<PHASE>-<condition>` but is reported under AC<n>
- Untestable AC → `⏭ Not testable — <reason>` in its row
- BEFORE runs for **every** AC whenever possible — it proves the change caused the AFTER result:

| Case | BEFORE |
|---|---|
| Behaviour exists on `BASE_REF` (bug, changed rule) | run full steps; Bug → defect must reproduce |
| New screen / endpoint / field absent on `BASE_REF` | run up to the missing point; record the absence (menu missing, 404, field not shown) as evidence |
| Needs data/config created only by the MR (new table, flag, migration) | `skipped: <reason>`; AFTER-only |
| Dirty baseline (MR migrations already applied), no deploy job, user skips | per Phase 5 rules; Bug ACs then cannot be ✅ |

- **No regression** list (separate from ACs): ≥1 neighbouring flow per touched app from `REGRESSION_SCOPE`, named by what it does (evidence id `REG-<flow>`); BEFORE and AFTER must be identical
- Test data: BEFORE and AFTER start from an equivalent fresh state — no run depends on data the previous run mutated
- EMIT: AC proof plan + No regression list + coverage check (every AC id has a row) → ask the user to confirm or edit

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
| 5.3 BEFORE | Phase 6 with phase = `BEFORE` | every AC's BEFORE recorded or skipped with reason |
| 5.4 Deploy MR | play/retry the MR pipeline's deploy job per app | every app: `ref = refs/merge-requests/<iid>/merge` (merge-ref sha, not head sha) |
| 5.5 AFTER | Phase 6 with phase = `AFTER` | every AC's AFTER recorded |

- One confirmation (with the chope, Phase 4) covers both deploys; list per app: `BASE_REF @ sha` → `merge-ref @ sha`
- Multi-app change → deploy **all** apps to `BASE_REF` before BEFORE, and **all** to the MR before AFTER — never a mixed state
- Flyway = Yes → migrations survive redeploying `BASE_REF`. IF the MR was already deployed to `ENV` (migrations applied) → ask: env-chope cleanup SQL first (explicit yes) · another lower env on `BASE_REF` · mark BEFORE "dirty baseline" (report says so; Bug ACs then can't be ✅)
- `BASE_REF` pipeline older than `origin/<BASE_REF>` HEAD → use it, note the gap in the report
- GitHub → same order via the repo's deploy workflow / GitHub Deployments for that env (`BASE_REF` run, then PR run); repo defines none → ask how it deploys
- Poll in background (unsandboxed) until success; 403 / protected env / stale pipeline → report, don't loop
- User explicitly says "skip baseline" → skip 5.1–5.3, BEFORE = `skipped by user`; Bug ACs then can't be ✅ (fix unverified without its reproduction) → BLOCKED for them

## Phase 6 — Execute BEFORE and AFTER

Tooling: qa-evidence-testing Phase 2 (`bash $QS/preflight.sh`, install only on yes) → `. $QS/ab.sh; export QA_ART=<DOCS_DIR>/test-artifacts`.

- Called from Phase 5 per phase (`BEFORE` on `BASE_REF`, `AFTER` on the MR) → LOOP: ACs (then `REG-<flow>` checks) → qa-evidence-testing Phases 3–4 with evidence id `AC<n>-<PHASE>` (e.g. `ac_begin AC2-BEFORE rename`) → recording + screenshot per step + backend proof per AC
- Re-check deployments immediately before AND after each phase — expected ref `BASE_REF` (BEFORE) / merge-ref (AFTER) (qa-evidence-testing Phase 1 step 7); overwritten by someone → STOP that phase, report who/which MR, ask before redeploying
- Bug AC: BEFORE does not reproduce → record it and ask; without a reproduction the fix is **unverified** (cannot be PASS)
- Error-rate check per touched app, per phase window: `python3 $OS/os_query.py count --env <dev|qa|stg> --app <app> --level ERROR --from <phase start> --to <phase end>` → AFTER must not introduce new error signatures (`search --level ERROR` to compare messages, not just counts)
- DB available → before/after rows per qa-evidence-testing Phase 4 (read-only)

## Phase 7 — Verdict per AC

Per AC, compare its BEFORE and AFTER evidence against its Then, and write **Why this proves it** (1–2 sentences tying the evidence to the Then):

| AC result | Rule |
|---|---|
| ✅ | AFTER shows the Then (screen + backend proof) · BEFORE shows the bug / old / absent behaviour where run |
| ❌ | AFTER does not show the Then, or shows a side effect the AC forbids |
| ⏭ | not testable / skipped / blocked — reason stated |

| Overall | Rule |
|---|---|
| **PASS** | every AC ✅ (or ⏭ agreed by the user in Phase 3) · every Bug AC reproduced in BEFORE · every No-regression flow unchanged · no new ERROR signatures · MR pipeline success · deployment verified before + after each phase |
| **FAIL** | any AC ❌ · any regression · new ERROR signature caused by the change |
| **BLOCKED** | env/deploy/tooling prevented proving an AC, or a Bug AC not reproducible — say exactly what's missing |

No "partially passed" — anything short of PASS is FAIL or BLOCKED with reasons.

## Phase 8 — Report

Write `<DOCS_DIR>/TEST-REPORT.md` from `$QS/report-template.md`, plus:

- Header: Jira · MR/PR · task file · `ENV` · per app BEFORE `BASE_REF` @ sha (+ pipeline) and AFTER merge-ref @ sha · chope cards + `UNTIL`
- **AC summary** table (first, after the verdict line): AC · source (Jira / plan) · Then · BEFORE · AFTER · ✅/❌/⏭
- One `## AC<n>` section per AC: criterion quoted → how it was proven → BEFORE vs AFTER (observed, recording, backend proof) → side-by-side step screenshots → **Why this proves AC<n>**
- **No regression** section: flows covered (apps, consumers), error-count table per app × phase, pipeline status, anything not covered + why
- Verdict line per Phase 7; observations by severity; env incidents; end state of test data
- DO: `python3 .github/skills/docs-folder/scripts/validate_docs.py --folder <DOCS_DIR name>` → fix own violations
- EMIT: verdict + AC summary table to the user

## Phase 9 — Publish (always ask; post only on yes)

- Jira: qa-evidence-testing Phase 6 — manifest `jira-evidence.json` with one `acs[]` entry per AC (criterion, BEFORE evidence, AFTER evidence, explanation) + `regression[]`; every caption states what is on screen **and** what it proves (e.g. "BEFORE: error banner reproduces the reported bug" / "AFTER: same step now saves; DB row updated once"); comment opens with the AC summary table; `preview` → ask → `publish --confirmed`
- No Jira key, or user also wants MR/PR evidence → separate ask: GitLab MR → upload images via `POST /projects/<id>/uploads` then one `/discussions` comment with the AC summary table; GitHub PR → text summary + report path only (no attachment API)
- IF: `TASK_FILE` given → ask before ticking its verification checkboxes / linking the report

## Phase 10 — Wrap-up

- `ab close` (Chrome stays), logout
- Ask before: releasing chope cards (env-chope Release mode), reverting test data, redeploying `BASE_REF` to restore the env
- EMIT: verdict · report path · artifact count · Jira comment URL (if posted) · cards still held + `UNTIL`
- CALL: SUGGEST_NEXT(Test, PASS | FAIL | BLOCKED)
