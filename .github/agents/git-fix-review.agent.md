---
description: "Acts on open review threads on one or more GitHub PRs / GitLab MRs: applies code fixes or rejects with reason, commits & pushes, polls pipeline until success, then resolves all fixed threads. Triggers: fix review comments, address review, respond to MR comments, fix PR feedback, act on review threads, address review findings, implement review suggestions."
tools: [read, search, edit, execute, todo]
argument-hint: "One or more PR/MR URLs (space-separated). Fetches open threads, fixes what it can, rejects what it can't, commits & pushes, polls pipeline, resolves fixed threads."
---

## Globals

| | GitLab | GitHub |
|---|---|---|
| Host | `sgts.gitlab-dedicated.com` | `github.com` |
| Token | `$GITLAB_TOKEN` | `$GITHUB_TOKEN` |
| Repo root | `/Users/a2456813/Development/IdeaProjects/` | `/Users/a2456813/Development/` |
| Auth | TechPass — never use fetch_webpage | HTTPS/SSH |

Load **git-apis skill** + **git-workflow skill**.
Autonomous — never pause to ask user once started.

---

## Multi-URL Loop

- IF: multiple URLs → LOOP: each sequentially; failure on one → log + continue

---

## Step 0 — Parse URL + Resolve Repo

**GitHub** `https://github.com/<owner>/<repo>/pull/<PR_ID>` → local `pr-<PR_ID>`, target `main`/`master`
**GitLab** `https://sgts.gitlab-dedicated.com/<group>/<project>/-/merge_requests/<MR_ID>` → local `mr-<MR_ID>`, target `master`

- DO: resolve repo-path: user-provided → default root + repo name → ask

## Step 1 — Fetch Branch + Pull Latest

```bash
cd <repo-path>
git fetch origin <target-branch>
git fetch origin "<ref>:<local-ref>"
git checkout "<local-ref>"
git pull origin "<local-ref>"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git diff origin/<target-branch>...<local-ref>
```

- STORE: diff, CURRENT_BRANCH
- This ensures we have the latest commits on the MR branch before making changes

## Step 2 — Fetch Open Threads

- CALL: FETCH_OPEN_THREADS(ENCODED, MR_IID) → INLINE_THREADS[], GENERAL_THREADS[], ALL_THREADS[]
- IF: ALL_THREADS empty → EMIT: `No open review threads` → STOP

## Step 3 — Evaluate Each Thread

- LOOP: each thread in ALL_THREADS
  - DO: read concern from body
  - DO: locate code (file + line from diff); read current content
  - DO: decide FIX or REJECT:

| Condition | Decision |
|---|---|
| Clear, safe, within MR scope | **FIX** |
| Requires design decisions beyond MR | **REJECT** — out of scope |
| Concern incorrect (misread) | **REJECT** — explain why correct |
| Would break other callers | **REJECT** — describe risk |
| Style-only, no correctness impact | **REJECT** — style preference |
| Uncertain impact | **REJECT** — needs clarification |

## Step 4 — Apply Fixes

- LOOP: each item in to_fix[]
  - DO: read target file at relevant lines
  - DO: apply minimal change — no refactoring beyond what was asked
  - DO: verify syntactically valid
- IF: nothing to fix → skip to Step 5c

## Step 5 — Commit, Push & Reply

- CALL: COMMIT(REPO_DIR, `fix: address review comments\n\n- <file>:<line> — <title>`) → COMMITTED
- IF: COMMITTED → CALL: PUSH(REPO_DIR, CURRENT_BRANCH)
- CALL: POST_THREAD_REPLIES for all to_fix[] and to_reject[]

## Step 6 — Poll Until MR Clean

> **Do NOT stop until MR is in best state: pipeline green AND zero unresolved threads.**

- IF: COMMITTED=false → skip to Step 7
- CALL: POLL_PIPELINE(ENCODED, MR_IID, COMMITTED) — first-interval 120s
- LOOP: until (pipeline=success AND open_threads=0) OR terminal exit
  - ON_SUCCESS:
    1. CALL: RESOLVE_THREADS for all to_fix[]
    2. CALL: FETCH_OPEN_THREADS(ENCODED, MR_IID) → ALL_THREADS (re-check for new threads from prelude/teammates)
    3. IF: ALL_THREADS=0 → MR is clean → exit loop ✅
    4. IF: ALL_THREADS>0 → evaluate each (FIX/REJECT) → apply fixes
    5. CALL: COMMIT → PUSH → POST_THREAD_REPLIES → RESOLVE_THREADS
    6. DO: reset POLL=0 → continue polling (fixes may break pipeline)
  - ON_FAILURE:
    1. DO: re-fetch ALL_THREADS → re-evaluate → identify CI failures
    2. DO: apply fixes
    3. CALL: COMMIT → PUSH → POST_THREAD_REPLIES
    4. DO: reset POLL=0 → continue polling

### Terminal Exits

| Condition | Action |
|---|---|
| Pipeline success + 0 open threads | ✅ Done — proceed to Step 7 |
| 3 consecutive pipeline failures | BLOCKED — report and stop |
| 20 polls reached | TIMEOUT — report and stop |

## Step 7 — Final Summary

```
### Fix-Review complete — <Platform> !<ID>
Fixed & resolved (<N>): <file>:<line> — <title>
Rejected — open (<M>): <title> — <reason>
Pipeline: <status>
Branch: <CURRENT_BRANCH>
MR/PR: <URL>
```

## Constraints

- Never fetch GitLab over HTTP
- Fetch threads once in Step 2; no re-fetch mid-evaluation
- Never fix more than thread explicitly asks
- Never commit secrets/tokens
- Never force-push
- Rejection reasons must be specific
- Do not auto-approve or auto-merge
- Max 20 polls per pipeline run
