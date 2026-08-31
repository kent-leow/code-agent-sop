---
name: git-workflow
description: "Shared Git + platform workflow: branch setup, commit, push, MR creation, adaptive pipeline polling, review-thread lifecycle (inline + general). Load alongside git-apis skill."
---

# git-workflow

> CALL: git-apis skill for raw platform API calls.

## Globals

| Variable | Value |
|---|---|
| `WORKSPACE` | `/Users/a2456813/Development/IdeaProjects` |
| GitLab host | `sgts.gitlab-dedicated.com` |
| Tokens | `$GITLAB_TOKEN`, `$GITHUB_TOKEN` |
| Binaries | `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/git` |
| Max polls | 20 |
| Max consecutive failures | 3 → `BLOCKED` |

Token pre-flight: `echo "GL: $([ -n "$GITLAB_TOKEN" ] && echo OK || echo MISSING) | GH: $([ -n "$GITHUB_TOKEN" ] && echo OK || echo MISSING)"`

> All `fetch`/`pull`/`push`/`clone` and API `curl` calls need network — request network access proactively, not after a sandbox block.

---

## BRANCH_SETUP

**Inputs:** `REPO_DIR`, `BRANCH_PATTERN` → **Outputs:** `TICKET_NUM`, `BRANCH`, `DEFAULT_BRANCH`

1. Resolve ticket (first hit): caller-supplied → `jira.json` `.ticket` → current branch regex `GOBIZWKST2-(\d+)` → STOP: ask user
2. `BRANCH` = substitute `{TICKET}` → `GOBIZWKST2-${TICKET_NUM}`
3. Sync default branch:
```bash
cd "${REPO_DIR}"
DEFAULT_BRANCH=$(/usr/bin/git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "master")
/usr/bin/git checkout "${DEFAULT_BRANCH}" && /usr/bin/git pull origin "${DEFAULT_BRANCH}" && /usr/bin/git fetch origin
```

> After BRANCH_SETUP → call **WORKTREE_SETUP** before touching any files.

| Context | Pattern |
|---|---|
| Task impl | `GOBIZWKST2-{TICKET}-{kebab-task-title}` |
| Vuln fix | `GOBIZWKST2-{TICKET}-Fix-Vulnerability-{YYYYMMDD}` |
| Review fix | branch exists — skip BRANCH_SETUP |

---

## WORKTREE_SETUP

**Inputs:** `REPO_DIR`, `BRANCH`, `DEFAULT_BRANCH` → **Outputs:** `WORKTREE_DIR`

Creates isolated worktree — parallel sessions never share working tree. **All code changes in WORKTREE_DIR, not REPO_DIR.**

```bash
cd "${REPO_DIR}"
REPO_NAME=$(basename "${REPO_DIR}")
WORKTREE_DIR="${TMPDIR:-/tmp}/worktrees/${REPO_NAME}/${BRANCH}"

# Clean stale
[ -d "${WORKTREE_DIR}" ] && { /usr/bin/git worktree remove "${WORKTREE_DIR}" --force 2>/dev/null || true; rm -rf "${WORKTREE_DIR}" 2>/dev/null || true; }

# Create — reuse remote branch or branch from default
if /usr/bin/git branch -a | grep -qE "(remotes/origin/|^  )${BRANCH}(\s|$)"; then
  /usr/bin/git worktree add "${WORKTREE_DIR}" "${BRANCH}" 2>/dev/null || \
    /usr/bin/git worktree add "${WORKTREE_DIR}" -b "${BRANCH}" "origin/${BRANCH}"
  cd "${WORKTREE_DIR}" && /usr/bin/git pull origin "${BRANCH}" 2>/dev/null || true
else
  /usr/bin/git worktree add -b "${BRANCH}" "${WORKTREE_DIR}" "${DEFAULT_BRANCH}"
fi
```

- STORE: `WORK_DIR="${WORKTREE_DIR}"` — all edits, tests, builds, local services run from WORK_DIR

---

## WORKTREE_TEARDOWN

**Inputs:** `REPO_DIR`, `WORKTREE_DIR`

```bash
cd "${REPO_DIR}" && /usr/bin/git worktree remove "${WORKTREE_DIR}" --force 2>/dev/null || true && /usr/bin/git worktree prune
```

---

## COMMIT

**Inputs:** `WORK_DIR`, `COMMIT_MSG`, `DEFAULT_BRANCH` → **Outputs:** `COMMITTED` (bool), `COMMIT_SHA`

Always squash all branch commits into a single commit. This keeps history clean and simplifies force-push.

```bash
cd "${WORK_DIR}" && /usr/bin/git add -A
if ! /usr/bin/git diff --cached --quiet || [ "$(/usr/bin/git rev-list --count origin/${DEFAULT_BRANCH}..HEAD)" -gt 1 ]; then
  # Soft-reset to fork point, then commit everything as one
  FORK_POINT=$(/usr/bin/git merge-base origin/${DEFAULT_BRANCH} HEAD)
  /usr/bin/git reset --soft "${FORK_POINT}"
  /usr/bin/git commit -m "${COMMIT_MSG}"
  COMMIT_SHA=$(/usr/bin/git rev-parse --short HEAD); COMMITTED=true
else
  COMMITTED=false
fi
```

| Context | Template |
|---|---|
| Task impl | `feat({scope}): {title} [GOBIZWKST2-{TICKET}]` |
| Review fix | `fix: address review comments` |
| Pipeline fix | `fix: resolve pipeline failure` |
| Vuln fix | `[GOBIZWKST2-{TICKET}] Vulnerability Fixes - {changelog}` |
| Post-impl fix | `fix({scope}): {summary} [GOBIZWKST2-{TICKET}]` |

---

## PUSH

**Inputs:** `WORK_DIR`, `BRANCH` — **Always force-push** (single squashed commit guarantees rewritten history).

```bash
cd "${WORK_DIR}" && /usr/bin/git push --force-with-lease origin "${BRANCH}"
```

After push → call **WORKTREE_TEARDOWN**.

---

## ENSURE_MR

**Inputs:** `ENCODED`, `BRANCH`, `DEFAULT_BRANCH`, `MR_TITLE`, `MR_BODY` → **Outputs:** `MR_IID`, `MR_URL`

**GitLab:** Check `GET .../merge_requests?state=opened&source_branch=${BRANCH}` → if exists return; else `POST .../merge_requests` with `source_branch`, `target_branch`, `title`, `description`, `remove_source_branch: true`.

**GitHub:** Check `GET /repos/{owner}/{repo}/pulls?state=open&head={owner}:{BRANCH}` → if exists return; else `POST /repos/{owner}/{repo}/pulls`.

---

## FETCH_OPEN_THREADS

**Inputs:** `ENCODED`, `MR_IID` → **Outputs:** `INLINE_THREADS[]`, `GENERAL_THREADS[]`, `ALL_THREADS[]`

**GitLab:** Paginate `GET .../discussions?per_page=100` → filter:
- Inline: `resolved != true AND system != true AND position != null`
- General: `resolved != true AND system != true AND position == null AND author not bot/ci/scanner`

**GitHub:** Fetch review comments + issue comments → filter non-bot, unresolved.

General threads with actionable code requests → `to_fix[]`; commentary/questions → `to_reject[]`.

---

## POST_THREAD_REPLIES

Post all replies BEFORE pipeline wait.

- **Fixed:** `Fixed — <what changed and where>.`
- **Rejected:** `Not applying — <reason>\n\n<1-2 sentences.>\n\nReason: <out of scope | misread | would break contract | style preference | needs clarification>`

---

## RESOLVE_THREADS

Resolve only `to_fix[]` threads. Leave `to_reject[]` open.

**GitLab:** `PUT .../discussions/${THREAD_ID}?resolved=true`
**GitHub:** GraphQL `resolveReviewThread` or reply "Resolved."

---

## POLL_PIPELINE

**Inputs:** `ENCODED`, `MR_IID`, `COMMITTED` — IF: `COMMITTED=false` → skip.

> Run to completion without pausing. Terminal exits: SUCCESS, BLOCKED, TIMEOUT.

**Adaptive schedule:** 180s → 120s → 90s → 60s → 30s (repeat). Reset `POLL=0` after each push.

```bash
INTERVALS=(180 120 90 60 30); POLL=0; MAX_POLLS=20; CONSECUTIVE_FAILURES=0
while [ ${POLL} -lt ${MAX_POLLS} ]; do
  IDX=$(( POLL < ${#INTERVALS[@]} ? POLL : ${#INTERVALS[@]} - 1 ))
  sleep ${INTERVALS[${IDX}]}; POLL=$(( POLL + 1 ))
  PIPELINE_STATUS=$(curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/pipelines" \
    | /usr/bin/jq -r '.[0].status')
  case "${PIPELINE_STATUS}" in
    success|skipped|manual) break ;;
    failed|canceled) CONSECUTIVE_FAILURES=$(( CONSECUTIVE_FAILURES + 1 ))
      [ ${CONSECUTIVE_FAILURES} -ge 3 ] && { echo "BLOCKED"; break; } ;;
    *) continue ;;
  esac
done
```

**ON_SUCCESS:** Check threads → if 0 → done; if >0 → evaluate → WORKTREE_SETUP → fix → COMMIT → PUSH → TEARDOWN → RESOLVE → reset poll

**ON_FAILURE:** Inspect CI logs → WORKTREE_SETUP → fix → COMMIT → PUSH → TEARDOWN → reset poll

### Terminal Exits

| Condition | Result |
|---|---|
| Pipeline success + 0 threads (+ 0 vulns) | ✅ Done |
| All remaining DEFERRED/SKIPPED/REJECTED | Done |
| 3 consecutive failures | BLOCKED — stop |
| 20 polls | TIMEOUT — stop |

> **Do NOT stop before MR is in best state.**

---

## MR-scoped Vulnerabilities (fix-vulnerabilities only)

Once MR exists → use pipeline-scoped endpoint:
```bash
PIPELINE_ID=$(curl -s ... ".../merge_requests/${MR_IID}/pipelines" | jq -r '.[0].id')
MR_VULNS=$(curl -s ... ".../vulnerability_findings?pipeline_id=${PIPELINE_ID}&severity=CRITICAL,HIGH,MEDIUM,LOW&per_page=100" | jq '[.[] | select(.state=="detected")]')
```
Fallback: job artifact `gl-dependency-scanning-report.json`. Do NOT use `/merge_requests/{iid}/vulnerability_findings`.

---

## Constraints

- Absolute paths: `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/git`
- Never force-push
- Never commit secrets/tokens
- Never auto-approve or auto-merge
- Never fix beyond what was explicitly requested
- Paginate all list API calls until empty
- Post replies before pipeline wait
- Resolve only `to_fix[]` — leave `to_reject[]` open
- Run full workflow to completion without pausing
