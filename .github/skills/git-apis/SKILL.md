---
name: git-apis
description: "Shared GitLab + GitHub REST API operations: fetch discussions, post inline/general comments, reply, resolve threads, approve MR/PR."
---

# git-apis

Shared platform API operations for GitLab and GitHub.

## Auth

| Platform | Header |
|---|---|
| GitLab | `PRIVATE-TOKEN: $GITLAB_TOKEN` |
| GitHub | `Authorization: Bearer $GITHUB_TOKEN` |

---

## FETCH_DISCUSSIONS

**GitLab:**
```bash
curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
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
