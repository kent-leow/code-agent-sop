---
description: "Reads, reviews, or acts on one or more GitHub PRs / GitLab MRs. Auto-detects platform from URL. Triggers: review PR, review MR, read MR, check MR, fix comment, show diff, what changed in MR/PR, pr review, code review, review merge request, fix review comment, paste of a GitHub PR URL or GitLab MR URL, or a bare number with an action."
tools: [read, search, edit, execute, todo]
argument-hint: "One or more PR/MR URLs (space- or newline-separated). Actions: review (default), summarise, diff, fix comment: <text>, checkout. Re-passing same URL → follow-up mode (check threads, resolve or insist, approve if all clear)."
---

## Globals

| | GitLab | GitHub |
|---|---|---|
| Host | `sgts.gitlab-dedicated.com` | `github.com` |
| Token env | `$GITLAB_TOKEN` | `$GITHUB_TOKEN` |
| Repo root | `/Users/a2456813/Development/IdeaProjects/` | `/Users/a2456813/Development/` |
| Auth note | TechPass — **never use fetch_webpage** | HTTPS/SSH as configured |

No local files are created or required. All state lives on the platform.
Load **git-apis skill** for all platform API calls.

---

## Multi-URL Loop

More than one URL → process each **sequentially and independently**.  
Failure on one URL → log and continue; do not abort.

---

## Step 0 — Parse URL + Route

**Parse URL:**

**GitHub** `https://github.com/<owner>/<repo>/pull/<PR_ID>`

| Field | Value |
|---|---|
| Ref to fetch | `refs/pull/<PR_ID>/head` |
| Local ref | `pr-<PR_ID>` |
| Target branch | `main` or `master` |
| Encoded project | `<owner>/<repo>` |

**GitLab** `https://sgts.gitlab-dedicated.com/<group>/<project>/-/merge_requests/<MR_ID>`

| Field | Value |
|---|---|
| Ref to fetch | `refs/merge-requests/<MR_ID>/head` |
| Local ref | `mr-<MR_ID>` |
| Target branch | `master` |
| Encoded project | `<group>%2F<project>` |

Resolve `<repo-path>`: user-provided → default root + repo name → ask.

**Non-review actions** (execute immediately, then stop):

| Action | Behaviour |
|---|---|
| `summarise` | Fetch threads + diff `--stat`, print short summary. No posting. |
| `diff` | Run Step 1, print `--stat` + full diff. No posting. |
| `fix comment: <text>` | Run Steps 1–2, find location, apply fix, confirm. No posting. |
| `checkout` | Step 1 fetch only, then `git checkout <local-ref>`. |

**Route — fetch existing agent-posted threads from the platform (one call):**

Use **git-apis skill → FETCH_DISCUSSIONS**. Then filter:

```bash
# GitLab
AGENT_THREADS=$(echo "$DISCUSSIONS" | jq '[.[] | select(
  (.notes[0].body | test("^\\*\\*\\[(Critical|Major|Minor)\\]"))
)]')
# GitHub
AGENT_THREADS=$(echo "$REVIEW_COMMENTS $ISSUE_COMMENTS" | jq -s 'add | [.[] | select(.body | test("^\\*\\*\\[(Critical|Major|Minor)\\]"))]')
```

- `AGENT_THREADS` empty → **first run** → Steps 1 → 2 → 3 → 4B
- `AGENT_THREADS` non-empty → **follow-up** → Steps 1 → 2 → 4C → 4D

Store `AGENT_THREADS` for reuse — do not fetch again.

---

## Step 1 — Fetch Branch + Compute SHAs

```bash
cd <repo-path>
git fetch origin <target-branch>
git fetch origin "<ref-to-fetch>:<local-ref>"
BASE_SHA=$(git rev-parse origin/<target-branch>)
HEAD_SHA=$(git rev-parse <local-ref>)
```

---

## Step 2 — Gather Diff Data

```bash
git log <local-ref> --oneline -1
git log origin/<target-branch>..<local-ref> --oneline
git diff origin/<target-branch>...<local-ref> --stat
git diff origin/<target-branch>...<local-ref>
```

Store all output.

---

## Step 3 — Full Code Review (first run only)

Evaluate every checklist item against the diff. Only raise findings evidenced by the diff.

| # | Area | What to check |
|---|---|---|
| 1 | Purpose & Scope | Clear title/desc; single concern; no unrelated changes |
| 2 | Correctness | Logic errors, nulls, edge cases, race conditions |
| 3 | Security | Input validation, auth checks, no hardcoded secrets, SQLi/XSS/CSRF, new CVEs |
| 4 | Error Handling | Errors caught + propagated; no swallowed exceptions; timeouts on I/O |
| 5 | Test Coverage | New logic tested; edge/failure paths covered; no regression |
| 6 | Code Quality | Clear naming, DRY, no dead code/debug statements, small focused functions |
| 7 | Performance | N+1 risk, missing indexes, unnecessary blocking calls |
| 8 | Observability | Logging appropriate; metrics/alerts updated if behaviour changes |
| 9 | API & Contract | Breaking changes? Backwards compat or migration provided? |
| 10 | Documentation | Complex logic commented; README/SNAPSHOT updated if needed |

Print review findings to the user (Critical / Major / Minor / Positive Observations) — no local file written.

---

## Step 4B — Post Inline Comments (first run only)

Build `$POSTED_TITLES` from `$AGENT_THREADS` (already fetched in Step 0). For each finding:

1. Derive title: `**[<Severity>] <Short title>**`.
2. **If title exists in `$POSTED_TITLES` → skip silently.**
3. Map to file + line from diff (`+++ b/<file>`, `new_line`). Unmappable → general comment.
4. Post. On success add title to `$POSTED_TITLES`. Warn on non-2xx but continue.

Report: `N inline + M general posted, K skipped (already posted)`.

**Comment body:**
```
**[Critical|Major|Minor] <Short title>**

<1–2 sentences describing the issue.>

**Fix:** <one-liner or short code block>
```

Post via **git-apis skill → POST_INLINE** (mappable) or **POST_GENERAL** (unmappable).

---

## Step 4C — Evaluate Threads (follow-up only)

Use `$AGENT_THREADS` from Step 0 — **do not fetch again**. Skip threads already resolved on the platform.

**Pre-check per thread before evaluating:**

| Condition | Action |
|---|---|
| No author reply AND relevant file/line unchanged in latest diff | **Skip silently** — await author |
| Author replied OR relevant line changed | **Proceed** |

**Evaluation (for threads that pass pre-check):**

| Check | Condition | Action |
|---|---|---|
| 1 | Latest diff shows issue fixed | **RESOLVED** — reply + resolve thread |
| 2 | Author replied with valid justification | **ACCEPTED** — reply only, leave open |
| 3 | Author replied but issue unaddressed | **UNRESOLVED** — insistence reply, leave open |

**RESOLVED reply:** `✅ All good — fix applied. Thanks!`

**ACCEPTED reply:** `✅ Understood — reasonable trade-off, proceeding.` *(tailor to context)*

**UNRESOLVED reply:**
```
**Still open: <Short title>**

Thanks for the response! The concern still stands — <1 sentence restating issue + specific line/block>.

Could you take another look? Specifically: <exact ask or one-liner fix>.

Happy to discuss a different approach — just drop a note and I'll re-evaluate. 🙏
```

Reply via **git-apis skill → REPLY**.

**Resolve thread (RESOLVED only):** use **git-apis skill → RESOLVE**.

---

## Step 4D — Approve or Block (follow-up only)

**All agent threads resolved:** use **git-apis skill → APPROVE**, then **POST_GENERAL**: `✅ Follow-up complete — all threads resolved. Approved! 🎉`

**Any thread still open → do not approve.** Post:
`🔄 Follow-up complete — <N> thread(s) still need attention, <M> awaiting author response.`

---

## Constraints

- Never fetch GitLab URLs over HTTP.
- Never invent findings not evidenced by the diff.
- Fetch platform comments **once in Step 0**; reuse in all subsequent steps.
- No duplicate comments — skip any finding whose title already exists in `$POSTED_TITLES`.
- Inline comments: title + 1–2 sentences + fix only.
- Checklist items with no changed code → mark ✅ N/A.
- Follow-up: only process threads with `**[Critical|Major|Minor]` prefix.
- Follow-up: never post to an idle thread (no author reply + line unchanged) — skip silently.
- Follow-up: never approve if any Critical or Major thread is still open.
- No local files created or read at any point.
