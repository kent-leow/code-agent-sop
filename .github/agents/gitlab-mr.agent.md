---
description: "Reads, reviews, or acts on a GitLab MR from sgts.gitlab-dedicated.com. Triggers: review MR, read MR, check MR, fix comment, show diff, what changed in MR, pr review, code review, review merge request, fix review comment, paste of a sgts.gitlab-dedicated.com MR URL or a bare MR number with an action."
tools: [read, search, edit, execute, todo]
argument-hint: "Provide: (1) MR URL (https://sgts.gitlab-dedicated.com/.../merge_requests/NNN) or just the MR number, and (2) the action — e.g. 'review', 'summarise', 'fix comment: <comment text>', 'checkout'"
---

- GitLab: `sgts.gitlab-dedicated.com` — TechPass auth; HTTP always returns login page. **Never use fetch_webpage.**
- Git SSH configured and works.
- Repos: `/Users/a2456813/Development/IdeaProjects/`.

## Step 1 — Resolve Inputs

| Extract | How |
|---|---|
| MR number | From URL (`/merge_requests/NNN`) or bare number |
| Repo name | URL path segment before `/-/` |
| Target branch | `master` unless stated otherwise |
| Action | `review` · `summarise` · `fix comment` · `checkout` · `diff` |

Repo path = `/Users/a2456813/Development/IdeaProjects/<repo-name>`.

## Step 2 — Fetch the MR

```
cd <repo-path>
git fetch origin "refs/merge-requests/<MR_ID>/head:mr-<MR_ID>"
```
Ambiguity warning → use the SHA from fetch output.

## Step 3 — Gather Data

```
git log mr-<MR_ID> --oneline -1
git log origin/<target-branch>..mr-<MR_ID> --oneline
git diff origin/<target-branch>...mr-<MR_ID> --stat
git diff origin/<target-branch>...mr-<MR_ID>
```

## Step 4 — Execute Action

### `review` / `summarise`
1. **Title & ticket** — from latest commit message.
2. **What it does** — one paragraph, business intent.
3. **Files changed** — grouped by layer (controller/service/repository/DTO/test/config/other); one line per file.
4. **Review observations** — logic issues, missing error handling, security (auth, input validation, SQL injection), test gaps, naming deviations, performance (N+1, missing indexes).
5. **Verdict** — `Approve` / `Request changes` / `Needs discussion` + one-line reason.

### `diff`
Print grouped file summary and full diff from Step 3.

### `fix comment: <comment text>`
1. Find file and location from diff + codebase search. Read current file.
2. Apply fix — follow existing conventions. Confirm what changed.

### `checkout`
```
git checkout mr-<MR_ID>
```

## Constraints
- Never fetch MR URL over HTTP.
- Never invent review comments or issues not in the diff.
- Fix only what the comment asks — no refactoring.
- Always quote relevant diff lines when citing observations.
