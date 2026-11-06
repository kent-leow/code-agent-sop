---
name: git-apis
description: "Shared GitLab + GitHub REST API operations: fetch discussions, post inline/general comments, reply, resolve threads, approve MR/PR, fetch failed CI jobs + logs."
---

# git-apis

Shared platform API operations for GitLab and GitHub.

## Auth

| Platform | Header |
|---|---|
| GitLab | `PRIVATE-TOKEN: $GITLAB_TOKEN` |
| GitHub | `Authorization: Bearer $GITHUB_TOKEN` |

Every call: network escalation up front · `curl --silent --show-error --connect-timeout 10 --max-time 60` · token via `-K <(printf 'header = "PRIVATE-TOKEN: %s"\n' "$GITLAB_TOKEN")` (never on argv/in logs) · check HTTP status (`-w '%{http_code}'`) before using the body · `--retry 3` on GET/PUT only — never on comment/approve POSTs (duplicates) · GitLab base `https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}` · paginate `per_page=100` until empty.

---

## FETCH_DISCUSSIONS

**GitLab:**
```bash
curl --silent --show-error --connect-timeout 10 --max-time 60 --retry 3 \
  -K <(printf 'header = "PRIVATE-TOKEN: %s"\n' "$GITLAB_TOKEN") \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/discussions?per_page=100"
```

**GitHub:** Fetch both endpoints:
- `GET /repos/{owner}/{repo}/pulls/{PR_ID}/comments?per_page=100` (inline)
- `GET /repos/{owner}/{repo}/issues/{PR_ID}/comments?per_page=100` (general)

---

## POST_INLINE

Post inline comment on a diff line.

**GitLab:** `POST .../merge_requests/${MR_IID}/discussions`
```json
{"body":"<comment>","position":{"position_type":"text","base_sha":"$BASE_SHA","start_sha":"$BASE_SHA","head_sha":"$HEAD_SHA","old_path":"<file>","new_path":"<file>","new_line":<N>}}
```
Line range: replace `new_line` with `"line_range":{"start":{"type":"new","new_line":<S>},"end":{"type":"new","new_line":<E>}}`

**GitHub:** `POST /repos/{owner}/{repo}/pulls/{PR_ID}/comments`
```json
{"body":"<comment>","commit_id":"$HEAD_SHA","path":"<file>","line":<N>,"side":"RIGHT"}
```
Line range: add `"start_line":<S>,"start_side":"RIGHT"`

---

## POST_GENERAL

Post general (non-inline) comment.

**GitLab:** `POST .../merge_requests/${MR_IID}/notes` → `{"body":"<comment>"}`
**GitHub:** `POST /repos/{owner}/{repo}/issues/{PR_ID}/comments` → `{"body":"<comment>"}`

---

## REPLY

Reply to existing thread.

**GitLab:** `POST .../merge_requests/${MR_IID}/discussions/${discussion_id}/notes` → `{"body":"<reply>"}`
**GitHub:** `POST /repos/{owner}/{repo}/pulls/{PR_ID}/comments` → `{"body":"<reply>","commit_id":"$HEAD_SHA","in_reply_to":<original_comment_id>}`

---

## RESOLVE

Mark thread as resolved.

**GitLab:** `PUT .../merge_requests/${MR_IID}/discussions/${discussion_id}` → `{"resolved":true}`
**GitHub (GraphQL):**
```json
{"query":"mutation{resolveReviewThread(input:{threadId:\"<node_id>\"}){thread{isResolved}}}"}
```
IF: node ID unavailable → REPLY(`"Resolved."`) and note limitation.

---

## APPROVE

**GitLab:** `POST .../merge_requests/${MR_IID}/approve`
**GitHub:** `POST /repos/{owner}/{repo}/pulls/{PR_ID}/reviews` → `{"commit_id":"$HEAD_SHA","event":"APPROVE","body":"LGTM!"}`

---

## FETCH_FAILED_JOBS

Read-only CI evidence: failed jobs of a pipeline + log tail (GitLab; verified 2026-11-06).

**Inputs:** `ENCODED`, `PIPELINE_ID` (or `MR_IID` → latest: `GET .../merge_requests/${MR_IID}/pipelines` → `.[0].id`) → **Outputs:** per failed job `{id, name, stage, failure_reason, allow_failure, web_url}` + last `TAIL` lines of trace

```bash
GL() { /usr/bin/curl --silent --show-error --connect-timeout 10 --max-time 60 --retry 3 \
  -K <(printf 'header = "PRIVATE-TOKEN: %s"\n' "$GITLAB_TOKEN") "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}$1"; }
GL "/pipelines/${PIPELINE_ID}/jobs?scope[]=failed&per_page=100" \
  | /usr/bin/jq -c '.[] | {id, name, stage, failure_reason, allow_failure, web_url}'
GL "/jobs/${JOB_ID}/trace" | sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g; s/^[0-9TZ:.-]+ [0-9A-Z]+ //' | tail -n "${TAIL:-120}"
```

- `allow_failure: true` jobs don't fail the pipeline — report but don't fix first
- Search the trace for the first error, not just the tail: `grep -nE 'ERROR|FAILED|error:|Exception|AssertionError' | head`
- Other read-only CI lookups: recent failed pipelines `GET .../pipelines?status=failed&ref=<branch>&per_page=5` · a pipeline's jobs `GET .../pipelines/${PIPELINE_ID}/jobs?per_page=100`
