---
description: "Reads, reviews, or acts on a GitLab MR from sgts.gitlab-dedicated.com. Triggers: review MR, read MR, check MR, fix comment, show diff, what changed in MR, pr review, code review, review merge request, fix review comment, paste of a sgts.gitlab-dedicated.com MR URL or a bare MR number with an action."
tools: [read, search, edit, execute, todo]
argument-hint: "Provide the MR URL (https://sgts.gitlab-dedicated.com/.../merge_requests/NNN). Action defaults to 'review'. Other actions: 'summarise', 'fix comment: <comment text>', 'checkout', 'diff'."
---

- GitLab: `sgts.gitlab-dedicated.com` — TechPass auth; HTTP always returns login page. **Never use fetch_webpage.**
- Git SSH configured and works.
- Repos: `/Users/a2456813/Development/IdeaProjects/`.
- Output dir: `/Users/a2456813/Development/IdeaProjects/.docs/pr-reviews/` — create if missing.

## Step 1 — Resolve Inputs

Parse the MR URL to extract:

| Field | Source |
|---|---|
| MR number | `/merge_requests/NNN` |
| Repo name | path segment immediately before `/-/` |
| Target branch | `master` unless URL or user specifies otherwise |
| Action | user-stated or default `review` |

Repo path = `/Users/a2456813/Development/IdeaProjects/<repo-name>`.
Output file = `/Users/a2456813/Development/IdeaProjects/.docs/pr-reviews/<MR_ID>.md`.

## Step 2 — Fetch the MR

```bash
cd <repo-path>
# Refresh target branch from remote first — never diff against stale local state
git fetch origin <target-branch>
git fetch origin "refs/merge-requests/<MR_ID>/head:mr-<MR_ID>"
```

Ambiguity warning → use the SHA from fetch output.

## Step 3 — Gather Data

Run all four commands; store output for Step 4.

```bash
git log mr-<MR_ID> --oneline -1
git log origin/<target-branch>..mr-<MR_ID> --oneline
git diff origin/<target-branch>...mr-<MR_ID> --stat
git diff origin/<target-branch>...mr-<MR_ID>
```

## Step 4 — Execute Action

### `review` (default) — Full PR Review

Run the review, then **write the result to `.docs/pr-reviews/<MR_ID>.md`** using the template below.
Create the `.docs/pr-reviews/` directory first if it does not exist.

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

#### Output Template (`.docs/pr-reviews/<MR_ID>.md`)

```markdown
# PR Review — MR !<MR_ID>

**Repo:** <repo-name>
**Branch:** <source-branch> → <target-branch>
**Reviewed:** <date>

---

## Summary

<one paragraph: what this MR does and why>

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

After writing the file, tell the user: `Review written to .docs/pr-reviews/<MR_ID>.md`.

### `summarise`
Print a short summary (title, intent, files changed count, verdict) — no output file.

### `diff`
Print grouped file summary and full diff from Step 3 — no output file.

### `fix comment: <comment text>`
1. Find file and location from diff + codebase search. Read current file.
2. Apply fix — follow existing conventions. Confirm what changed.
3. Do **not** write a review file.

### `checkout`
```bash
git checkout mr-<MR_ID>
```

## Constraints
- Never fetch MR URL over HTTP.
- Never invent review findings not evidenced by the diff.
- Fix only what the comment asks — no refactoring.
- Always quote relevant diff lines when citing findings.
- Checklist items with no changed code in scope → mark ✅ N/A.
