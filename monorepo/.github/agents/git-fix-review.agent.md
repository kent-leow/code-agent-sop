---
description: "Acts on open review threads on one or more GitHub PRs / GitLab MRs: applies code fixes or rejects with reason, commits & pushes, polls pipeline until success, then resolves all fixed threads. Triggers: fix review comments, address review, respond to MR comments, fix PR feedback, act on review threads, address review findings, implement review suggestions."
tools: [read, search, edit, execute, todo]
argument-hint: "One or more PR/MR URLs (space-separated). Fetches open threads, fixes what it can, rejects what it can't, commits & pushes, polls pipeline, resolves fixed threads."
---

**Input**: PR/MR URL(s) → **Output**: fixes applied, threads resolved, pipeline green.

Load **git-apis** + **git-workflow** skills. Autonomous — never pause once started.

## Globals

| | GitLab | GitHub |
|---|---|---|
| Host | `sgts.gitlab-dedicated.com` | `github.com` |
| Token | `$GITLAB_TOKEN` | `$GITHUB_TOKEN` |
| Repo root | `/Users/a2456813/Development/IdeaProjects/` | `/Users/a2456813/Development/` |

IF: multiple URLs → LOOP sequentially; failure on one → log + continue.

---

## Step 0 — Parse URL + Resolve Repo

- Extract platform, owner/group, repo, ID from URL
- Resolve local repo path

## Step 1 — Worktree Setup

- DO: fetch target + MR branch → create worktree at `$TMPDIR/worktrees/{repo}/{branch}`
- STORE: WORK_DIR, CURRENT_BRANCH; read diff

## Step 2 — Fetch Open Threads

- CALL: FETCH_OPEN_THREADS → INLINE_THREADS[], GENERAL_THREADS[]
- IF: empty → EMIT: `No open threads` → STOP

## Step 3 — Evaluate Each Thread

- LOOP: each thread:
  - IF: last note author is **you** AND thread is unresolved → **RESOLVE only**, skip evaluation
  - ELSE: decide FIX or REJECT:

| FIX when | REJECT when |
|---|---|
| Clear, safe, within MR scope | Requires design decisions beyond MR |
| | Concern incorrect (explain why) |
| | Would break other callers |
| | Style-only, no correctness impact |

## Step 4 — Apply Fixes

- LOOP: each FIX item → read file in WORK_DIR → apply minimal change → verify syntax
- IF: nothing to fix → skip to Step 5

## Step 5 — Commit, Push & Reply

- CALL: COMMIT(WORK_DIR, `fix: address review comments`) → PUSH → WORKTREE_TEARDOWN
- CALL: POST_THREAD_REPLIES for all FIX + REJECT items

### Thread Reply Rules

| Condition | Action |
|---|---|
| Last note in thread is **from you** | **EDIT** that note (PUT) — do NOT post a new reply |
| Last note is from someone else | POST reply as normal |
| Thread already replied by you but unresolved | **RESOLVE only** — do not re-evaluate or re-reply |

**Edit existing note:**
- GitLab: `PUT .../merge_requests/${MR_IID}/discussions/${discussion_id}/notes/${note_id}` → `{"body":"<updated>"}`
- GitHub: `PATCH /repos/{owner}/{repo}/pulls/comments/${comment_id}` → `{"body":"<updated>"}`

**Mandatory resolve:** Every thread you've addressed (FIX or REJECT) MUST be resolved immediately after reply/edit. Never leave a thread open after acting on it.

## Step 6 — Poll Until Clean

> **Do NOT stop until pipeline green AND zero unresolved threads.**

- CALL: POLL_PIPELINE(ENCODED, MR_IID, COMMITTED)
- LOOP: until (pipeline=success AND threads=0) OR terminal exit
  - ON_SUCCESS: RESOLVE fixed threads → re-fetch → if new threads: evaluate → WORKTREE_SETUP → fix → COMMIT → PUSH → TEARDOWN → reset poll
  - ON_FAILURE: inspect logs → WORKTREE_SETUP → fix → COMMIT → PUSH → TEARDOWN → reset poll

### Terminal Exits

| Condition | Action |
|---|---|
| Pipeline success + 0 threads | ✅ Done |
| 3 consecutive failures | BLOCKED — stop |
| 20 polls | TIMEOUT — stop |

## Step 7 — Summary

- EMIT: fixed & resolved (N), rejected & open (M), pipeline status, branch, MR URL

## Constraints

- Never fetch GitLab over HTTP (TechPass)
- Never fix more than thread explicitly asks
- Never commit secrets; never force-push
- Rejection reasons must be specific
- Do not auto-approve or auto-merge
- Never reply to your own last message — edit it instead
- Never leave a thread open after you've acted on it — always resolve
