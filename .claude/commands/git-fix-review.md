---
description: "Acts on open review threads on one or more GitHub PRs / GitLab MRs: applies code fixes or rejects with reason, commits & pushes, polls pipeline until success, then resolves all fixed threads. Triggers: fix review comments, address review, respond to MR comments, fix PR feedback, act on review threads, address review findings, implement review suggestions."
tools: [read, search, edit, execute, todo]
argument-hint: "One or more PR/MR URLs (space- or newline-separated). Fetches every open review thread, fixes what it can, rejects what it can't (with reason), commits & pushes, polls pipeline to success, then resolves fixed threads."
---

## Globals

| | GitLab | GitHub |
|---|---|---|
| Host | `sgts.gitlab-dedicated.com` | `github.com` |
| Token env | `$GITLAB_TOKEN` | `$GITHUB_TOKEN` |
| Repo root | `/Users/a2456813/Development/IdeaProjects/` | `/Users/a2456813/Development/` |
| Auth note | TechPass — **never use fetch_webpage** | HTTPS/SSH as configured |

Fully independent — no prior agent run required.
Load **git-apis skill** for all platform API calls.

---

## Multi-URL Loop

More than one URL → process each **sequentially and independently**.  
Failure on one URL → log and continue; do not abort.

---

## Step 0 — Parse URL + Resolve Repo

**GitHub** `https://github.com/<owner>/<repo>/pull/<PR_ID>`  
→ Local ref `pr-<PR_ID>`, target `main`/`master`, encoded project `<owner>/<repo>`

**GitLab** `https://sgts.gitlab-dedicated.com/<group>/<project>/-/merge_requests/<MR_ID>`  
→ Local ref `mr-<MR_ID>`, target `master`, encoded project `<group>%2F<project>`

Resolve `<repo-path>`: user-provided → default root + repo name → ask.

---

## Step 1 — Fetch Branch + Diff

```bash
cd <repo-path>
git fetch origin <target-branch>
git fetch origin "<ref-to-fetch>:<local-ref>"
BASE_SHA=$(git rev-parse origin/<target-branch>)
HEAD_SHA=$(git rev-parse <local-ref>)
# Determine current working branch name (needed for push in Step 5)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git diff origin/<target-branch>...<local-ref>
```

Store diff and `CURRENT_BRANCH` — used for code context in Step 3 and push in Step 5.

---

## Step 2 — Fetch Open Review Threads

Use **git-apis skill → FETCH_DISCUSSIONS**. Then filter open threads:

```bash
# GitLab
OPEN_THREADS=$(echo "$DISCUSSIONS" | jq '[.[] | select(.resolved != true) | {
  id: .id,
  first_note_id: .notes[0].id,
  author: .notes[0].author.username,
  body: .notes[0].body,
  file: .notes[0].position.new_path,
  line: .notes[0].position.new_line,
  replies: [.notes[1:][]]
}]')
# GitHub
OPEN_THREADS=$(echo "$REVIEW_COMMENTS" | jq '[.[] | select(.in_reply_to_id == null) | {
  id: .id,
  node_id: .node_id,
  author: .user.login,
  body: .body,
  file: .path,
  line: .line,
  replies: []
}]')
```

If `OPEN_THREADS` is empty → print `No open review threads found on <Platform> !<ID>.` and stop.

---

## Step 3 — Evaluate Each Thread

For each thread in `OPEN_THREADS`, in order:

1. **Read the concern** from `body`.
2. **Locate the code**: use `file` + `line`, cross-reference with diff. Read current file content around that line.
3. **Decide: FIX or REJECT** using the rules below.
4. Add to `to_fix[]` or `to_reject[]`.

### Fix vs Reject rules

| Condition | Decision |
|---|---|
| Fix is clear, safe, and within this MR's scope | **FIX** |
| Fix requires design decisions beyond this MR | **REJECT** — out of scope; suggest follow-up ticket |
| Concern is incorrect (reviewer misread the code) | **REJECT** — explain why the code is correct |
| Fix would break other callers / contracts not touched by this MR | **REJECT** — describe the risk |
| Suggestion is style-only with no correctness impact | **REJECT** — style preference; deferring to keep diff focused |
| Uncertain — cannot safely determine impact | **REJECT** — needs author clarification before proceeding |

---

## Step 4 — Apply Fixes

For each item in `to_fix[]`:

1. **Read** the target file at the relevant lines.
2. **Apply** the minimal change that addresses the concern — no refactoring beyond what was asked.
3. **Verify** edit is syntactically valid (re-read the changed block).

If nothing to fix → skip to Step 5b (post responses only).

---

## Step 5 — Commit & Push

### 5a — Commit

Only if there are staged/unstaged changes from Step 4:

```bash
cd <repo-path>
git add -A
# Verify something is staged before committing
git diff --cached --quiet || git commit -m "fix: address review comments

$(echo "$to_fix" | sed 's/^/- /')"
```

Build the commit message body from `to_fix[]` thread summaries (file:line — concern title).

### 5b — Push

```bash
git push origin "${CURRENT_BRANCH}"
```

If nothing was committed (nothing to fix) → skip push; proceed to Step 5c.

### 5c — Post Thread Responses (before pipeline wait)

**For each FIXED thread:**

```
✅ **Fixed** — <one sentence: what changed and where>.
```

**For each REJECTED thread:**

```
⛔ **Not applying — <Short reason title>**

<1–2 sentences explaining why this change was not made.>

**Reason:** <out of scope / reviewer misread / would break contract / style preference / needs author clarification>

<If actionable — suggest next step.>
```

Post all replies via **git-apis skill → REPLY** before waiting for the pipeline.

---

## Step 6 — Poll Pipeline Until Success

> Skip this step if nothing was committed in Step 5a.

### 6a — Adaptive polling schedule

Use decreasing intervals — longer early, shorter later:

```
Poll #  Wait before polling
  1     120 s   (2 min  — give CI time to initialise)
  2      90 s   (1.5 min)
  3      60 s   (1 min)
  4      45 s
  5+     30 s   (keep tight once nearly done)
```

```bash
INTERVALS=(120 90 60 45 30)
POLL=0
MAX_POLLS=20

while [ $POLL -lt $MAX_POLLS ]; do
  IDX=$(( POLL < ${#INTERVALS[@]} ? POLL : $(( ${#INTERVALS[@]} - 1 )) ))
  WAIT=${INTERVALS[$IDX]}
  echo "[<platform> !<ID>] Poll #$(( POLL + 1 )) — waiting ${WAIT}s..."
  sleep ${WAIT}
  POLL=$(( POLL + 1 ))

  # GitLab — fetch latest pipeline for the MR
  PIPELINE=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/pipelines" \
    | /usr/bin/jq '.[0]')
  # GitHub — fetch latest check suite / status
  # Use git-apis skill → FETCH_PIPELINE_STATUS

  PIPELINE_STATUS=$(echo "${PIPELINE}" | /usr/bin/jq -r '.status')
  PIPELINE_URL=$(echo "${PIPELINE}" | /usr/bin/jq -r '.web_url')
  echo "[<platform> !<ID>] Pipeline: ${PIPELINE_STATUS}  (${PIPELINE_URL})"

  case "${PIPELINE_STATUS}" in
    success)
      echo "Pipeline passed — resolving fixed threads."
      break
      ;;
    failed|canceled)
      echo "Pipeline ${PIPELINE_STATUS}. Check logs: ${PIPELINE_URL}"
      # Re-fetch open threads; if new failures introduced → evaluate & fix (Step 3→4→5)
      # then reset POLL=0 for fresh poll cycle
      break
      ;;
    running|pending|created|waiting_for_resource|preparing)
      echo "Pipeline still ${PIPELINE_STATUS}. Continuing to poll..."
      ;;
    *)
      echo "Unknown pipeline status '${PIPELINE_STATUS}'. Continuing to poll."
      ;;
  esac
done

[ $POLL -ge $MAX_POLLS ] && echo "TIMEOUT: exceeded ${MAX_POLLS} polls — manual check required."
```

### 6b — Re-fix loop (pipeline failed)

If pipeline `failed`/`canceled`:
1. Re-fetch open threads (Step 2 logic).
2. Evaluate new/remaining concerns (Step 3).
3. Apply fixes (Step 4) → commit + push (Step 5a–5b) → reset `POLL=0` → continue polling.

Stop re-fix attempts if:
- All remaining threads are `REJECTED` or already `DEFERRED`
- 3 consecutive `failed` pipelines with no new fixable threads → log `BLOCKED` and stop

---

## Step 7 — Resolve Fixed Threads

After pipeline reaches `success`:

For each thread in `to_fix[]` that was fixed and replied to:

```bash
# GitLab — resolve the discussion
/usr/bin/curl -s -X PUT -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/discussions/${THREAD_ID}?resolved=true"
```

```bash
# GitHub — mark review comment as resolved (via GraphQL minimizeComment or dismiss review)
# Use git-apis skill → RESOLVE_THREAD
```

Only resolve threads that were **fixed** — leave rejected threads open.

---

## Step 8 — Final Summary

```
### Fix-Review complete — <Platform> !<ID>

**Fixed & resolved (<N>):**
- <file>:<line> — <title>
- ...

**Rejected — threads left open (<M>):**
- <title> — <reason type>
- ...

**Pipeline:** <success | failed | timeout>
**Polls:** <N> iterations
**Branch:** <CURRENT_BRANCH>
**MR/PR:** <URL>

Rejected threads remain open. Re-run this agent on the same URL after the author responds or pushes changes.
```

Do not auto-approve or auto-merge under any circumstance.

---

## Constraints

- Never fetch GitLab URLs over HTTP.
- Fetch threads **once in Step 2** per cycle — do not re-fetch mid-evaluation.
- Never fix more than what the thread explicitly asks — no opportunistic refactoring.
- Never commit secrets, tokens, or credentials.
- Never force-push (`--force`).
- If a fix touches code with no test coverage, note it in the reply but do not block the fix.
- Rejection reasons must be specific — never use vague language.
- Do not auto-approve or auto-merge under any circumstance.
- Max poll iterations: 20 per pipeline run.
