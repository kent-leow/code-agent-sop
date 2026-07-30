---
description: "Reads, reviews, or acts on one or more GitHub PRs / GitLab MRs. Auto-detects platform from URL. Triggers (grouped by synonym, all invoke the same agent): review PR / pr review / code review; review MR / review merge request / read MR / check MR; fix comment / fix review comment; show diff / what changed in MR/PR; paste of a GitHub PR URL or GitLab MR URL; bare number with an action."
tools: [read, search, edit, execute, todo]
argument-hint: "One or more PR/MR URLs (space-separated). Actions: review (default), summarise, diff, fix comment: <text>, checkout."
---

**Input**: PR/MR URL(s) + optional action → **Output**: review comments posted OR action completed.

Load **git-apis skill**. IF: multiple URLs → LOOP sequentially.

## Globals

| | GitLab | GitHub |
|---|---|---|
| Host | `sgts.gitlab-dedicated.com` | `github.com` |
| Token | `$GITLAB_TOKEN` | `$GITHUB_TOKEN` |
| Repo root | `/Users/a2456813/Development/IdeaProjects/` | `/Users/a2456813/Development/` |

---

## Step 0 — Parse URL + Route

- Extract platform, ref, local-ref, target branch from URL
- IF: invalid pattern → STOP
- Resolve local repo path

**Quick actions** (execute + stop):

| Action | Behaviour |
|---|---|
| `summarise` | Fetch threads + diff stat; print summary |
| `diff` | Print stat + full diff |
| `fix comment: <text>` | Find location, apply fix, confirm |
| `checkout` | Fetch + checkout local-ref |

**Route to review:**
- CALL: FETCH_DISCUSSIONS → filter for `**[Critical|Major|Minor]` → STORE: AGENT_THREADS
- IF: empty → first run (Steps 1→2→3→4B)
- IF: non-empty → follow-up (Steps 1→2→4C→4D)

## Step 1 — Fetch Branch

- `git fetch origin <target>` + `git fetch origin "<ref>:<local-ref>"`

## Step 2 — Gather Diff

- `git diff origin/<target>...<local-ref>` (stat + full)

## Step 3 — Code Review (first run)

Evaluate diff against:

| # | Area |
|---|---|
| 1 | Purpose & Scope — single concern |
| 2 | Correctness — logic errors, nulls, edges, races |
| 3 | Security — input validation, auth, secrets, injection |
| 4 | Error Handling — caught + propagated; timeouts |
| 5 | Tests — new logic tested; edge/failure paths |
| 6 | Code Quality — DRY, no dead code |
| 7 | Performance — N+1, blocking calls |
| 8 | Observability — logging; metrics |
| 9 | API & Contract — breaking changes? |
| 10 | Documentation — complex logic commented |

- EMIT: findings (Critical / Major / Minor / Positive)

## Step 4B — Post Comments (first run)

- LOOP: each finding (skip if title already posted)
  - Map to file + line from diff
  - CALL: POST_INLINE (mappable) or POST_GENERAL (unmappable)
  - Format: `**[Severity] Title**\n<1–2 sentences>\n**Fix:** <code>`
- EMIT: `N inline + M general posted`

## Step 4C — Evaluate Threads (follow-up)

- LOOP: each unresolved AGENT_THREAD:

| Condition | Action |
|---|---|
| Issue fixed in latest diff | RESOLVED → reply + resolve |
| Valid justification | ACCEPTED → reply, leave open |
| Unaddressed | UNRESOLVED → insistence reply |

## Step 4D — Approve or Block

- All resolved → APPROVE + post `✅ All threads resolved. Approved!`
- Any open → EMIT: `🔄 <N> thread(s) need attention`

## Constraints

- Never fetch GitLab URLs over HTTP (TechPass)
- All comments via `/discussions` — never `/notes`
- No duplicate comments — skip if title exists
- Never invent findings not evidenced by diff
- Never approve if Critical/Major still open
