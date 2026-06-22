---
name: gitlab-mr-automation
description: 'Self-contained GitLab automation: branch from ticket, commit, push, create MR, poll pipeline + resolve review threads. Use for: implement task, fix review, automated workflow, submit code, push changes, create merge request, fix pipeline, resolve threads, prelude comments. No external skill dependencies.'
argument-hint: 'REPO_DIR, BRANCH_PATTERN (with {TICKET} placeholder), optional TICKET_NUM'
---

# gitlab-mr-automation

> Self-contained GitLab automation: ticket → branch → code → commit → push → MR → poll until pipeline=success AND open_threads=0.

## Globals

| Variable | Value |
|---|---|
| GitLab host | `sgts.gitlab-dedicated.com` |
| GitLab token | `$GITLAB_TOKEN` |
| Absolute binaries | `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/git` |
| Max polls | 20 |
| Max consecutive failures | 3 → `BLOCKED` |

---

## Input → Output

| Input | Required | Description |
|---|---|---|
| `REPO_DIR` | ✓ | Absolute path to repo |
| `BRANCH_PATTERN` | ✓ | Pattern with `{TICKET}` placeholder |
| `TICKET_NUM` | | Extracted from jira.json/branch if omitted |
| `COMMIT_MSG` | ✓ | Initial commit message |
| `MR_TITLE` | ✓ | Merge request title |
| `MR_BODY` | | MR description (optional) |

| Output | Description |
|---|---|
| `MR_URL` | Created/existing MR link |
| `STATUS` | SUCCESS / BLOCKED / TIMEOUT |

### Branch Pattern Examples

| Context | Pattern |
|---|---|
| Task implementation | `GOBIZWKST2-{TICKET}-{kebab-task-title}` |
| Vulnerability fixes | `GOBIZWKST2-{TICKET}-Fix-Vulnerability-{YYYYMMDD}` |
| Hotfix | `GOBIZWKST2-{TICKET}-hotfix-{description}` |

---

## Phase 1 — Setup

1. DO: Token pre-flight
   ```bash
   echo "GitLab token: $([ -n "${GITLAB_TOKEN}" ] && echo OK || echo MISSING)"
   ```
   - IF: MISSING → STOP: "Set GITLAB_TOKEN environment variable"

2. DO: Resolve `ENCODED` project path
   ```bash
   cd "${REPO_DIR}"
   REMOTE_URL=$(/usr/bin/git remote get-url origin)
   PROJECT_PATH=$(echo "${REMOTE_URL}" | sed -E 's|.*gitlab[^/]*/||; s|\.git$||')
   ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${PROJECT_PATH}', safe=''))")
   ```

3. DO: Resolve ticket number (stop at first hit)
   1. Caller-supplied `TICKET_NUM`
   2. `jira.json` → read `.ticket` → extract numeric part
   3. Current branch → parse `GOBIZWKST2-(\d+)`
      ```bash
      TICKET_NUM=$(/usr/bin/git rev-parse --abbrev-ref HEAD 2>/dev/null \
        | grep -oE 'GOBIZWKST2-[0-9]+' | grep -oE '[0-9]+' || true)
      ```
   4. IF: still empty → STOP: ask user for GOBIZWKST2 ticket number

4. STORE: `BRANCH` = substitute `{TICKET}` in `BRANCH_PATTERN` with `GOBIZWKST2-${TICKET_NUM}`

5. DO: Checkout and sync
   ```bash
   cd "${REPO_DIR}"
   DEFAULT_BRANCH=$(/usr/bin/git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
     | sed 's|refs/remotes/origin/||' || echo "master")
   /usr/bin/git checkout "${DEFAULT_BRANCH}"
   /usr/bin/git pull origin "${DEFAULT_BRANCH}"
   /usr/bin/git fetch origin

   if /usr/bin/git branch -a | grep -qE "(remotes/origin/|^  )${BRANCH}(\s|$)"; then
     /usr/bin/git checkout "${BRANCH}"
     /usr/bin/git pull origin "${BRANCH}" 2>/dev/null || true
   else
     /usr/bin/git checkout -b "${BRANCH}"
   fi
   echo "Active branch: ${BRANCH}"
   ```

---

## Phase 2 — Code Changes

> Agent makes code changes between Phase 1 and Phase 3. This skill does NOT implement code — it orchestrates the git workflow.

6. IF: No code changes made → STOP: "No changes to commit."

---

## Phase 3 — Commit & Push

7. DO: Commit changes
   ```bash
   cd "${REPO_DIR}"
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

8. IF: `COMMITTED=false` → STOP: "Nothing to commit — working tree clean."

9. DO: Push to remote (never force-push)
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

## Phase 4 — Merge Request

10. DO: Create or find existing MR
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

11. EMIT: `MR ${MR_ACTION}: ${MR_URL}`

---

## Phase 5 — Poll & Fix Loop

> Run to completion without pausing. Terminal exits: SUCCESS, BLOCKED, TIMEOUT.

12. STORE: `POLL=0`, `CONSECUTIVE_FAILURES=0`, `MAX_POLLS=20`

13. LOOP: while `POLL < MAX_POLLS`
    ```bash
    INTERVALS=(180 120 90 60 30)
    IDX=$(( POLL < ${#INTERVALS[@]} ? POLL : $(( ${#INTERVALS[@]} - 1 )) ))
    WAIT=${INTERVALS[${IDX}]}
    echo "[Poll #$(( POLL + 1 ))] Waiting ${WAIT}s — ${MR_URL}"
    sleep ${WAIT}
    POLL=$(( POLL + 1 ))

    PIPELINE=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
      "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/pipelines" \
      | /usr/bin/jq '.[0]')
    PIPELINE_STATUS=$(echo "${PIPELINE}" | /usr/bin/jq -r '.status')
    PIPELINE_URL=$(echo "${PIPELINE}" | /usr/bin/jq -r '.web_url')
    PIPELINE_ID=$(echo "${PIPELINE}" | /usr/bin/jq -r '.id')
    echo "Pipeline ${PIPELINE_ID}: ${PIPELINE_STATUS} — ${PIPELINE_URL}"
    ```
    - IF: `status=success` → goto ON_SUCCESS (Phase 6)
    - IF: `status=failed|canceled` → `CONSECUTIVE_FAILURES++`
      - IF: `CONSECUTIVE_FAILURES >= 3` → STOP: "BLOCKED: 3 consecutive failures"
      - ELSE: goto ON_FAILURE (Phase 7)
    - IF: `status=running|pending|created|waiting_for_resource|preparing` → continue loop
    - IF: `status=skipped|manual` → goto ON_SUCCESS (Phase 6)

---

## Phase 6 — ON_SUCCESS

14. DO: Fetch open threads
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

    INLINE_THREADS=$(echo "${RAW_DISCUSSIONS}" | /usr/bin/jq '[
      .[] | select(
        .resolved != true and
        .notes[0].system != true and
        .notes[0].position != null
      ) | {
        id: .id, note_id: .notes[0].id, author: .notes[0].author.username,
        body: .notes[0].body, file: .notes[0].position.new_path,
        line: .notes[0].position.new_line, replies: [.notes[1:][]], type: "inline"
      }
    ]')

    GENERAL_THREADS=$(echo "${RAW_DISCUSSIONS}" | /usr/bin/jq '[
      .[] | select(
        .resolved != true and
        .notes[0].system != true and
        .notes[0].position == null and
        (.notes[0].author.username | test("bot|pipeline|ci|scanner|gitlab"; "i") | not)
      ) | {
        id: .id, note_id: .notes[0].id, author: .notes[0].author.username,
        body: .notes[0].body, file: null, line: null, replies: [.notes[1:][]], type: "general"
      }
    ]')

    ALL_THREADS=$(echo "${INLINE_THREADS} ${GENERAL_THREADS}" | /usr/bin/jq -s 'add // []')
    THREAD_COUNT=$(echo "${ALL_THREADS}" | /usr/bin/jq 'length')
    echo "Open threads: ${THREAD_COUNT}"
    ```
    - Note: Prelude/bot threads included — treat same as human reviewer

15. IF: `THREAD_COUNT == 0` → EMIT: "✅ MR ready: pipeline green, no open threads" → STOP: SUCCESS

16. DO: Evaluate each thread (human AND prelude/bot)
    - Actionable code request → `to_fix[]`
    - Commentary/question/out-of-scope → `to_reject[]`

17. IF: `to_fix.length == 0` AND `to_reject.length > 0`:
    - DO: Post rejection replies (see Reply section)
    - EMIT: "✅ MR ready: pipeline green, remaining threads rejected"
    - STOP: SUCCESS

18. LOOP: each thread in `to_fix[]`
    - DO: Apply fix (agent implements)
    - STORE: fix details for commit message

19. DO: Commit fix
    ```bash
    cd "${REPO_DIR}"
    /usr/bin/git add -A
    /usr/bin/git commit -m "fix: address review comments"
    ```

20. DO: Push
    ```bash
    /usr/bin/git push origin "${BRANCH}"
    ```

21. DO: Post thread replies (BEFORE resuming poll)
    - Fixed thread reply: `Fixed — <one sentence: what changed and where>.`
    - Rejected thread reply: `Not applying — <reason title>\n\n<1-2 sentences why.>\n\nReason: <out of scope | reviewer misread | would break contract | style preference | needs author clarification>`
    ```bash
    /usr/bin/curl -s -X POST -H "PRIVATE-TOKEN: $GITLAB_TOKEN" -H "Content-Type: application/json" \
      "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/discussions/${THREAD_ID}/notes" \
      -d '{"body":"'"${REPLY_BODY}"'"}'
    ```

22. DO: Resolve fixed threads (only `to_fix[]`)
    ```bash
    /usr/bin/curl -s -X PUT -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
      "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/discussions/${THREAD_ID}?resolved=true" \
      | /usr/bin/jq -r '.resolved'
    ```

23. STORE: `POLL=0`, `CONSECUTIVE_FAILURES=0` → goto LOOP (step 13)

---

## Phase 7 — ON_FAILURE

24. DO: Fetch failed job logs
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

25. DO: Analyze failure → apply fix (agent implements)

26. DO: Commit and push fix
    ```bash
    cd "${REPO_DIR}"
    /usr/bin/git add -A
    /usr/bin/git commit -m "fix: resolve pipeline failure"
    /usr/bin/git push origin "${BRANCH}"
    ```

27. STORE: `POLL=0` (keep `CONSECUTIVE_FAILURES`) → goto LOOP (step 13)

---

## Commit Message Templates

| Context | Template |
|---|---|
| Initial implementation | `feat({scope}): {task title} [GOBIZWKST2-{TICKET}]` |
| Review fix | `fix: address review comments` |
| Pipeline fix | `fix: resolve pipeline failure` |
| Vulnerability fix | `[GOBIZWKST2-{TICKET}] Vulnerability Fixes - {pkg}@old → new` |

---

## Terminal States

| Condition | Status | Action |
|---|---|---|
| Pipeline success + 0 open threads | SUCCESS | Done |
| Pipeline success + only rejected threads | SUCCESS | Done |
| 3 consecutive pipeline failures | BLOCKED | Stop, report |
| 20 polls exceeded | TIMEOUT | Stop, report |

---

## Constraints

- Use absolute paths: `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/git`
- Never force-push
- Never commit secrets/tokens/credentials
- Never auto-approve or auto-merge
- Post thread replies BEFORE pipeline wait resumes
- Resolve only `to_fix[]` — leave `to_reject[]` open
- Run full loop to completion — no user prompts mid-workflow
- Paginate all list API calls until response length is 0
