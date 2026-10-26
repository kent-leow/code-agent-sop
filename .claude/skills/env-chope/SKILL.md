---
name: env-chope
description: "Chope (reserve) or release DEV/QA/STAGING env cards on the Gobiz Chope Env Jira board (MOLBLT board 4529) on the user's behalf. Analyses a GitLab MR to find touched molb-* apps + Flyway migrations, verifies every card is Available, then moves cards to Occupied with the house title convention, assigns the user, and attaches draft Flyway cleanup SQL. Use when: chope env, chope staging/qa/dev, reserve environment, book env for MR, release env, un-chope, who is on staging. Requires JIRA_EMAIL, JIRA_TOKEN, JIRA_BASE_URL, GITLAB_TOKEN."
argument-hint: "'chope staging for <MR URL> for a day' | 'release my staging cards' | 'status qa'"
metadata:
  category: operations
  tier: standard
  status: active
  invocation: explicit
---

# Env Chope

**Input**: request text (mode, env, MR URL(s), duration, optional pair partner / Jira key) → **Output**: Jira cards updated + report; draft cleanup SQL under `<DOCS_DIR>/env-chope/` when Flyway changes exist.

## Constants (verified live)

| Name | Value |
|---|---|
| Board | `$JIRA_BASE_URL/jira/software/c/projects/MOLBLT/boards/4529` — "Gobiz Chope Env kanban", filter `project = MOLBLT AND labels = CHOPE` |
| Workstream | Jira **label** — default `WS2&WS3` (others: `WS1`, `WS4`) |
| Card | one per (env × app); title's 1st `[..]` = env, 2nd = app |
| Available column | statuses `To Do`, `Ready for Dev` |
| Occupied column | `Dev In Progress` (chope target), `Testing`, `READY FOR TEST`, `For Review / Reviewing`, `Ready for Demo to PO`, `Done, pending execution` |
| Release target | `To Do` |
| House rules | ReadMe card `MOLBLT-6670` (never clone or edit it) |
| GitLab | `https://sgts.gitlab-dedicated.com`; monorepo `wog/gvt/gobiz/molb-gobusiness/molb-monorepo` |

### Title convention — follow verbatim

| State | Format | Example |
|---|---|---|
| Occupied | `[<ENV>] [<app>][Until <D MON hAM/PM>] [Flyway= <Yes\|No>] [JIRA <KEY>]` | `[STAGING] [molb-licence-service][Until 26 OCT 6PM] [Flyway= No] [JIRA MOLBLT-7531]` |
| Available (placeholder) | `[<ENV>] [<app>] [Until ???] [Flyway=false] [JIRA ???]` | `[DEV] [molb-status-update-job] [Until ???] [Flyway=false] [JIRA ???]` |

Never hand-build titles — `chope_board.py` composes and validates them. Keep the card's existing app name (e.g. `molb-send-to-edh-job`), not the monorepo folder name.

## Scripts

`S=.github/skills/env-chope/scripts` — stdlib Python 3, JSON on stdout, non-zero exit + `ERROR:` on stderr.

| Command | Purpose | Writes Jira? |
|---|---|---|
| `python3 $S/mr_impact.py --mr <URL> [--env E]` | touched apps (via `service-graph.json` at MR head), per-env Flyway verdict, migration diffs, Jira keys, changed shared packages + consumers | no |
| `python3 $S/chope_board.py list [--env E] [--ws W] [--mine]` | cards with column/assignee | no |
| `python3 $S/chope_board.py check --env E --apps a,b [--ws W]` | availability gate; verdict per app | no |
| `python3 $S/chope_board.py title --env E --app A --until U --flyway yes\|no --jira K` | preview a title | no |
| `python3 $S/chope_board.py chope --key K --env E --app A --until U --flyway yes\|no --jira K [--pair-label N]` | set title, assign self, add pair label, → `Dev In Progress`; refuses if card not Available or assigned | **yes** |
| `python3 $S/chope_board.py release --key K --env E --app A [--remove-label N ...] [--force]` | placeholder title, unassign, remove given pair labels (others kept + reported), → `To Do`, then delete `cleanup-*.sql`; refuses unless card is Occupied **and** assigned to you (`--force` overrides) | **yes** |
| `python3 $S/chope_board.py clone --from K --env E --app A` | create card from a same-env WS card (placeholder title, CHOPE + WS labels) | **yes** |
| `python3 $S/chope_board.py attach --key K --file F` | attach file | **yes** |

`check` verdicts: `available` · `occupied` · `available-but-assigned` · `other-workstream` · `ambiguous` · `missing` (+ `clone_source`). Name aliases (monorepo → card) live in `APP_ALIASES` in `chope_board.py`; add there when a new mismatch is confirmed. Write commands resolve the target transition before mutating, so a missing transition aborts with no change.

## Prerequisites

- DO: `source ~/.zshenv`; confirm `JIRA_EMAIL`, `JIRA_TOKEN`, `JIRA_BASE_URL`, `GITLAB_TOKEN` non-empty (never print values)
- IF: any missing → STOP: name the missing variable
- Network calls → request network access up front

## Phase 1 — Parse request

STORE (mark `unknown` if absent — never guess):

| Field | Rule |
|---|---|
| `MODE` | `chope` (default) · `release` ("release", "un-chope", "done with") · `status` ("who is on", "is X free") |
| `ENV` | DEV / QA / STAGING (`stg` → STAGING). Multiple allowed. IF unknown in chope/release → ask |
| `MRS` | GitLab MR URL(s). IF chope and none → ask (or accept explicit app list from user) |
| `WS` | default `WS2&WS3` unless user names another |
| `UNTIL` | see Duration rules |
| `JIRA` | user-given key wins; else from MR (Phase 2) |
| `PAIR` | pairing partner name → label (optional) |

### Duration rules (timezone Asia/Singapore, `NOW` = current time)

| Request | `UNTIL` |
|---|---|
| explicit date/time | as given |
| "today" / no duration | today 6PM; IF `NOW` ≥ 6PM → ask |
| "a day" / "N days" | (today + N days) 6PM |
| "N hours" | `NOW` + N h, rounded up to the hour |
| "till/until <weekday>" | next such weekday 6PM |

Format: `D MON hAM/PM` uppercase, no leading zero, minutes only if non-zero (`27 OCT 6PM`, `3 NOV 10:30AM`). IF result lands on Sat/Sun → flag in the confirmation.

## Phase 2 — Analyse MR(s) (chope only)

- LOOP: `MRS` → `mr_impact.py --mr <URL> --env <ENV>`; merge `apps` across MRs (Flyway = Yes if Yes in any)
- IF: MR `state` is `merged`/`closed` → warn in confirmation
- IF: `apps` empty → STOP: "MR touches no deployable app" (list `unmapped_paths`)
- IF: `packages` non-empty → EMIT the package + its consumers; ask whether to also chope consumers (never auto-add)
- IF: `unmapped_paths` non-empty → EMIT them (info only)
- `JIRA`: user-given → else exactly one key in `jira_keys` → use it; >1 → ask which; 0 → ask (never invent)
- IF: Flyway reason contains `unresolved` → keep `Yes` (conservative) and say why in the confirmation

## Phase 3 — Availability gate (all-or-nothing, before any write)

- DO: `check --env <ENV> --apps <comma list of app names> --ws <WS>` (one call per env)
- IF: any verdict ∈ {`occupied`, `available-but-assigned`, `other-workstream`, `ambiguous`} → STOP: **do not chope anything**. EMIT table: app · card key/link · current title · assignee · verdict. Suggest who to contact
- IF: verdict `missing` (and nothing else blocks) → DO: `list --env <ENV> --ws <WS>` and look for a card whose app name is a near-match (alias, `molb-` prefix, `sftp-`/`-service` variants). IF found → STOP: ask whether it is the same app (if yes, add the pair to `APP_ALIASES` and re-run `check`). ELSE plan `clone --from <clone_source>` (per ReadMe "How to add a new card"); requires confirmation in Phase 5
- IF: `clone_source` is null → STOP: no same-env WS card to clone; ask user

## Phase 4 — Draft Flyway cleanup SQL (only apps with Flyway = Yes)

- CALL: DOCS_FOLDER(REQUEST, TICKET=`JIRA`, CAN_CREATE_JIRA=false) → `DOCS_DIR` (load **docs-folder** skill)
- LOOP: app with Flyway = Yes → write `<DOCS_DIR>/env-chope/cleanup-<env-lower>-<card-app>-<JIRA>.sql` from its `migration_files[].diff` (if a diff is truncated/`too_large`, fetch the file raw at the MR head SHA):
  - Header: `-- DRAFT — review before running`, MR URL, app, env, generated timestamp
  - Reverse each statement, newest migration first, statements in reverse order:

| Forward | Reverse |
|---|---|
| `CREATE TABLE t` | `DROP TABLE IF EXISTS t;` |
| `ALTER TABLE t ADD [COLUMN] c` | `ALTER TABLE t DROP COLUMN IF EXISTS c;` |
| `CREATE [UNIQUE] INDEX [CONCURRENTLY] i` | `DROP INDEX IF EXISTS i;` |
| `ADD CONSTRAINT k` | `ALTER TABLE t DROP CONSTRAINT IF EXISTS k;` |
| `INSERT` (keys visible) | `DELETE ... WHERE <key cols> = <values>;` |
| type change / `UPDATE` / `DELETE` / `DROP` / Kotlin-Java migration | `-- TODO(manual): not mechanically reversible — <reason>` (never guess prior state) |

  - Then history rows: versioned `V<ver>__<desc>` → `DELETE FROM <table> WHERE version = '<ver with _ → .>';`; repeatable `R__x` → `WHERE script = 'R__x.sql'`. `<table>` = `spring.flyway.table` from the service config if set, else `flyway_schema_history`; prefix schema only if config sets `schemas`/`default-schema`, else leave `<schema>.` placeholder with TODO
  - Django (`onboarding-portal-service`) → `DELETE FROM django_migrations WHERE app = '<app>' AND name = '<migration>';` + TODO to run reverse `manage.py migrate <app> <previous>`
  - Use `IF EXISTS` everywhere; no `CASCADE` unless the forward script created the dependent object

## Phase 5 — Confirm (mandatory before any Jira write)

EMIT plan table, then ask (ask_user tool) **Proceed?**:

| Card | Env | App | Current title → New title | Status | Assignee | Extras |
|---|---|---|---|---|---|---|

Extras: clone source, pair label, cleanup SQL path. Also list: Jira key used, `UNTIL` reasoning, Flyway reasons, warnings (weekend, merged MR, packages).
- IF: declined → STOP: nothing written; keep any SQL drafts and say where

## Phase 6 — Execute

- DO: re-run `check` (race guard). IF verdicts changed → STOP and report; do not write
- DO: confirm every cleanup SQL file exists before the first write
- LOOP (sequential): `clone` (if planned) → `chope` → `attach` cleanup SQL (Flyway = Yes); STORE each completed key
- IF: any command fails → STOP immediately. Writes are not transactional, so EMIT exactly which cards were already choped/cloned, then ask: roll back (run `release --key K --env E --app A [--remove-label <PAIR>]` for each choped card) or keep. Cloned cards stay on the board as Available placeholders (report them). Never leave a partial chope unreported

## Phase 7 — Verify & report

- DO: `list --env <ENV> --mine` → confirm every planned card is Occupied, `Dev In Progress`, assigned to user, title exact
- EMIT table: card link · new title · status · attachments. Remind: deploy your branch; release when done

## Release mode

- Cards: from MR (Phase 2 apps) or `list --env <ENV> --mine` → confirm selection with user
- IF: any card title has `Flyway= Yes` → ask: "Migration residues cleaned up (cleanup script run)?" — IF no → STOP (ReadMe: clean up before release)
- Pair labels: show each card's non-`CHOPE`/non-`WS*` labels; ask which are pairing-partner labels → pass each as `--remove-label` (never guess; unknown labels are kept)
- Confirm plan (old → placeholder title, → `To Do`, unassign, labels/attachments removed) → `release` each → verify with `list` → report (incl. `other_labels_kept`)
- Never `--force` without explicit user statement that the owner agreed

## Status mode

- `list --env <ENV> [--ws <WS>]` → EMIT table: app · column · assignee · title. Read-only

## Constraints

- All-or-nothing gate: if any required card is unavailable, chope none (the gate runs before writes; writes themselves are sequential — see Phase 6 rollback)
- Never edit/clone the ReadMe/Announcements card; never touch other workstreams' cards unless the user names that workstream
- Never take over a card assigned to someone else; never move cards that aren't the user's out of Occupied
- Never invent Jira keys, app names, or reverse SQL for irreversible changes
- Never print tokens; never use `curl -k`
- Every Jira write must be preceded by the Phase 5 confirmation in the same run
