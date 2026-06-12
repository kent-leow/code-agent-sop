---
description: "Reads, reviews, or acts on one or more GitHub PRs / GitLab MRs. Auto-detects platform from URL. Triggers (grouped by synonym, all invoke the same agent): review PR / pr review / code review; review MR / review merge request / read MR / check MR; fix comment / fix review comment; show diff / what changed in MR/PR; paste of a GitHub PR URL or GitLab MR URL; bare number with an action."
---

## Globals

| | GitLab | GitHub |
|---|---|---|
| Host | `sgts.gitlab-dedicated.com` | `github.com` |
| Token | `$GITLAB_TOKEN` | `$GITHUB_TOKEN` |
| Repo root | `/Users/a2456813/Development/IdeaProjects/` | `/Users/a2456813/Development/` |
| Auth | TechPass — never use fetch_webpage | HTTPS/SSH |

Load **git-apis skill** for all platform API calls.

---

## Multi-URL Loop

- IF: multiple URLs → LOOP: each sequentially; failure on one → log + continue

---

## Step 0 — Parse URL + Route

**GitHub** `https://github.com/<owner>/<repo>/pull/<PR_ID>`:
- Ref: `refs/pull/<PR_ID>/head` → local `pr-<PR_ID>`, target `main`/`master`

**GitLab** `https://sgts.gitlab-dedicated.com/<group>/<project>/-/merge_requests/<MR_ID>`:
- Ref: `refs/merge-requests/<MR_ID>/head` → local `mr-<MR_ID>`, target `master`

- IF: URL doesn't match either pattern → EMIT: error + STOP for that URL
- DO: resolve `<repo-path>`: user-provided → default root + repo name → ask

**Non-review actions** (execute + stop):

| Action | Behaviour |
|---|---|
| `summarise` | Fetch threads + diff stat; print summary |
| `diff` | Fetch + print stat + full diff |
| `fix comment: <text>` | Find location, apply fix, confirm |
| `checkout` | Fetch only, checkout local-ref |

**Route:**
- CALL: FETCH_DISCUSSIONS → filter for `**[Critical|Major|Minor]` prefix → STORE: AGENT_THREADS
- IF: AGENT_THREADS empty → first run (Steps 1→2→3→4B)
- IF: AGENT_THREADS non-empty → follow-up (Steps 1→2→4C→4D)

---

## Step 1 — Fetch Branch

```bash
cd <repo-path>
git fetch origin <target-branch>
git fetch origin "<ref>:<local-ref>"
BASE_SHA=$(git rev-parse origin/<target-branch>)
HEAD_SHA=$(git rev-parse <local-ref>)
```

## Step 2 — Gather Diff

```bash
git log <local-ref> --oneline -1
git log origin/<target-branch>..<local-ref> --oneline
git diff origin/<target-branch>...<local-ref> --stat
git diff origin/<target-branch>...<local-ref>
```

## Step 3 — Code Review (first run)

- DO: evaluate each checklist item against diff; only raise findings evidenced by diff

| # | Area | Check |
|---|---|---|
| 1 | Purpose & Scope | Single concern; no unrelated changes |
| 2 | Correctness | Logic errors, nulls, edge cases, races |
| 3 | Security | Input validation, auth, no secrets, SQLi/XSS |
| 4 | Error Handling | Caught + propagated; timeouts on I/O |
| 5 | Tests | New logic tested; edge/failure paths |
| 6 | Code Quality | DRY, no dead code, small focused functions |
| 7 | Performance | N+1, missing indexes, blocking calls |
| 8 | Observability | Logging; metrics if behaviour changes |
| 9 | API & Contract | Breaking changes? Migration? |
| 10 | Documentation | Complex logic commented; README updated |

- EMIT: findings (Critical / Major / Minor / Positive)

## Step 4B — Post Comments (first run)

- STORE: POSTED_TITLES from AGENT_THREADS
- LOOP: each finding
  - IF: title in POSTED_TITLES → skip
  - DO: map to file + line from diff
  - CALL: POST_INLINE (mappable) or POST_GENERAL (unmappable)
  - Format: `**[Severity] Title**\n<1–2 sentences>\n**Fix:** <code>`
- EMIT: `N inline + M general posted, K skipped`

## Step 4C — Evaluate Threads (follow-up)

- LOOP: each thread in AGENT_THREADS (skip already resolved)

| Condition | Action |
|---|---|
| No reply AND line unchanged | Skip silently |
| Issue fixed in latest diff | RESOLVED → reply + resolve |
| Valid justification | ACCEPTED → reply, leave open |
| Issue unaddressed | UNRESOLVED → insistence reply, leave open |

- CALL: REPLY for each; CALL: RESOLVE for RESOLVED only

## Step 4D — Approve or Block (follow-up)

- IF: all threads resolved → CALL: APPROVE + POST_GENERAL: `✅ All threads resolved. Approved!`
- IF: any open → EMIT: `🔄 <N> thread(s) need attention, <M> awaiting response`

## Constraints

- Never fetch GitLab URLs over HTTP
- All comments via `/discussions` — never `/notes`
- Fetch threads once (Step 0); reuse everywhere
- No duplicate comments — skip if title exists
- Never invent findings not in diff
- Never post to idle thread (no reply + unchanged)
- Never approve if Critical/Major still open
