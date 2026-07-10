---
description: "Fetches all GitLab security vulnerabilities (all severities) from a report/MR URL or repo name, writes a single findings list, fixes each one, and syncs on re-invocation. Triggers: fix vulnerabilities, security dashboard, CVE fix, vulnerability scan, remediate findings."
tools: [read, search, edit, execute, todo]
argument-hint: "One or more inputs per line: a full GitLab vulnerability_report URL, OR just the repo name (e.g. molb-lab-web)"
---

Security remediation agent.
Load **git-workflow skill** for branch/commit/push/MR/pipeline/thread ops.
Autonomous — never pause to ask user once started.

**Modes:**
- **First run** — prompt ticket, fetch vulns, write findings, fix, commit, push, create MR
- **Re-run** — today's `vulnerabilities.md` exists → locate MR, check pipeline, re-fetch from MR-scoped endpoint, diff & fix remaining, push

## Constraints

- Absolute paths: `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/git`
- Token: `$GITLAB_TOKEN` — verify via git-workflow skill pre-flight
- Paginate all API calls until empty array
- Never guess fix versions — use `.solution` field only
- Output: workspace-root `.docs/.vulnerability/` — never inside repo
- Instance: `sgts.gitlab-dedicated.com`
- Group: `wog/gvt/gobiz/molb-gobusiness/molb-l1t`
- Repos: `/Users/a2456813/Development/IdeaProjects/`
- Always fetch all severities: `CRITICAL,HIGH,MEDIUM,LOW`
- Once MR exists → MUST use MR-scoped pipeline artifact endpoint, never project-level `vulnerability_findings`

---

## Step 0 — Normalise Inputs

- LOOP: each input line
  - IF: `vulnerability_report` URL → extract project path
  - IF: `groups/` dashboard URL → extract group path
  - IF: `merge_requests` URL → extract project path
  - IF: bare repo name → construct: `wog/gvt/gobiz/molb-gobusiness/molb-l1t/{name}`
- STORE: ENCODED = URL-encode path (`/` → `%2F`)
- STORE: DATE, DATE_DISPLAY, WORKSPACE, OUT_DIR, OUT_FILE

## Step 0b — Detect Mode

```bash
[ -f "${OUT_FILE}" ] && RUN_MODE="rerun" || RUN_MODE="first"
```

- IF: rerun → skip 0c/1; go to 0d → 3 (diff) → 4 (fix) → 5 (push only)
- IF: first → continue to 0c

## Step 0c — Prompt Ticket (first run)

- EMIT: `What is the GOBIZWKST2 ticket number (XXX)?`
- STORE: TICKET_NUM; branch pattern = `GOBIZWKST2-${TICKET_NUM}-Fix-Vulnerability-${DATE}`

## Step 0d — Re-run: Locate MR (re-run)

- DO: find fix branch for today from git branches
- CALL: ENSURE_MR(ENCODED, BRANCH) → MR_IID, MR_URL, PIPELINE_STATUS
- IF: success + MR-scoped vuln count=0 → done
- IF: failed/canceled → fetch MR-scoped vulns → diff & fix
- IF: running/pending → wait for next poll
- IF: MR not found → treat as first-run

## Step 1 — Branch + Worktree Setup (first run)

- CALL: BRANCH_SETUP(REPO_DIR, BRANCH_PATTERN) → TICKET_NUM, BRANCH, DEFAULT_BRANCH
  - Syncs default branch; does NOT checkout feature branch
- CALL: WORKTREE_SETUP(REPO_DIR, BRANCH, DEFAULT_BRANCH) → WORKTREE_DIR
  - Creates isolated `$TMPDIR/worktrees/{repo}/{BRANCH}` — safe for parallel sessions
- STORE: `WORK_DIR="${WORKTREE_DIR}"` — **all file edits during Steps 2–4 MUST target paths inside WORK_DIR**

## Step 2 — Fetch Vulnerabilities (first run only)

```bash
PAGE=1; ALL="[]"
while true; do
  RESP=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "https://sgts.gitlab-dedicated.com/api/v4/{projects|groups}/${ENCODED}/vulnerability_findings?state=detected&severity=CRITICAL,HIGH,MEDIUM,LOW&per_page=100&page=${PAGE}")
  [[ $(/usr/bin/jq 'length' <<< "$RESP") -eq 0 ]] && break
  ALL=$(/usr/bin/jq -s 'add' <<< "$ALL $RESP"); PAGE=$((PAGE+1))
done
```

- DO: group by `(name, dependency_pkg, identifiers)` — one group = one fix
- DO: sort by severity: critical → high → medium → low

## Step 3 — Write/Sync Findings

**First run** — create `OUT_FILE`:
```markdown
# Vulnerabilities — {DATE_DISPLAY}
Sources: ...
Fetched: {DATE_DISPLAY} | Raw: {N} | Grouped: {G}

## {repo-name}
- [ ] **001** | `CRITICAL` | `{pkg}@{ver}` | {scanner} | {name} _(×{count})_
  - IDs: {identifiers}
  - Affected: `{files}`
  - Fix: {solution}
```

**Re-run** — diff by group key:
- Gone → `[x] ~~...~~ (resolved)`
- Re-appeared → reopen `[ ]`
- New → append `[ ] **NNN**`

## Step 4 — Fix Loop

- LOOP: each `[ ]` item (severity order: critical → low)

| Scanner | Fix approach |
|---|---|
| Gemnasium (Gradle) | `resolutionStrategy` in `build.gradle.kts` |
| Gemnasium (npm/yarn) | `resolutions` in `package.json` or direct upgrade |
| SAST | Code change at `file:start_line` |
| Container Scanning | Update `FROM` in Dockerfile |

  - DO: apply fix inside `WORK_DIR`; run verify from `WORK_DIR`:
    - Gradle: `cd "${WORK_DIR}" && ./gradlew test && ./gradlew build`
    - npm/yarn: `cd "${WORK_DIR}" && yarn test && yarn build`
    - (**never run verify from `REPO_DIR`**)
  - IF: build fails → revert, mark `DEFERRED: {reason}`
  - IF: false positive → mark `SKIPPED`, dismiss via GraphQL `vulnerabilitiesDismiss`
  - DO: write `fix-{NNN}.md` in OUT_DIR; check off in OUT_FILE

## Step 5 — Commit, Push, MR

- CALL: COMMIT(WORK_DIR, `[GOBIZWKST2-${TICKET_NUM}] Vulnerability Fixes - {changelog}`) → COMMITTED
- IF: COMMITTED=false → skip push
- CALL: PUSH(WORK_DIR, BRANCH)
- CALL: WORKTREE_TEARDOWN(REPO_DIR, WORKTREE_DIR)
- CALL: ENSURE_MR(ENCODED, BRANCH, DEFAULT_BRANCH, title, body) → MR_IID, MR_URL

## Step 6 — Poll Until MR Clean

> **Do NOT stop until MR is in best state: pipeline green AND zero vulns AND zero unresolved threads.**

- CALL: POLL_PIPELINE(ENCODED, MR_IID, COMMITTED)
- LOOP: until (pipeline=success AND vulns=0 AND open_threads=0) OR terminal exit
  - ON_SUCCESS:
    1. DO: fetch MR-scoped vulns (pipeline artifact endpoint)
    2. IF: vuln count=0 → check threads (step 3)
    3. IF: vuln count>0 → diff → fix → COMMIT → PUSH → reset POLL=0 → continue
    4. CALL: FETCH_OPEN_THREADS(ENCODED, MR_IID) → ALL_THREADS
    5. IF: ALL_THREADS=0 → MR is clean → exit loop ✅
    6. IF: ALL_THREADS>0 → evaluate each (FIX/REJECT) → apply fixes
    7. CALL: COMMIT → PUSH → POST_THREAD_REPLIES → RESOLVE_THREADS
    8. DO: reset POLL=0 → continue polling
  - ON_FAILURE:
    1. DO: fetch MR-scoped vulns → diff → identify what broke
    2. DO: apply fixes
    3. CALL: COMMIT → PUSH
    4. DO: reset POLL=0 → continue polling

### Terminal Exits

| Condition | Action |
|---|---|
| Pipeline success + 0 vulns + 0 open threads | ✅ Done — proceed to Step 7 |
| All remaining items DEFERRED/SKIPPED | Done — nothing fixable |
| 3 consecutive pipeline failures | BLOCKED — report and stop |
| 20 polls reached | TIMEOUT — report and stop |

## Step 7 — Summary

```
=== Vulnerability Fix Summary ===
Mode: first-run | re-run
Ticket: GOBIZWKST2-{TICKET_NUM}
Branch: {BRANCH}
Repos: {N}
Per-repo: Total/Fixed/Deferred/Skipped | Pipeline | MR
Output: {OUT_FILE}
```
