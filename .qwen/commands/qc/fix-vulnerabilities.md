---
description: "Fetches all GitLab security vulnerabilities (all severities) from a report/MR URL or repo name, writes a single findings list, fixes each one, and syncs on re-invocation. Triggers: fix vulnerabilities, security dashboard, CVE fix, vulnerability scan, remediate findings."
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

## Step 1 — Branch Setup (first run)

- CALL: BRANCH_SETUP(REPO_DIR, BRANCH_PATTERN) → TICKET_NUM, BRANCH, DEFAULT_BRANCH

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

  - DO: apply fix; run verify (`./gradlew test && build` or `yarn test && build`)
  - IF: build fails → revert, mark `DEFERRED: {reason}`
  - IF: false positive → mark `SKIPPED`, dismiss via GraphQL `vulnerabilitiesDismiss`
  - DO: write `fix-{NNN}.md` in OUT_DIR; check off in OUT_FILE

## Step 5 — Commit, Push, MR

- CALL: COMMIT(REPO_DIR, `[GOBIZWKST2-${TICKET_NUM}] Vulnerability Fixes - {changelog}`) → COMMITTED
- IF: COMMITTED=false → skip push
- CALL: PUSH(REPO_DIR, BRANCH)
- CALL: ENSURE_MR(ENCODED, BRANCH, DEFAULT_BRANCH, title, body) → MR_IID, MR_URL

## Step 6 — Pipeline Watch Loop

- CALL: POLL_PIPELINE(ENCODED, MR_IID, COMMITTED)
  - ON_SUCCESS: fetch MR-scoped vulns; IF count=0 → done; else diff → fix → COMMIT → PUSH → reset → continue
  - ON_FAILURE: same as ON_SUCCESS
- STOP: success + 0 vulns | all DEFERRED/SKIPPED | 3 failures → BLOCKED | 20 polls → TIMEOUT

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
