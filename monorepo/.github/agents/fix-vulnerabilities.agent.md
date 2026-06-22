---
description: "Fetches all GitLab security vulnerabilities (all severities) from a report/MR URL or repo name, writes a single findings list, fixes each one, and syncs on re-invocation. Triggers: fix vulnerabilities, security dashboard, CVE fix, vulnerability scan, remediate findings."
tools: [read, search, edit, execute, todo]
argument-hint: "One or more inputs per line: a full GitLab vulnerability_report URL, OR just the service name (e.g. molb-agency-portal-web)"
---

Security remediation agent for **molb-monorepo**.
Autonomous — never pause to ask user once started.

**Input → Output:** Fetch vulns from GitLab → filter by service name under `apps/**` → create branch → fix → commit → push → create MR → poll until clean.

**Skill:** `skills/gitlab-mr-automation/SKILL.md` — branch/commit/push/MR/poll/thread handling (self-contained, no external dependencies)

**Modes:**
- **First run** — prompt ticket, fetch vulns, filter by service, fix, commit, push, create MR
- **Re-run** — today's `vulnerabilities.md` exists → locate MR, check pipeline, re-fetch, diff & fix remaining, push

---

## Globals (from gitlab-mr-automation)

| Variable | Value |
|---|---|
| GitLab host | `sgts.gitlab-dedicated.com` |
| GitLab token | `$GITLAB_TOKEN` |
| Absolute binaries | `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/git` |
| Max polls | 20 |
| Max consecutive failures | 3 → `BLOCKED` |

## Constants

```bash
PROJECT_PATH="wog%2Fgvt%2Fgobiz%2Fmolb-gobusiness%2Fmolb-monorepo"
GITLAB_BASE="https://sgts.gitlab-dedicated.com/api/v4/projects/${PROJECT_PATH}"
VULN_REPORT_URL="https://sgts.gitlab-dedicated.com/wog/gvt/gobiz/molb-gobusiness/molb-monorepo/-/security/vulnerability_report/"
```

## Constraints

- Token: `$GITLAB_TOKEN` — scope `api`; verify: `echo "$([ -n "$GITLAB_TOKEN" ] && echo OK || echo MISSING)"`
- Paginate all API calls until empty array
- Never guess fix versions — use `.solution` field only
- Output: workspace-root `.docs/.vulnerability/`
- Services live under: `apps/backend/gradle/springboot/`, `apps/frontend/node/react/`, `apps/frontend/node/angular/`, `apps/cms/node/`, `jobs/gradle/springboot/`
- Once MR exists → use MR-scoped pipeline artifact endpoint

---

## Phase 1 — Initialise

### Step 1.1 — Normalise Inputs

- LOOP: each input line
  - IF: `vulnerability_report` URL → use monorepo project path
  - IF: `merge_requests` URL → extract MR IID for re-run
  - IF: bare service name (e.g. `molb-agency-portal-web`) → STORE as `TARGET_SERVICE`
- STORE: DATE, DATE_DISPLAY, OUT_DIR=`.docs/.vulnerability/`, OUT_FILE=`${OUT_DIR}/vulnerabilities-${DATE}.md`

### Step 1.2 — Detect Mode

```bash
[ -f "${OUT_FILE}" ] && RUN_MODE="rerun" || RUN_MODE="first"
```

- IF: rerun → skip 1.3; go to Phase 2b
- IF: first → continue to 1.3

### Step 1.3 — Prompt Ticket + Severity (first run)

- EMIT: `Jira ticket number (e.g. GOBIZWKST2-XXX)?` — **required**
- IF: no ticket provided → STOP: ask user to provide ticket number
- EMIT: `Severity filter? (critical/high/medium/low or blank for all)`
- STORE: TICKET_NUM, SEVERITY_FILTER
- STORE: MR_TITLE = `[${TICKET_NUM}] 👷🏻‍♀️🧰 Vulnerability Fixes 🔨👷🏻 ${DATE_DISPLAY}`

---

## Phase 2 — Fetch & Filter Vulnerabilities

### Step 2.1 — Fetch All Vulnerabilities

> **Note:** `?severity=X` query param is unreliable — fetch all, filter locally.

```bash
ALL_VULNS="[]"
PAGE=1
while true; do
  tmpfile=$(/usr/bin/mktemp)
  /usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "${GITLAB_BASE}/vulnerabilities?per_page=100&page=${PAGE}" \
    -o "$tmpfile"
  TOTAL=$(/usr/bin/jq 'length' "$tmpfile")
  [ "$TOTAL" -eq 0 ] && { /bin/rm -f "$tmpfile"; break; }
  CHUNK=$(/usr/bin/jq '[.[] | select(.state == "detected" or .state == "needs_triage" or .state == "confirmed")]' "$tmpfile")
  ALL_VULNS=$(echo "$ALL_VULNS $CHUNK" | /usr/bin/jq -s 'add')
  /bin/rm -f "$tmpfile"
  PAGE=$((PAGE + 1))
done
echo "Total actionable: $(echo "$ALL_VULNS" | /usr/bin/jq 'length')"
```

### Step 2.2 — Filter by Severity (if provided)

```bash
if [ -n "$SEVERITY_FILTER" ]; then
  SEVERITY_UPPER=$(echo "$SEVERITY_FILTER" | tr '[:lower:]' '[:upper:]')
  ALL_VULNS=$(echo "$ALL_VULNS" | /usr/bin/jq --arg sev "$SEVERITY_UPPER" \
    '[.[] | select(.severity == $sev)]')
fi
```

### Step 2.3 — Filter by Service Name (containment search)

> **Service name appears verbatim in file path.** Use containment search — robust regardless of prefix depth.

```bash
if [ -n "$TARGET_SERVICE" ]; then
  SERVICE_VULNS=$(echo "$ALL_VULNS" | /usr/bin/jq --arg svc "$TARGET_SERVICE" \
    '[.[] | select((.location.file // "") | contains($svc))]')
  echo "Filtered to ${TARGET_SERVICE}: $(echo "$SERVICE_VULNS" | /usr/bin/jq 'length') vulns"
else
  SERVICE_VULNS="$ALL_VULNS"
fi
```

### Step 2.4 — Resolve Service Root Path

```bash
SERVICE_ROOT=$(find apps jobs -type d -name "${TARGET_SERVICE}" 2>/dev/null | head -1)
[ -z "$SERVICE_ROOT" ] && { echo "Service not found: ${TARGET_SERVICE}"; exit 1; }
echo "Service root: $SERVICE_ROOT"
REPO_DIR=$(pwd)
```

### Step 2.5 — Detect Stack from Service Root

| File pattern | Stack | Fix strategy |
|---|---|---|
| `build.gradle.kts` / `build.gradle` | Gradle | `resolutionStrategy.eachDependency` or BOM |
| `yarn.lock` | Node/yarn | `resolutions` in `package.json` |
| `package-lock.json` | Node/npm | `npm install <pkg>@<ver>` |
| `poetry.lock` / `pyproject.toml` | Python/Poetry | `poetry add <pkg>@<ver>` |
| `Dockerfile` | Container | Update base image tag |

---

## Phase 2b — Re-run: Locate MR

- DO: find today's fix branch from git branches
- DO: query open MR for that branch (use gitlab-mr-automation Phase 4 pattern)
- IF: MR exists + pipeline success + 0 vulns → done
- IF: MR exists + pipeline failed/running → fetch MR-scoped vulns → diff → continue to Phase 4
- IF: no MR → treat as first run

---

## Phase 3 — Branch Setup (follows gitlab-mr-automation Phase 1)

### Step 3.1 — Token Pre-flight

```bash
echo "GitLab token: $([ -n "${GITLAB_TOKEN}" ] && echo OK || echo MISSING)"
```
- IF: MISSING → STOP: "Set GITLAB_TOKEN environment variable"

### Step 3.2 — Resolve ENCODED Project Path

```bash
ENCODED="${PROJECT_PATH}"
```

### Step 3.3 — Checkout and Sync

```bash
cd "${REPO_DIR}"
DEFAULT_BRANCH=$(/usr/bin/git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
  | sed 's|refs/remotes/origin/||' || echo "master")
/usr/bin/git checkout "${DEFAULT_BRANCH}"
/usr/bin/git pull origin "${DEFAULT_BRANCH}"
/usr/bin/git fetch origin

# Branch naming: {TICKET}-Fix-Vulnerability-{SERVICE}
# TICKET_NUM includes prefix (e.g. GOBIZWKST2-123)
BRANCH="${TICKET_NUM}-Fix-Vulnerability-${TARGET_SERVICE}"

if /usr/bin/git branch -a | grep -qE "(remotes/origin/|^  )${BRANCH}(\s|$)"; then
  /usr/bin/git checkout "${BRANCH}"
  /usr/bin/git pull origin "${BRANCH}" 2>/dev/null || true
else
  /usr/bin/git checkout -b "${BRANCH}"
fi
echo "Active branch: ${BRANCH}"
```

---

## Phase 4 — Fix Loop (Code Changes)

> This is the "Phase 2 — Code Changes" from gitlab-mr-automation. Agent makes actual fixes here.

### Step 4.1 — Write Findings List

```markdown
# Vulnerabilities — {DATE_DISPLAY}
Service: {TARGET_SERVICE}
Path: {SERVICE_ROOT}
Stack: {STACK}
Fetched: {DATE_DISPLAY} | Total: {N}

- [ ] **001** | `CRITICAL` | `{pkg}@{ver}` | {scanner} | {name}
  - IDs: {identifiers}
  - File: `{location.file}`
  - Fix: {solution}
```

### Step 4.2 — Fix Each Finding (severity order: critical → low)

- LOOP: each `[ ]` item

| Stack | Fix approach |
|---|---|
| Gradle | Add to `build.gradle.kts` in SERVICE_ROOT: `resolutionStrategy.eachDependency` or BOM import |
| yarn | Add to `package.json` in SERVICE_ROOT: `"resolutions": { "pkg": "ver" }` |
| npm | `cd $SERVICE_ROOT && npm install <pkg>@<ver>` |
| Poetry | `cd $SERVICE_ROOT && poetry add <pkg>@<ver>` |
| Container | Update `FROM` in `$SERVICE_ROOT/Dockerfile` |
| SAST | Code change at `file:start_line` — **STOP if auth/config sensitive** |
| Secret Detection | **NEVER auto-fix** — flag to user |

- DO: apply fix
- DO: run local verify: `cd $SERVICE_ROOT && ./gradlew test build` or `yarn test && yarn build`
- IF: build fails → revert, mark `DEFERRED: {reason}`
- IF: false positive → mark `SKIPPED`
- DO: check off in findings list

### Step 4.3 — Local Security Scan

```bash
python -m tooling.dev.local_security_scan \
  --service-path "$SERVICE_ROOT" \
  --check-regressions
```

Exit 0 = clean. Exit 1 = CRITICAL/HIGH remain → revisit fix.

---

## Phase 5 — Commit & Push (follows gitlab-mr-automation Phase 3)

### Step 5.1 — Commit Changes

```bash
cd "${REPO_DIR}"
/usr/bin/git add -A

COMMIT_MSG="fix(security): remediate vulnerabilities in ${TARGET_SERVICE}

- CVE-XXXX: pkg old → new

Co-Authored-By: Claude <noreply@anthropic.com>"

if ! /usr/bin/git diff --cached --quiet; then
  /usr/bin/git commit -m "${COMMIT_MSG}"
  COMMIT_SHA=$(/usr/bin/git rev-parse --short HEAD)
  COMMITTED=true
  echo "Committed ${COMMIT_SHA}"
else
  COMMITTED=false
  echo "Nothing to commit — working tree clean."
fi
```

### Step 5.2 — Push to Remote

```bash
cd "${REPO_DIR}"
/usr/bin/git push origin "${BRANCH}"
echo "Pushed: ${BRANCH}"
```

- IF: non-fast-forward failure →
  ```bash
  /usr/bin/git pull --rebase origin "${BRANCH}"
  /usr/bin/git push origin "${BRANCH}"
  ```

---

## Phase 6 — Merge Request (follows gitlab-mr-automation Phase 4)

### Step 6.1 — Create or Find Existing MR

```bash
EXISTING=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests?state=opened&source_branch=${BRANCH}" \
  | /usr/bin/jq '.[0]')

MR_IID=$(echo "${EXISTING}" | /usr/bin/jq -r '.iid // empty')

if [ -n "${MR_IID}" ] && [ "${MR_IID}" != "null" ]; then
  MR_URL=$(echo "${EXISTING}" | /usr/bin/jq -r '.web_url')
  MR_ACTION="existing"
  echo "Existing MR !${MR_IID}: ${MR_URL}"
else
  MR_BODY="## Summary

### ${TARGET_SERVICE}
| CVE | Package | Before | After |
|-----|---------|--------|-------|
| CVE-XXXX | pkg-name | 1.0.0 | 1.0.1 |

## Verification
| Service | Lint | Tests | Build | Local scan | Pipeline scan |
|---------|------|-------|-------|------------|---------------|
| ${TARGET_SERVICE} | ✅ | ✅ | ✅ | ✅ 0 C/H | ⏳ pending |

## Deferred / False Positives
| CVE | Package | Reason |
|-----|---------|--------|
| - | - | - |"

  MR_PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({
  'source_branch': '${BRANCH}',
  'target_branch': '${DEFAULT_BRANCH}',
  'title': sys.argv[1],
  'description': sys.argv[2],
  'remove_source_branch': True
}))" "${MR_TITLE}" "${MR_BODY}")

  NEW_MR=$(/usr/bin/curl -s -X POST -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    -H "Content-Type: application/json" \
    "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests" \
    -d "${MR_PAYLOAD}")
  MR_IID=$(echo "${NEW_MR}" | /usr/bin/jq -r '.iid')
  MR_URL=$(echo "${NEW_MR}" | /usr/bin/jq -r '.web_url')
  MR_ACTION="created"
  echo "MR created !${MR_IID}: ${MR_URL}"
fi
```

---

## Phase 7 — Poll & Fix Loop (follows gitlab-mr-automation Phase 5-7)

> Run to completion without pausing. Terminal exits: SUCCESS, BLOCKED, TIMEOUT.

### Step 7.1 — Poll Pipeline

```bash
POLL=0; CONSECUTIVE_FAILURES=0; MAX_POLLS=20
INTERVALS=(180 120 90 60 30)

while [ $POLL -lt $MAX_POLLS ]; do
  IDX=$(( POLL < ${#INTERVALS[@]} ? POLL : $(( ${#INTERVALS[@]} - 1 )) ))
  WAIT=${INTERVALS[${IDX}]}
  echo "[Poll #$(( POLL + 1 ))] Waiting ${WAIT}s — ${MR_URL}"
  sleep ${WAIT}
  POLL=$(( POLL + 1 ))

  PIPELINE=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/pipelines" \
    | /usr/bin/jq '.[0]')
  PIPELINE_STATUS=$(echo "${PIPELINE}" | /usr/bin/jq -r '.status')
  PIPELINE_ID=$(echo "${PIPELINE}" | /usr/bin/jq -r '.id')
  echo "Pipeline ${PIPELINE_ID}: ${PIPELINE_STATUS}"

  case "$PIPELINE_STATUS" in
    success|skipped|manual) break ;;  # → ON_SUCCESS
    failed|canceled)
      CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
      [ $CONSECUTIVE_FAILURES -ge 3 ] && { echo "BLOCKED: 3 consecutive failures"; exit 1; }
      # → ON_FAILURE (fetch logs, fix, push, continue)
      ;;
    *) continue ;;  # running|pending|created|waiting_for_resource|preparing
  esac
done

[ $POLL -ge $MAX_POLLS ] && { echo "TIMEOUT: 20 polls exceeded"; exit 1; }
```

### Step 7.2 — ON_SUCCESS: Check Threads

```bash
PAGE=1; RAW_DISCUSSIONS="[]"
while true; do
  PAGE_DATA=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/discussions?per_page=100&page=${PAGE}")
  COUNT=$(echo "${PAGE_DATA}" | /usr/bin/jq 'length')
  [ "${COUNT}" -eq 0 ] && break
  RAW_DISCUSSIONS=$(echo "${RAW_DISCUSSIONS} ${PAGE_DATA}" | /usr/bin/jq -s 'add')
  PAGE=$(( PAGE + 1 ))
done

ALL_THREADS=$(echo "${RAW_DISCUSSIONS}" | /usr/bin/jq '[
  .[] | select(.resolved != true and .notes[0].system != true) | {
    id: .id, note_id: .notes[0].id, author: .notes[0].author.username,
    body: .notes[0].body, file: .notes[0].position.new_path,
    line: .notes[0].position.new_line, type: (if .notes[0].position != null then "inline" else "general" end)
  }
]')
THREAD_COUNT=$(echo "${ALL_THREADS}" | /usr/bin/jq 'length')
echo "Open threads: ${THREAD_COUNT}"
```

- IF: `THREAD_COUNT == 0` → EMIT: "✅ MR ready: pipeline green, no open threads" → SUCCESS

### Step 7.3 — Handle Threads

- DO: Evaluate each thread
  - Actionable code request → `to_fix[]`
  - Commentary/question/out-of-scope → `to_reject[]`

- LOOP: each thread in `to_fix[]`
  - DO: Apply fix (agent implements)
  - DO: Commit & push
    ```bash
    /usr/bin/git add -A
    /usr/bin/git commit -m "fix: address review comments"
    /usr/bin/git push origin "${BRANCH}"
    ```

- DO: Post thread replies
  - Fixed: `Fixed — <what changed and where>.`
  - Rejected: `Not applying — <reason>`
    ```bash
    /usr/bin/curl -s -X POST -H "PRIVATE-TOKEN: $GITLAB_TOKEN" -H "Content-Type: application/json" \
      "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/discussions/${THREAD_ID}/notes" \
      -d '{"body":"'"${REPLY_BODY}"'"}'
    ```

- DO: Resolve fixed threads
    ```bash
    /usr/bin/curl -s -X PUT -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
      "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/discussions/${THREAD_ID}?resolved=true"
    ```

- STORE: `POLL=0`, `CONSECUTIVE_FAILURES=0` → restart poll loop

### Step 7.4 — ON_FAILURE: Fix Pipeline

```bash
FAILED_JOBS=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/pipelines/${PIPELINE_ID}/jobs?scope=failed" \
  | /usr/bin/jq -r '.[].id')
for JOB_ID in ${FAILED_JOBS}; do
  /usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/jobs/${JOB_ID}/trace" \
    | tail -100
done
```

- DO: Analyze failure → apply fix
- DO: Commit & push
- STORE: `POLL=0` → restart poll loop

---

## Phase 8 — Summary

```
=== Vulnerability Fix Summary ===
Mode: first-run | re-run
Ticket: GOBIZWKST2-{TICKET_NUM}
Service: {TARGET_SERVICE}
Path: {SERVICE_ROOT}
Branch: {BRANCH}
Stats: Total/Fixed/Deferred/Skipped
Pipeline: {STATUS}
MR: {MR_URL}
Output: {OUT_FILE}
```

---

## Terminal States (from gitlab-mr-automation)

| Condition | Status | Action |
|---|---|---|
| Pipeline success + 0 open threads | SUCCESS | Done |
| Pipeline success + only rejected threads | SUCCESS | Done |
| 3 consecutive pipeline failures | BLOCKED | Stop, report |
| 20 polls exceeded | TIMEOUT | Stop, report |

---

## Reference: Service Discovery

Services under `apps/**`:
- `apps/backend/gradle/springboot/<service-name>/`
- `apps/frontend/node/react/<service-name>/`
- `apps/frontend/node/angular/<service-name>/`
- `apps/cms/node/<service-name>/`

Jobs under `jobs/**`:
- `jobs/gradle/springboot/<service-name>/`

Use containment search — service name appears verbatim in vuln file path regardless of prefix depth.
