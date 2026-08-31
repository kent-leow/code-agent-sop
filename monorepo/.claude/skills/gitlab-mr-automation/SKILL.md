---
name: gitlab-mr-automation
description: 'Self-contained GitLab automation: branch from ticket, commit, push, create MR, poll pipeline + resolve review threads. Use for: implement task, fix review, automated workflow, submit code, push changes, create merge request, fix pipeline, resolve threads, prelude comments. No external skill dependencies.'
argument-hint: 'REPO_DIR, BRANCH_PATTERN (with {TICKET} placeholder), optional TICKET_NUM'
---

# gitlab-mr-automation

> Self-contained: ticket → branch → worktree → code → commit → push → MR → poll until pipeline=success AND open_threads=0.

## Globals

| Variable | Value |
|---|---|
| GitLab host | `sgts.gitlab-dedicated.com` |
| Token | `$GITLAB_TOKEN` |
| Binaries | `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/git` |
| Max polls | 20 |
| Max consecutive failures | 3 → `BLOCKED` |

> All `fetch`/`pull`/`push`/`clone` and API `curl` calls need network — request network access proactively, not after a sandbox block.

## Input → Output

| Input | Required | Description |
|---|---|---|
| `REPO_DIR` | ✓ | Absolute path to repo |
| `BRANCH_PATTERN` | ✓ | Pattern with `{TICKET}` placeholder |
| `TICKET_NUM` | | Auto-resolved if omitted |
| `COMMIT_MSG` | ✓ | Commit message |
| `MR_TITLE` | ✓ | Merge request title |

| Output | Description |
|---|---|
| `WORKTREE_DIR` | Isolated worktree path |
| `MR_URL` | MR link |
| `STATUS` | SUCCESS / BLOCKED / TIMEOUT |

---

## Phase 1 — Setup

1. Token pre-flight: `[ -n "$GITLAB_TOKEN" ] && echo OK || echo MISSING`
2. Resolve ENCODED project path from `git remote get-url origin`
3. Resolve ticket: caller → `jira.json` → current branch regex → ask user
4. `BRANCH` = substitute `{TICKET}` → `GOBIZWKST2-${TICKET_NUM}`
5. Create worktree:
```bash
cd "${REPO_DIR}"
REPO_NAME=$(basename "${REPO_DIR}")
WORKTREE_DIR="${TMPDIR:-/tmp}/worktrees/${REPO_NAME}/${BRANCH}"
[ -d "${WORKTREE_DIR}" ] && { /usr/bin/git worktree remove "${WORKTREE_DIR}" --force 2>/dev/null || true; rm -rf "${WORKTREE_DIR}" 2>/dev/null || true; }
if /usr/bin/git branch -a | grep -qE "(remotes/origin/|^  )${BRANCH}(\s|$)"; then
  /usr/bin/git worktree add "${WORKTREE_DIR}" "${BRANCH}" 2>/dev/null || \
    /usr/bin/git worktree add "${WORKTREE_DIR}" -b "${BRANCH}" "origin/${BRANCH}"
  cd "${WORKTREE_DIR}" && /usr/bin/git pull origin "${BRANCH}" 2>/dev/null || true
else
  /usr/bin/git worktree add -b "${BRANCH}" "${WORKTREE_DIR}" "${DEFAULT_BRANCH}"
fi
WORK_DIR="${WORKTREE_DIR}"
```

---

## Phase 2 — Code Changes

> Agent implements between Phase 1 and 3. All edits in `WORK_DIR` only. Local services: `cd "${WORK_DIR}"` first.

IF: no changes → STOP.

---

## Phase 3 — Commit & Push

Always squash all branch commits into a single commit, then force-push.

```bash
cd "${WORK_DIR}" && /usr/bin/git add -A
if ! /usr/bin/git diff --cached --quiet || [ "$(/usr/bin/git rev-list --count origin/${DEFAULT_BRANCH}..HEAD)" -gt 1 ]; then
  FORK_POINT=$(/usr/bin/git merge-base origin/${DEFAULT_BRANCH} HEAD)
  /usr/bin/git reset --soft "${FORK_POINT}"
  /usr/bin/git commit -m "${COMMIT_MSG}"; COMMITTED=true
else
  COMMITTED=false
fi
```
IF: `COMMITTED=false` → STOP.

```bash
cd "${WORK_DIR}" && /usr/bin/git push --force-with-lease origin "${BRANCH}"
cd "${REPO_DIR}" && /usr/bin/git worktree remove "${WORKTREE_DIR}" --force 2>/dev/null || true && /usr/bin/git worktree prune
```

---

## Phase 4 — Merge Request

```bash
EXISTING=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests?state=opened&source_branch=${BRANCH}" | /usr/bin/jq '.[0]')
MR_IID=$(echo "$EXISTING" | /usr/bin/jq -r '.iid // empty')
```
IF: exists → reuse. ELSE: `POST .../merge_requests` with `source_branch`, `target_branch`, `title`, `remove_source_branch: true`.

---

## Phase 5 — Threads-First & Poll Loop

> **Key insight:** Pushing restarts the pipeline. Process open threads IMMEDIATELY after push (before polling) — fixing threads early avoids wasted pipeline cycles.

### PRE-POLL: Fix Threads First

After Phase 4 (MR exists), BEFORE entering the poll loop:

1. Fetch open threads (paginate `/discussions?per_page=100`)
   - Filter: `resolved != true AND system != true`
   - Inline: `position != null`; General: `position == null AND author not bot`
2. IF: 0 threads → proceed to poll loop
3. Evaluate: actionable → `to_fix[]`; commentary → `to_reject[]`
4. IF: only rejections → post replies → proceed to poll loop
5. Re-create worktree → apply fixes → squash commit → force-push → teardown → post replies → resolve `to_fix[]` → reset poll (push already restarted pipeline)

### POLL LOOP

Adaptive schedule: 180s → 120s → 90s → 60s → 30s. Reset `POLL=0` after each push.

LOOP: while `POLL < 20`:
- `success|skipped|manual` → **ON_SUCCESS**
- `failed|canceled` → increment failures; ≥3 → BLOCKED; else **ON_FAILURE**
- `running|pending|...` → continue

### ON_SUCCESS

1. Fetch open threads (same filter as above)
2. IF: 0 threads → ✅ SUCCESS
3. Evaluate: actionable → `to_fix[]`; commentary → `to_reject[]`
4. IF: only rejections → post replies → SUCCESS
5. Re-create worktree → apply fixes → squash commit → force-push → teardown → post replies → resolve `to_fix[]` → reset poll

### ON_FAILURE

1. Fetch failed job logs: `GET .../pipelines/${PID}/jobs?scope=failed` → trace
2. Also fetch open threads — fix both pipeline AND threads in same pass (saves a cycle)
3. Re-create worktree → analyze + fix all → squash commit → force-push → teardown → reset poll

---

## Phase 6 — Terminal States

| Condition | Status |
|---|---|
| Pipeline success + 0 open threads | SUCCESS |
| Only rejected threads remain | SUCCESS |
| 3 consecutive pipeline failures | BLOCKED |
| 20 polls exceeded | TIMEOUT |

---

## Reply Templates

- **Fixed:** `Fixed — <what changed and where>.`
- **Rejected:** `Not applying — <reason>\n\n<1-2 sentences.>\n\nReason: <out of scope | misread | would break contract | style preference | needs clarification>`

## Commit Templates

| Context | Template |
|---|---|
| Implementation | `feat({scope}): {title} [GOBIZWKST2-{TICKET}]` |
| Review fix | `fix: address review comments` |
| Pipeline fix | `fix: resolve pipeline failure` |
| Vuln fix | `[GOBIZWKST2-{TICKET}] Vulnerability Fixes - {changelog}` |

## Constraints

- Absolute paths: `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/git`
- Always squash + force-push (`--force-with-lease`)
- Never commit secrets/tokens
- Never auto-approve or auto-merge
- Fix threads BEFORE waiting for pipeline (push restarts it anyway)
- Post replies BEFORE pipeline wait resumes
- Resolve only `to_fix[]` — leave `to_reject[]` open
- Run full loop without pausing
- Paginate all API calls until empty
