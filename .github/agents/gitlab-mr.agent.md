---
description: "Reads, reviews, or acts on a GitLab MR from sgts.gitlab-dedicated.com. Triggers: review MR, read MR, check MR, fix comment, show diff, what changed in MR, pr review, code review, review merge request, fix review comment, paste of a sgts.gitlab-dedicated.com MR URL or a bare MR number with an action."
tools: [read, search, edit, execute, todo]
argument-hint: "Provide: (1) MR URL (https://sgts.gitlab-dedicated.com/.../merge_requests/NNN) or just the MR number, and (2) the action — e.g. 'review', 'summarise', 'fix comment: <comment text>', 'checkout'"
---

## Context

- GitLab instance: `sgts.gitlab-dedicated.com` — requires TechPass auth; HTTP fetch always returns a login page. **Never use fetch_webpage for this host.**
- Git SSH access is configured and works.
- Repos live under `/Users/a2456813/Development/IdeaProjects/`.
- VS Code GitLab extension (`gitlab.gitlab-workflow`) is installed but cannot be scripted for MR reads.

---

## Step 1 — Resolve inputs

From the user's message:

| What to extract | How |
|---|---|
| MR number | From URL (`/merge_requests/NNN`) or bare number |
| Repo name | From URL path segment before `/-/` (e.g. `molb-agency-portal-backend`) |
| Target branch | Assume `master` unless the user states otherwise |
| Action | `review` · `summarise` · `fix comment` · `checkout` · `diff` |

Repo path = `/Users/a2456813/Development/IdeaProjects/<repo-name>`.

---

## Step 2 — Fetch the MR

```
cd <repo-path>
git fetch origin "refs/merge-requests/<MR_ID>/head:mr-<MR_ID>"
```

If ambiguity warning appears for `FETCH_HEAD`, use the SHA printed by the fetch instead.

---

## Step 3 — Gather MR data

Run all of the following:

```
# MR branch name & latest commit
git log mr-<MR_ID> --oneline -1

# Commits unique to this MR
git log origin/<target-branch>..mr-<MR_ID> --oneline

# Files changed (summary)
git diff origin/<target-branch>...mr-<MR_ID> --stat

# Full diff
git diff origin/<target-branch>...mr-<MR_ID>
```

---

## Step 4 — Execute the action

### `review` or `summarise`
Produce a structured summary:

1. **Title & ticket** — infer from latest commit message.
2. **What it does** — one paragraph, business intent.
3. **Files changed** — grouped by layer (controller / service / repository / DTO / test / config / other); one line per file describing the change.
4. **Review observations** — list any of the following found in the diff:
   - Logic correctness issues
   - Missing error handling or edge cases
   - Security concerns (auth checks, input validation, SQL injection risk in raw queries)
   - Test coverage gaps
   - Naming or convention deviations from the rest of the codebase
   - Performance concerns (N+1 queries, missing indexes implied by new queries)
5. **Verdict** — `Approve` / `Request changes` / `Needs discussion`, with a one-line reason.

### `diff`
Print the grouped file summary and full diff as-is from Step 3.

### `fix comment: <comment text>`
1. Identify the file and location the comment refers to (search the diff and codebase).
2. Read the current file content.
3. Apply the fix — follow existing codebase conventions exactly.
4. Confirm what was changed.

### `checkout`
```
git checkout mr-<MR_ID>
```
Tell the user which branch they are now on.

---

## Constraints

- Never fetch the MR URL over HTTP — it will only return a login page.
- Never guess review comments or invent issues not visible in the diff.
- When fixing a comment, only change what the comment asks — do not refactor surrounding code.
- Always quote the relevant diff lines when citing a review observation.
