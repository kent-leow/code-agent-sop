---
name: git-workflow
description: "Shared Git + platform workflow: branch setup, commit, push, MR creation, adaptive pipeline polling, review-thread lifecycle (inline + general). Load alongside git-apis skill."
---

# git-workflow

Branch management, commit, push, MR creation, adaptive pipeline polling, review-thread lifecycle (inline + general/prelude).

> Also load **git-apis skill** — git-workflow delegates raw platform API calls to it.

---

## Globals

| Variable | Value |
|---|---|
| `WORKSPACE` | `/Users/a2456813/Development/IdeaProjects` |
| GitLab host | `sgts.gitlab-dedicated.com` |
| GitLab token | `$GITLAB_TOKEN` |
| GitHub token | `$GITHUB_TOKEN` |
| Absolute binaries | `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/git` |
| Max polls | 20 per pipeline run |
| Max consecutive failures | 3 before `BLOCKED` |

**Token pre-flight (run once before first API call):**
```bash
echo "GitLab token: $([ -n "${GITLAB_TOKEN}" ] && echo OK || echo MISSING)"
echo "GitHub token: $([ -n "${GITHUB_TOKEN}" ] && echo OK || echo MISSING)"
```

---

## Operations

---

### BRANCH_SETUP — checkout default, pull, create or switch to feature branch

**Inputs:** `REPO_DIR` (absolute path), `BRANCH` (full branch name)  
**Outputs:** `DEFAULT_BRANCH`, active branch set to `BRANCH`

```bash
cd "${REPO_DIR}"

# 1. Detect default branch
DEFAULT_BRANCH=$(/usr/bin/git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
  | sed 's|refs/remotes/origin/||' || echo "master")

# 2. Sync default branch
/usr/bin/git checkout "${DEFAULT_BRANCH}"
/usr/bin/git pull origin "${DEFAULT_BRANCH}"

# 3. Fetch remote refs
/usr/bin/git fetch origin

# 4. Create or switch to feature branch
if /usr/bin/git branch -a | grep -qE "(remotes/origin/|^  )${BRANCH}(\s|$)"; then
  /usr/bin/git checkout "${BRANCH}"
  /usr/bin/git pull origin "${BRANCH}" 2>/dev/null || true   # ok if no remote yet
else
  /usr/bin/git checkout -b "${BRANCH}"
fi
echo "Active branch: ${BRANCH}"
```

**Branch naming conventions:**

| Context | Pattern |
|---|---|
| Vulnerability fixes | `GOBIZWKST2-{TICKET}-Fix-Vulnerability-{YYYYMMDD}` |
| Task implementation | `GOBIZWKST2-{TICKET}-{kebab-task-title}` |
| Post-implementation fix | reuse the task branch (checkout if exists, else create) |
| Review-fix workflow | branch already exists — skip BRANCH_SETUP; use FETCH_BRANCH instead |

**Detect current branch (review-fix mode):**
```bash
CURRENT_BRANCH=$(/usr/bin/git rev-parse --abbrev-ref HEAD)
```

---

### WORKTREE_SETUP — create isolated filesystem worktree for parallel session safety

**Inputs:** `REPO_DIR`, `BRANCH`, `DEFAULT_BRANCH`  
**Outputs:** `WORKTREE_DIR`, `WORK_DIR`

> Creates an isolated directory so parallel agent sessions never share a working tree. All code changes **MUST** happen in `WORK_DIR`, not `REPO_DIR`.

```bash
cd "${REPO_DIR}"
REPO_NAME=$(basename "${REPO_DIR}")
WORKTREE_DIR="${TMPDIR:-/tmp}/worktrees/${REPO_NAME}/${BRANCH}"

# Remove stale worktree at same path (handles crashed/restarted sessions)
if [ -d "${WORKTREE_DIR}" ]; then
  /usr/bin/git worktree remove "${WORKTREE_DIR}" --force 2>/dev/null || true
  rm -rf "${WORKTREE_DIR}" 2>/dev/null || true
fi

# Create worktree — reuse existing remote branch or branch from default
if /usr/bin/git branch -a | grep -qE "(remotes/origin/|^  )${BRANCH}(\s|$)"; then
  /usr/bin/git worktree add "${WORKTREE_DIR}" "${BRANCH}" 2>/dev/null || \
    /usr/bin/git worktree add "${WORKTREE_DIR}" -b "${BRANCH}" "origin/${BRANCH}"
  cd "${WORKTREE_DIR}" && /usr/bin/git pull origin "${BRANCH}" 2>/dev/null || true
else
  /usr/bin/git worktree add -b "${BRANCH}" "${WORKTREE_DIR}" "${DEFAULT_BRANCH}"
fi

WORK_DIR="${WORKTREE_DIR}"
echo "Worktree ready: ${WORKTREE_DIR} (branch: ${BRANCH})"
```

- DO: All subsequent file edits, test runs, and build commands must operate inside `WORK_DIR`
- DO: Pass `WORK_DIR` (not `REPO_DIR`) to COMMIT and PUSH

---

### WORKTREE_TEARDOWN — remove worktree after push

**Inputs:** `REPO_DIR`, `WORKTREE_DIR`

> Call after PUSH. Branch and remote tracking ref remain intact.

```bash
cd "${REPO_DIR}"
/usr/bin/git worktree remove "${WORKTREE_DIR}" --force 2>/dev/null || true
/usr/bin/git worktree prune
echo "Worktree removed: ${WORKTREE_DIR}"
```

---

### COMMIT — stage all changes and commit

**Inputs:** `WORK_DIR` (WORKTREE_DIR or REPO_DIR), `COMMIT_MSG`  
**Outputs:** `COMMITTED` (`true`/`false`), `COMMIT_SHA`

```bash
cd "${WORK_DIR}"
/usr/bin/git add -A

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

**Commit message conventions:**

| Context | Template |
|---|---|
| Review fix | `fix: address review comments\n\n- <file>:<line> — <summary>\n- ...` |
| Vulnerability fix | `[GOBIZWKST2-{TICKET}] Vulnerability Fixes - {pkg}@old → new, ...` |
| Vulnerability retry | `[GOBIZWKST2-{TICKET}] Vulnerability Fixes (retry) - {change_log}` |
| Task implementation | `feat({scope}): {task title} [GOBIZWKST2-{TICKET}]\n\nImplemented:\n- {file1}\n- {file2}` |
| Post-impl fix | `fix({scope}): {fix summary} [GOBIZWKST2-{TICKET}]` |

---

### PUSH — push branch to remote

**Inputs:** `WORK_DIR` (WORKTREE_DIR or REPO_DIR), `BRANCH`  
**Rule:** Never force-push (`--force`).

```bash
cd "${WORK_DIR}"
/usr/bin/git push origin "${BRANCH}"
echo "Pushed: ${BRANCH}"
```

If push fails with non-fast-forward (remote has commits ahead):
```bash
/usr/bin/git pull --rebase origin "${BRANCH}"
/usr/bin/git push origin "${BRANCH}"
```

- DO: After push, call **WORKTREE_TEARDOWN** to clean up the isolated worktree

---

### ENSURE_MR — find existing MR or create a new one

**Inputs:** `ENCODED` (URL-encoded project path), `BRANCH`, `DEFAULT_BRANCH`, `MR_TITLE`, `MR_BODY`  
**Outputs:** `MR_IID`, `MR_URL`, `MR_ACTION` (`created` | `existing`)

**GitLab:**
```bash
# 1. Look for existing open MR on this branch
EXISTING=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests?state=opened&source_branch=${BRANCH}" \
  | /usr/bin/jq '.[0]')

MR_IID=$(echo "${EXISTING}" | /usr/bin/jq -r '.iid // empty')

if [ -n "${MR_IID}" ] && [ "${MR_IID}" != "null" ]; then
  MR_URL=$(echo "${EXISTING}" | /usr/bin/jq -r '.web_url')
  MR_ACTION="existing"
  echo "Existing MR !${MR_IID}: ${MR_URL}"
else
  # 2. Build payload safely via python3 (avoids shell quoting issues in multiline bodies)
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

**GitHub:**
```bash
# Check for existing open PR
EXISTING_PR=$(/usr/bin/curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/${OWNER}/${REPO}/pulls?state=open&head=${OWNER}:${BRANCH}" \
  | /usr/bin/jq '.[0]')

MR_IID=$(echo "${EXISTING_PR}" | /usr/bin/jq -r '.number // empty')

if [ -n "${MR_IID}" ] && [ "${MR_IID}" != "null" ]; then
  MR_URL=$(echo "${EXISTING_PR}" | /usr/bin/jq -r '.html_url')
  MR_ACTION="existing"
  echo "Existing PR #${MR_IID}: ${MR_URL}"
else
  PR_PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({'head': '${BRANCH}', 'base': '${DEFAULT_BRANCH}',
  'title': sys.argv[1], 'body': sys.argv[2]}))" "${MR_TITLE}" "${MR_BODY}")

  NEW_PR=$(/usr/bin/curl -s -X POST -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.github.com/repos/${OWNER}/${REPO}/pulls" \
    -d "${PR_PAYLOAD}")
  MR_IID=$(echo "${NEW_PR}" | /usr/bin/jq -r '.number')
  MR_URL=$(echo "${NEW_PR}" | /usr/bin/jq -r '.html_url')
  MR_ACTION="created"
  echo "PR created #${MR_IID}: ${MR_URL}"
fi
```

---

### FETCH_OPEN_THREADS — inline review + general/prelude threads

**Inputs:** `ENCODED`, `MR_IID` (GitLab) OR `OWNER`, `REPO`, `MR_IID` (GitHub)  
**Outputs:** `INLINE_THREADS[]`, `GENERAL_THREADS[]`, `ALL_THREADS[]`

Fetches ALL open, non-system, non-bot threads — both line-attached (inline review) and general (prelude/summary notes from humans).

**GitLab:**
```bash
# Paginate — discussions can exceed 100
PAGE=1; RAW_DISCUSSIONS="[]"
while true; do
  PAGE_DATA=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/discussions?per_page=100&page=${PAGE}")
  COUNT=$(echo "${PAGE_DATA}" | /usr/bin/jq 'length')
  [ "${COUNT}" -eq 0 ] && break
  RAW_DISCUSSIONS=$(echo "${RAW_DISCUSSIONS} ${PAGE_DATA}" | /usr/bin/jq -s 'add')
  PAGE=$(( PAGE + 1 ))
done

# Inline threads — have a diff position (line-attached review comments)
INLINE_THREADS=$(echo "${RAW_DISCUSSIONS}" | /usr/bin/jq '[
  .[] | select(
    .resolved != true and
    .notes[0].system != true and
    .notes[0].position != null
  ) | {
    id: .id,
    note_id: .notes[0].id,
    author: .notes[0].author.username,
    body: .notes[0].body,
    file: .notes[0].position.new_path,
    line: .notes[0].position.new_line,
    replies: [.notes[1:][]],
    type: "inline"
  }
]')

# General / prelude threads — no diff position; exclude system notes and CI/bot authors
GENERAL_THREADS=$(echo "${RAW_DISCUSSIONS}" | /usr/bin/jq '[
  .[] | select(
    .resolved != true and
    .notes[0].system != true and
    .notes[0].position == null and
    (.notes[0].author.username | test("bot|pipeline|ci|scanner|gitlab"; "i") | not)
  ) | {
    id: .id,
    note_id: .notes[0].id,
    author: .notes[0].author.username,
    body: .notes[0].body,
    file: null,
    line: null,
    replies: [.notes[1:][]],
    type: "general"
  }
]')
```

**GitHub:**
```bash
# Inline review comments (line-attached, root threads only)
REVIEW_COMMENTS=$(/usr/bin/curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/${OWNER}/${REPO}/pulls/${MR_IID}/comments?per_page=100")
INLINE_THREADS=$(echo "${REVIEW_COMMENTS}" | /usr/bin/jq '[
  .[] | select(.in_reply_to_id == null) | {
    id: .id,
    node_id: .node_id,
    author: .user.login,
    body: .body,
    file: .path,
    line: (.line // .original_line),
    replies: [],
    type: "inline"
  }
]')

# General PR comments (issue comments — non-line-attached)
ISSUE_COMMENTS=$(/usr/bin/curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/${OWNER}/${REPO}/issues/${MR_IID}/comments?per_page=100")
GENERAL_THREADS=$(echo "${ISSUE_COMMENTS}" | /usr/bin/jq '[
  .[] | select(
    (.user.type // "User") != "Bot" and
    (.user.login | test("bot|ci|actions|scanner"; "i") | not)
  ) | {
    id: .id,
    author: .user.login,
    body: .body,
    file: null,
    line: null,
    replies: [],
    type: "general"
  }
]')
```

**Combine:**
```bash
ALL_THREADS=$(echo "${INLINE_THREADS} ${GENERAL_THREADS}" \
  | /usr/bin/jq -s 'add // []')

INLINE_COUNT=$(echo "${INLINE_THREADS}" | /usr/bin/jq 'length')
GENERAL_COUNT=$(echo "${GENERAL_THREADS}" | /usr/bin/jq 'length')
echo "Open threads — inline: ${INLINE_COUNT}, general/prelude: ${GENERAL_COUNT}"
```

Evaluate general threads with the same FIX/REJECT rules as inline threads. General threads that are actionable (request a code change) → `to_fix[]`; commentary/questions → `to_reject[]` with a clarifying reply.

---

### POST_THREAD_REPLIES — post fix / reject replies

Use **git-apis skill → REPLY** for every thread that was evaluated.

Post all replies **before** starting the pipeline wait.

**Fixed thread reply:**
```
✅ **Fixed** — <one sentence: what changed and where>.
```

**Rejected thread reply:**
```
⛔ **Not applying — <Short reason title>**

<1–2 sentences explaining why this change was not made.>

**Reason:** <out of scope | reviewer misread | would break contract | style preference | needs author clarification>

<If actionable: suggest next step or follow-up ticket.>
```

---

### RESOLVE_THREADS — resolve fixed threads after pipeline success

For each thread in `to_fix[]` that was fixed AND replied to:

**GitLab:**
```bash
/usr/bin/curl -s -X PUT -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/discussions/${THREAD_ID}?resolved=true" \
  | /usr/bin/jq -r '.resolved'
```

**GitHub** — use git-apis skill → RESOLVE.  
If thread node ID unavailable → reply `✅ Resolved.` and note the limitation.

Only resolve threads in `to_fix[]`. Leave `to_reject[]` threads open for author follow-up.

---

### POLL_PIPELINE — adaptive polling with ON_SUCCESS / ON_FAILURE hooks

**Inputs:** `ENCODED`, `MR_IID`, `COMMITTED`  
**Skip entirely** if `COMMITTED=false`.

#### Adaptive schedule

```
Poll #  Wait     Rationale
  1     180 s    CI initialisation + dependency scanning
  2     120 s    Still starting
  3      90 s    Mid-run
  4      60 s    Approaching end
  5+     30 s    Tight — pipeline nearly done
```

For review-only pipelines (no scanning jobs) agents MAY use first interval of 120 s.  
**Reset POLL=0 after each push** so the schedule restarts from long intervals for the new pipeline.

#### Poll loop

```bash
INTERVALS=(180 120 90 60 30)
POLL=0
MAX_POLLS=20
CONSECUTIVE_FAILURES=0

while [ ${POLL} -lt ${MAX_POLLS} ]; do
  IDX=$(( POLL < ${#INTERVALS[@]} ? POLL : $(( ${#INTERVALS[@]} - 1 )) ))
  WAIT=${INTERVALS[${IDX}]}
  echo "[Poll #$(( POLL + 1 ))] Waiting ${WAIT}s — ${MR_URL}"
  sleep ${WAIT}
  POLL=$(( POLL + 1 ))

  # GitLab — latest pipeline on the MR
  PIPELINE=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/pipelines" \
    | /usr/bin/jq '.[0]')
  PIPELINE_STATUS=$(echo "${PIPELINE}" | /usr/bin/jq -r '.status')
  PIPELINE_URL=$(echo "${PIPELINE}"   | /usr/bin/jq -r '.web_url')
  PIPELINE_ID=$(echo "${PIPELINE}"    | /usr/bin/jq -r '.id')
  echo "Pipeline ${PIPELINE_ID}: ${PIPELINE_STATUS} — ${PIPELINE_URL}"

  # GitHub — latest check suite
  # CHECKS=$(/usr/bin/curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  #   "https://api.github.com/repos/${OWNER}/${REPO}/commits/${HEAD_SHA}/check-suites")
  # PIPELINE_STATUS=$(echo "${CHECKS}" | /usr/bin/jq -r '.check_suites[0].conclusion // .check_suites[0].status')

  case "${PIPELINE_STATUS}" in
    success)
      CONSECUTIVE_FAILURES=0
      echo "Pipeline passed."
      # ► Execute caller's ON_SUCCESS hook (defined below by each agent)
      break
      ;;
    failed|canceled)
      CONSECUTIVE_FAILURES=$(( CONSECUTIVE_FAILURES + 1 ))
      echo "Pipeline ${PIPELINE_STATUS} (consecutive: ${CONSECUTIVE_FAILURES}) — ${PIPELINE_URL}"
      [ ${CONSECUTIVE_FAILURES} -ge 3 ] && { echo "BLOCKED: 3 consecutive failures."; break; }
      # ► Execute caller's ON_FAILURE hook (defined below by each agent)
      # After applying fixes → COMMIT → PUSH → reset:
      # POLL=0; CONSECUTIVE_FAILURES=0
      ;;
    running|pending|created|waiting_for_resource|preparing)
      echo "Pipeline still ${PIPELINE_STATUS}. Continuing..."
      ;;
    skipped|manual)
      echo "Pipeline ${PIPELINE_STATUS}."
      # ► Execute caller's ON_SUCCESS hook (treat as success for domain checks)
      break
      ;;
    *)
      echo "Unknown status '${PIPELINE_STATUS}'. Continuing."
      ;;
  esac
done

[ ${POLL} -ge ${MAX_POLLS} ] && echo "TIMEOUT: exceeded ${MAX_POLLS} polls — manual check required."
```

#### ON_SUCCESS hook — caller defines

| Agent | ON_SUCCESS action |
|---|---|
| `git-fix-review` | → RESOLVE_THREADS for all `to_fix[]` items |
| `fix-vulnerabilities` | Re-fetch MR-scoped vulns; if count=0 → done; else diff & fix → COMMIT → PUSH → reset POLL |
| `execute-task` / `fix-task` | → FETCH_OPEN_THREADS → evaluate → fix → COMMIT → PUSH → POST_THREAD_REPLIES → RESOLVE_THREADS |

#### ON_FAILURE hook — caller defines

| Agent | ON_FAILURE action |
|---|---|
| `git-fix-review` | Re-fetch ALL_THREADS → re-evaluate (Steps 3→4→5) → COMMIT → PUSH → reset POLL |
| `fix-vulnerabilities` | Re-fetch MR-scoped vulns → fix remaining (Step 4) → COMMIT → PUSH → reset POLL |
| `execute-task` / `fix-task` | Inspect build/test logs → fix compilation or test failures → COMMIT → PUSH → reset POLL |

#### Exit conditions (any → break loop)

| Condition | Result |
|---|---|
| Pipeline `success` AND all domain checks pass | ✅ Done |
| All remaining items `DEFERRED` / `SKIPPED` / `REJECTED` | ✅ Done (nothing left to fix) |
| `CONSECUTIVE_FAILURES >= 3` | 🚫 `BLOCKED` |
| `POLL >= MAX_POLLS` | ⏱ `TIMEOUT` |

---

## MR-scoped vulnerability source (fix-vulnerabilities only)

> Once an MR exists, ALL vulnerability fetching MUST use the MR-scoped pipeline endpoint.  
> The project-level endpoint reflects only the default branch.

**Preferred — pipeline-scoped findings:**
```bash
PIPELINE_ID=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/pipelines" \
  | /usr/bin/jq -r '.[0].id')

MR_VULNS=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/vulnerability_findings?pipeline_id=${PIPELINE_ID}&severity=CRITICAL,HIGH,MEDIUM,LOW&per_page=100" \
  | /usr/bin/jq 'if type=="array" then [.[] | select(.state == "detected")] else [] end')
MR_VULN_COUNT=$(echo "${MR_VULNS}" | /usr/bin/jq 'length')
```

**Fallback — job artifact download** (if pipeline-scoped returns empty/error):
```bash
DS_JOB_ID=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/pipelines/${PIPELINE_ID}/jobs?per_page=100" \
  | /usr/bin/jq -r '[.[] | select(.name | test("dependency-scanning|gemnasium"))] | .[0].id')

/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/jobs/${DS_JOB_ID}/artifacts/gl-dependency-scanning-report.json" \
  -o /tmp/ds-report.json
MR_VULNS=$(cat /tmp/ds-report.json \
  | /usr/bin/jq '[.vulnerabilities[] | select(.state == "detected")]' 2>/dev/null || echo "[]")
MR_VULN_COUNT=$(echo "${MR_VULNS}" | /usr/bin/jq 'length')
```

> Do NOT use `/merge_requests/{iid}/vulnerability_findings` — returns 404 on this GitLab instance.

---

## Usage Reference

In every agent that uses git workflow, add to the header:
> Load **git-workflow skill** for all branch/commit/push/MR/pipeline/thread operations.

Reference operations by name in agent steps:

```
→ skill: BRANCH_SETUP        — checkout default, pull, create/switch feature branch
→ skill: COMMIT              — git add -A; commit if staged changes exist
→ skill: PUSH                — git push origin <branch>; no force
→ skill: ENSURE_MR           — find existing open MR or create new one
→ skill: FETCH_OPEN_THREADS  — inline review + general/prelude threads (paginated)
→ skill: POST_THREAD_REPLIES — ✅ fixed / ⛔ rejected replies before pipeline wait
→ skill: RESOLVE_THREADS     — resolve to_fix[] threads after pipeline success
→ skill: POLL_PIPELINE       — adaptive poll loop; callers define ON_SUCCESS/ON_FAILURE hooks
```

---

## Constraints

- Absolute paths: `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/git`
- Never force-push (`--force`)
- Never commit secrets, tokens, or credentials
- Never auto-approve or auto-merge
- Never fix beyond what was explicitly requested in a thread
- Paginate all list API calls until response length is 0
- Post thread replies before starting pipeline wait — never after
- Resolve only `to_fix[]` threads — leave `to_reject[]` open
- If a fix touches code with no test coverage, note it in the reply but do not block the fix
