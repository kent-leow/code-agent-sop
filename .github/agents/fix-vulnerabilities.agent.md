---
description: "Fetches all GitLab security vulnerabilities (all severities) from a report/MR URL or repo name, writes a single findings list, fixes each one, and syncs on re-invocation. Triggers: fix vulnerabilities, security dashboard, CVE fix, vulnerability scan, remediate findings."
tools: [read, search, edit, execute, todo]
argument-hint: "One or more inputs per line: a full GitLab vulnerability_report URL, OR just the repo name (e.g. molb-lab-web)"
---

**Input**: repo name / vulnerability URL / MR URL (+ Jira key) → **Output**: `<DOCS_DIR>/vulnerability/vulnerabilities-{DATE}.md`, fixes applied, MR pushed.

Load **docs-folder** and **git-workflow** skills. Autonomous — never pause once started.

**Modes**: First run (fetch + fix + MR) · Re-run (today's `vulnerabilities-{DATE}.md` exists in `DOCS_DIR` → diff + fix remaining)

---

## Config

| Key | Value |
|---|---|
| Instance | `sgts.gitlab-dedicated.com` |
| Group | `wog/gvt/gobiz/molb-gobusiness/molb-l1t` |
| Repos | `/Users/a2456813/Development/IdeaProjects/` |
| Severities | `CRITICAL,HIGH,MEDIUM,LOW` |
| Output | `<DOCS_DIR>/vulnerability/` (docs-folder skill) |
| Binaries | `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/git` |

## Step 0 — Normalise Inputs

- LOOP: each input → extract/construct project path → URL-encode as ENCODED
- STORE: DATE=`YYYYMMDD`
- IF: no `GOBIZWKST2-` key in input → EMIT: `GOBIZWKST2 ticket number?` → STORE: TICKET_NUM
- CALL: DOCS_FOLDER(REQUEST, TICKET=`GOBIZWKST2-${TICKET_NUM}`, TITLE=`fix-vulnerability-${DATE}`) → DOCS_DIR (reuses existing folder for that key)
- STORE: OUT_DIR=`${DOCS_DIR}/vulnerability/`, OUT_FILE=`${OUT_DIR}/vulnerabilities-${DATE}.md`

## Step 0b — Mode Detection

- IF: `OUT_FILE` exists → **re-run**: locate MR → skip to Step 3 (diff) → 4 → 5
- ELSE → **first run**: continue

## Step 0c — Branch Pattern (first run)

- STORE: BRANCH pattern from TICKET_NUM (Step 0)

## Step 1 — Branch + Worktree (first run)

- CALL: BRANCH_SETUP → WORKTREE_SETUP → STORE: `WORK_DIR`

## Step 2 — Fetch Vulnerabilities (first run)

- DO: paginate `/vulnerability_findings?state=detected&severity=...&per_page=100`
- DO: group by `(name, dependency_pkg, identifiers)` → sort critical→low

## Step 3 — Write/Sync Findings

- **First run**: create `OUT_FILE` with grouped checklist (severity, pkg, version, scanner, fix)
- **Re-run**: diff by group key — resolved→`[x]`, new→append `[ ]`, re-appeared→reopen

## Step 4 — Fix Loop

- LOOP: each `[ ]` item (severity order)

| Scanner | Approach |
|---|---|
| Gemnasium (Gradle) | `resolutionStrategy` in `build.gradle.kts` |
| Gemnasium (npm/yarn) | `resolutions`/direct upgrade in `package.json` |
| SAST | Code fix at `file:start_line` |
| Container Scanning | Update `FROM` in Dockerfile |

  - DO: apply fix in `WORK_DIR`; run verify (`./gradlew build` / `yarn build`)
  - IF: build fails → revert, mark `DEFERRED: reason`
  - IF: false positive → mark `SKIPPED`, dismiss via GraphQL

## Step 5 — Commit, Push, MR

- CALL: COMMIT(WORK_DIR, `[GOBIZWKST2-${TICKET_NUM}] Vulnerability Fixes`) → PUSH → WORKTREE_TEARDOWN → ENSURE_MR

## Step 6 — Poll Until Clean

> **Do NOT stop until pipeline green AND zero vulns AND zero unresolved threads.**

- CALL: POLL_PIPELINE(ENCODED, MR_IID, COMMITTED)
- LOOP: until (pipeline=success AND vulns=0 AND threads=0) OR terminal exit
  - ON_SUCCESS + vulns>0: diff → fix → COMMIT → PUSH → reset poll
  - ON_SUCCESS + threads>0: evaluate → fix → COMMIT → PUSH → RESOLVE → reset poll
  - ON_FAILURE: fetch MR-scoped vulns → fix → COMMIT → PUSH → reset poll

### Terminal Exits

| Condition | Action |
|---|---|
| Success + 0 vulns + 0 threads | ✅ Done |
| All remaining DEFERRED/SKIPPED | Done — nothing fixable |
| 3 consecutive failures | BLOCKED — stop |
| 20 polls | TIMEOUT — stop |

## Step 7 — Summary

- EMIT: mode, ticket, branch, repos, per-repo stats (total/fixed/deferred/skipped), pipeline, MR URL

## Constraints

- Never guess fix versions — use `.solution` field only
- Once MR exists → use MR-scoped pipeline artifact endpoint only
- Token: `$GITLAB_TOKEN`; paginate all API calls
- Never run verify from `REPO_DIR`
