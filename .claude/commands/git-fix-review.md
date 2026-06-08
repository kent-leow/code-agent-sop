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
Load **git-workflow skill** for all branch/commit/push/MR/pipeline/thread operations.

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

→ **skill: FETCH_OPEN_THREADS** (`ENCODED`, `MR_IID`)  
Outputs: `INLINE_THREADS[]`, `GENERAL_THREADS[]`, `ALL_THREADS[]`.

Evaluate both inline and general/prelude threads with the same FIX/REJECT rules in Step 3.

If `ALL_THREADS` is empty → print `No open review threads found on <Platform> !<ID>.` and stop.

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

## Step 5 — Commit, Push & Reply

### 5a — Commit

→ **skill: COMMIT** (`REPO_DIR`, `COMMIT_MSG`)  
Commit message: `fix: address review comments\n\n- <file>:<line> — <concern title>\n- ...` (one line per `to_fix[]` item).  
Store output `COMMITTED`.

### 5b — Push

If `COMMITTED=false` → skip push and proceed directly to Step 5c.  
→ **skill: PUSH** (`REPO_DIR`, `CURRENT_BRANCH`)

### 5c — Post Thread Responses (before pipeline wait)

→ **skill: POST_THREAD_REPLIES** — post replies for every thread in `to_fix[]` and `to_reject[]`.

---

## Step 6 — Poll Pipeline Until Success

> Skip this step if `COMMITTED=false` from Step 5a.

→ **skill: POLL_PIPELINE** (`ENCODED`, `MR_IID`, `COMMITTED`)  
Use first-interval **120 s** (review-only pipeline — no dependency scanning).

**ON_SUCCESS hook:**  
→ skill: RESOLVE_THREADS — resolve all threads in `to_fix[]`.

**ON_FAILURE hook:**  
Re-fetch ALL_THREADS → re-evaluate (Steps 3→4) → skill: COMMIT → skill: PUSH → skill: POST_THREAD_REPLIES → reset `POLL=0`.

### 6b — Re-fix loop (pipeline failed)

Stop re-fix attempts when:
- All remaining threads are `REJECTED` or `DEFERRED` — nothing left to fix
- 3 consecutive failed pipelines → log `BLOCKED` and stop

---

## Step 7 — Resolve Fixed Threads

→ **skill: RESOLVE_THREADS** — resolves all threads in `to_fix[]` after pipeline reaches `success`.  
Leave `to_reject[]` threads open for author follow-up.

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
