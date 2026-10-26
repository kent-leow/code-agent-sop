---
name: cft-agency-onboarding
description: Turn a CFT (Cloud File Transfer) agency request — new agency, new team, SFTP→HTTPS switch, new direction, webhook change — into a step-by-step checklist derived live from the Confluence "CFT Guide for Devs". Read-only; never touches the CFT portal. Requires JIRA_EMAIL, JIRA_TOKEN, JIRA_BASE_URL.
metadata:
  category: operations
  tier: standard
  status: active
  invocation: explicit
---

# CFT Agency Onboarding

**Input**: Jira key and/or agency, team, env, change type → **Output**: `<DOCS_DIR>/cft-checklist.md`

The Confluence guide is the source of truth. This skill reads it at run time and maps the request onto its steps. It never copies the guide's procedure into itself, so the guide can change without this skill going stale.

## Constants

| Name | Value |
|---|---|
| `GUIDE_PAGE_ID` | `283475666` (title "CFT: Guide for Devs", space BIZSG) |
| Page URL | `$JIRA_BASE_URL/wiki/spaces/BIZSG/pages/283475666/CFT+Guide+for+Devs` |
| API | `$JIRA_BASE_URL/wiki/rest/api/content/<id>?expand=body.storage,version` |

## Prerequisites

- DO: confirm `JIRA_EMAIL`, `JIRA_TOKEN`, `JIRA_BASE_URL` are non-empty (never print values)
- IF: any missing → STOP: tell user to `source ~/.zshenv`
- IF: curl fails with `self signed certificate` → retry with `--cacert <corporate CA bundle>` (path from user/env); never use `-k`
- Network call → request network access up front

## Phase 1 — Ingest request

- IF: Jira key given → DO: GET `$JIRA_BASE_URL/rest/api/3/issue/<KEY>?fields=summary,description,comment,issuelinks`; flatten ADF to text
- DO: extract (mark each `unknown` if absent — never guess):

| Field | Examples |
|---|---|
| agency, team | `nparks`, none |
| env | staging / prod |
| change type | new agency · new team · protocol switch (SFTP→HTTPS or reverse) · new direction · webhook change · key rotation |
| protocol | SFTP / HTTPS |
| directions | gobiz→agency, agency→gobiz |
| encryption (PGP) | yes / no / unknown |
| zone | Internet / Intranet / unknown |
| webhook URL | provided / none |
| reference workflows | names / IDs quoted in ticket |

## Phase 2 — Fetch guide live

- DO: GET the guide via the API above with basic auth
- IF: HTTP ≠ 200 → STOP: report status; do not fall back to memory of the guide
- STORE: `version.number`, `version.when`
- DO: strip storage-format HTML to text (drop `ac:plain-text-body` code blocks only after noting which steps contain commands)
- DO: locate the step headings (`Step N`, `Step 4.1`, `Step 4.2`, …) in the fetched text

## Phase 3 — Map request to guide steps

- DO: select steps using the table below as a **starting hint only**; verify each against the fetched text
- IF: a hinted step is missing/renamed in the live guide → follow the live guide and EMIT a note

| Change type | Likely steps (verify) |
|---|---|
| New agency, SFTP | all steps |
| New agency, HTTPS | as above; skip IP whitelisting; Step 4.2 instead of 4.1 |
| New team, existing agency | agency Application, workflows, webhook; reuse GoBiz Application/keys |
| SFTP→HTTPS switch, existing agency | HTTPS Client Application (Step 4.2), workflows, credential hand-over; GoBiz Application and job config expected unchanged |
| New direction | workflow for that direction (+ keys if encrypted) |
| Webhook change | webhook step + "Updating agency's webhook" |

- IF: a step is conditional in the guide ("only applicable if…") → carry the condition into the checklist verbatim
- IF: the guide has `TODO` markers or an obvious copy-paste inconsistency in a selected step → EMIT it under Gaps

## Phase 4 — Derive concrete values

- DO: apply the guide's naming conventions to the request (Application, workflows, webhook, key names, credentials file name)
- DO: check workflow name/vanity-ID length against the guide's stated limit; IF over → flag, propose nothing without user input
- DO: for each selected workflow step, list the settings the guide prescribes (sender/receiver apps, data types, allowed extensions, encryption, webhooks and events) with protocol-specific differences called out
- DO: compare ticket reference names/IDs with the guide's convention; IF they differ → flag for user decision
- IF: tool inputs for a value are `unknown` → leave placeholder `<…>`; never invent

## Phase 5 — Gaps

- DO: list what neither ticket nor guide answers, each with an owner suggestion. Always check:
  - zone (Internet/Intranet) and hostname for the target env
  - PGP required or not (guide ties it to agency expectation, not protocol)
  - existing Application/workflows for this agency in the target env (reuse vs create)
  - name collisions with existing Applications/workflows when adding a second protocol for the same agency
  - webhook URL needed
  - test window and who confirms success
  - credential hand-over channel

## Phase 6 — Write checklist

- DO: write `<DOCS_DIR>/cft-checklist.md` (`DOCS_DIR` from docs-folder skill DOCS_FOLDER; `cft-checklist-<agency>.md` when one ticket covers >1 agency)

```md
# CFT checklist: <agency>[-<team>] — <env> — <change type>
> Guide: CFT Guide for Devs · v<version> · <date> · <url>
## Request summary
## Steps (in order)
- [ ] Step N — <title>: <what to do for this request; names/values filled in>
## Values
| Item | Value | Source |
## Gaps / questions
| # | Question | Suggested owner |
## Not verified
```

- EMIT: file path + 3-line summary (steps selected, gaps count, guide version)

## Constraints

- Read-only: never create/modify anything in the CFT portal, Jira, Confluence, or repos
- Never print or store credentials, Client Secrets, passwords, private keys
- Never state a CFT behaviour not found in the fetched guide; put it under "Not verified"
- Cite guide version/date in every checklist
- Do not run guide commands (ssh-keygen, sftp, gpg); list them only
