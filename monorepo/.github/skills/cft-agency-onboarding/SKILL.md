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

The Confluence guide is the source of truth, read at run time; this skill never copies its procedure.

| Constant | Value |
|---|---|
| Guide page | id `283475666` — "CFT: Guide for Devs", space BIZSG (`$JIRA_BASE_URL/wiki/spaces/BIZSG/pages/283475666`) |
| Calls | **jira-ticket** skill scripts (`J=.github/skills/jira-ticket/scripts`) — auth, timeouts, retries, errors handled there |

## Phase 1 — Ingest request

- IF: Jira key → `bash $J/get-issue.sh --issue-key <KEY>`; IF fails → STOP with the script's error
- Extract (absent → `unknown`, never guess): agency, team, env (staging/prod), change type (new agency · new team · protocol switch · new direction · webhook change · key rotation), protocol (SFTP/HTTPS), directions (gobiz→agency / agency→gobiz), PGP (yes/no/unknown), zone (Internet/Intranet/unknown), webhook URL, reference workflow names/IDs

## Phase 2 — Fetch guide live

- `bash $J/get-page.sh --page-id 283475666` → text + `Version N · <when>`
- IF: non-zero exit → STOP: report the error; never fall back to memory of the guide
- STORE: version + date; locate step headings (`Step N`, `Step 4.1`, `Step 4.2`, …); note which steps contain code blocks (commands)

## Phase 3 — Map request to guide steps

Hint table only — verify every step against the fetched text; IF missing/renamed → follow the live guide and note it.

| Change type | Likely steps |
|---|---|
| New agency, SFTP | all |
| New agency, HTTPS | all; skip IP whitelisting; Step 4.2 not 4.1 |
| New team, existing agency | agency Application, workflows, webhook; reuse GoBiz Application/keys |
| SFTP→HTTPS, existing agency | HTTPS Client Application (4.2), workflows, credential hand-over; GoBiz Application + job config unchanged |
| New direction | that direction's workflow (+ keys if encrypted) |
| Webhook change | webhook step + "Updating agency's webhook" |

- Conditional steps ("only applicable if…") → carry the condition verbatim
- `TODO` markers / copy-paste inconsistencies in selected steps → Gaps

## Phase 4 — Derive concrete values

- Apply the guide's naming conventions (Application, workflows, webhook, keys, credentials file)
- Workflow name/vanity-ID over the guide's length limit → flag; propose nothing without user input
- Per workflow: sender/receiver apps, data types, extensions, encryption, webhooks/events — protocol differences called out
- Ticket names/IDs differing from convention → flag for user decision
- Unknown inputs → `<…>` placeholder

## Phase 5 — Gaps (each with suggested owner)

Always check: zone + hostname for env · PGP required (agency expectation, not protocol) · existing Application/workflows in env (reuse vs create) · name collisions when adding a second protocol · webhook URL · test window + who confirms · credential hand-over channel.

## Phase 6 — Write checklist

`<DOCS_DIR>/cft-checklist.md` (docs-folder skill; `cft-checklist-<agency>.md` when one ticket covers >1 agency):

```md
# CFT checklist: <agency>[-<team>] — <env> — <change type>
> Guide: CFT Guide for Devs · v<version> · <date> · <url>
## Request summary
## Steps (in order)
- [ ] Step N — <title>: <action with names/values filled in>
## Values
| Item | Value | Source |
## Gaps / questions
| # | Question | Suggested owner |
## Not verified
```

EMIT: path + 3 lines (steps selected, gap count, guide version).

## Constraints

- Read-only: no writes to CFT portal, Jira, Confluence, or repos; don't run guide commands (ssh-keygen, sftp, gpg) — list them
- Never print/store credentials, Client Secrets, passwords, private keys
- Behaviour not in the fetched guide → "Not verified"; cite guide version/date
