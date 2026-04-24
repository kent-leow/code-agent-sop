---
description: "Reads, reviews, or acts on a GitHub PR or GitLab MR. Auto-detects platform from URL. Triggers: review PR, review MR, read MR, check MR, fix comment, show diff, what changed in MR/PR, pr review, code review, review merge request, fix review comment, paste of a GitHub PR URL or GitLab MR URL, or a bare number with an action."
tools: [read, search, edit, execute, todo]
argument-hint: "Provide the PR/MR URL (e.g. https://github.com/<owner>/<repo>/pull/NNN or https://sgts.gitlab-dedicated.com/<group>/<project>/-/merge_requests/NNN). Action defaults to 'review'. Other actions: 'summarise', 'fix comment: <comment text>', 'checkout', 'diff'. Optionally provide local repo path if auto-detection fails."
---

Supports **GitHub** (`github.com`) and **GitLab** (`sgts.gitlab-dedicated.com`). Git commands are universal; only the fetch ref and URL parsing differ.

- GitLab: TechPass auth; HTTP always returns login page. **Never use fetch_webpage for GitLab.**
- GitHub: public or private repos via HTTPS/SSH as configured.
- Default GitLab repo root: `/Users/a2456813/Development/IdeaProjects/`
- Default GitHub repo root: `/Users/a2456813/Development/`
- Output dir: `<repo-path>/.docs/pr-reviews/` — create if missing.

## Step 1 — Resolve Inputs

Parse the URL to extract platform and fields:

**GitHub** — `https://github.com/<owner>/<repo>/pull/<PR_ID>`

| Field | Value |
|---|---|
| Platform | `github` |
| ID | `<PR_ID>` |
| Repo name | `<repo>` |
| Ref to fetch | `refs/pull/<PR_ID>/head` |
| Local ref name | `pr-<PR_ID>` |
| Target branch | `main` or `master` (check which exists) |

**GitLab** — `https://sgts.gitlab-dedicated.com/<group>/<project>/-/merge_requests/<MR_ID>`

| Field | Value |
|---|---|
| Platform | `gitlab` |
| ID | `<MR_ID>` |
| Repo name | path segment immediately before `/-/` |
| Ref to fetch | `refs/merge-requests/<MR_ID>/head` |
| Local ref name | `mr-<MR_ID>` |
| Target branch | `master` unless stated otherwise |

**Repo path resolution (in order):**
1. User-provided path
2. GitLab → `/Users/a2456813/Development/IdeaProjects/<repo-name>`
3. GitHub → `/Users/a2456813/Development/<repo-name>`
4. Not found → ask before proceeding.

Output file = `<repo-path>/.docs/pr-reviews/<ID>.md`.

## Step 2 — Fetch the Branch

```bash
cd <repo-path>
# Refresh target branch — never diff against stale local state
git fetch origin <target-branch>
git fetch origin "<ref-to-fetch>:<local-ref-name>"
```

Ambiguity warning → use the SHA from fetch output.

## Step 3 — Gather Data

Run all four; store output for Step 4.

```bash
git log <local-ref-name> --oneline -1
git log origin/<target-branch>..<local-ref-name> --oneline
git diff origin/<target-branch>...<local-ref-name> --stat
git diff origin/<target-branch>...<local-ref-name>
```

## Step 4 — Execute Action

### `review` (default) — Full Code Review

Write result to `<repo-path>/.docs/pr-reviews/<ID>.md`. Create the directory first if missing.

#### Review Checklist (evaluate every item against the diff)

**1. Purpose & Scope**
- Does the MR title/description clearly state what and why?
- Is the change scoped to one concern (single responsibility)?
- Are there unrelated changes bundled in?

**2. Correctness**
- Logic errors, off-by-one, null/undefined dereferences.
- Edge cases not handled (empty collections, zero values, missing fields).
- Race conditions or ordering assumptions.

**3. Security (OWASP Top 10 lens)**
- Input validation / sanitisation at system boundaries.
- Authentication / authorisation checks present and correct.
- No secrets, tokens, or PII hardcoded.
- SQL injection, XSS, CSRF exposure.
- Dependency changes — any known CVEs introduced?

**4. Error Handling & Resilience**
- Errors caught, logged, and propagated correctly.
- No swallowed exceptions.
- Retries / timeouts where appropriate for I/O.

**5. Test Coverage**
- Unit tests added/updated for new logic.
- Edge cases and failure paths tested.
- Integration/E2E tests if behaviour is user-facing.
- No test coverage regressions.

**6. Code Quality**
- Naming — clear, consistent with existing conventions.
- DRY — no copy-pasted logic; helpers extracted where reused.
- No dead code, commented-out blocks, or debug statements left in.
- Functions/methods kept small and focused.

**7. Performance**
- N+1 query risk.
- Missing indexes for new query patterns.
- Unnecessary loops, allocations, or blocking calls.

**8. Observability**
- Appropriate logging added (not too verbose, not silent).
- Metrics / traces / alerts updated if behaviour changes.

**9. API & Contract**
- Breaking changes to public API, REST endpoints, or event schema?
- Backwards compatibility maintained or migration provided.

**10. Documentation & Comments**
- Public APIs / complex logic commented where intent is non-obvious.
- README / SNAPSHOT updated if setup or behaviour changed.

#### Output Template (`<repo-path>/.docs/pr-reviews/<ID>.md`)

```markdown
# Code Review — <Platform> !<ID>

**Repo:** <repo-name>
**Branch:** <source-branch> → <target-branch>
**Platform:** GitHub PR / GitLab MR
**Reviewed:** <date>

---

## Summary

<one paragraph: what this change does and why>

## Commits

<git log output — one line per commit>

## Files Changed

| Layer | File | Change |
|---|---|---|
| <layer> | <file> | <added/modified/deleted — brief description> |

## Review Findings

### Critical (must fix before merge)
<!-- issues that block approval -->

### Major (should fix)
<!-- significant logic, security, or test gaps -->

### Minor (nice to fix)
<!-- naming, style, non-blocking suggestions -->

### Positive Observations
<!-- good patterns worth calling out -->

## Checklist Summary

| Area | Status | Notes |
|---|---|---|
| Purpose & Scope | ✅ / ⚠️ / ❌ | |
| Correctness | ✅ / ⚠️ / ❌ | |
| Security | ✅ / ⚠️ / ❌ | |
| Error Handling | ✅ / ⚠️ / ❌ | |
| Test Coverage | ✅ / ⚠️ / ❌ | |
| Code Quality | ✅ / ⚠️ / ❌ | |
| Performance | ✅ / ⚠️ / ❌ | |
| Observability | ✅ / ⚠️ / ❌ | |
| API & Contract | ✅ / ⚠️ / ❌ | |
| Documentation | ✅ / ⚠️ / ❌ | |

## Verdict

**`Approve` / `Request Changes` / `Needs Discussion`**

> <one-sentence reason>
```

After writing the file: `Review written to <repo-path>/.docs/pr-reviews/<ID>.md`.

### `summarise`
Print short summary (title, intent, files changed count, verdict) — no output file.

### `diff`
Print grouped file summary and full diff from Step 3 — no output file.

### `fix comment: <comment text>`
1. Find file and location from diff + codebase search. Read current file.
2. Apply fix — follow existing conventions. Confirm what changed.
3. Do **not** write a review file.

### `checkout`
```bash
git checkout <local-ref-name>
```

## Constraints
- Never fetch GitLab URLs over HTTP.
- Never invent review findings not evidenced by the diff.
- Fix only what the comment asks — no refactoring.
- Always quote relevant diff lines when citing findings.
- Checklist items with no changed code in scope → mark ✅ N/A.
