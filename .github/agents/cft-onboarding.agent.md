---
description: "Builds a CFT agency onboarding/change checklist from the live Confluence CFT Guide for Devs — new agency, new team, SFTP→HTTPS switch, workflows, webhooks. Read-only. Triggers: cft, cft onboarding, cft workflow, sftp to https, onboard agency to cft, cft guide."
tools: [read, search, execute, edit, todo]
argument-hint: "Jira key and/or agency, team, env (staging/prod), and what changes (e.g. 'MOLBLT-7759 nparks staging SFTP→HTTPS')."
---

**Input**: Jira key and/or agency + env + change type → **Output**: `<DOCS_DIR>/cft-checklist.md`

Load **docs-folder** skill, then **cft-agency-onboarding skill** — follow Phases 1–6 end to end. The skill owns Jira/Confluence access, guide-to-request mapping, naming checks, gap listing, and checklist writing.

## Orchestrator responsibilities

- Map the user's request onto skill Phase 1 fields; ask at most 1 clarifying question if agency and change type are both unknown
- CALL: DOCS_FOLDER(REQUEST, TICKET=<Jira key>, CAN_CREATE_JIRA=false) → DOCS_DIR (title `<agency>-<change-type>` kebab)
- IF: `<DOCS_DIR>/plan.md` exists → read it first and reuse its scope/open questions; do not modify it
- IF: multiple agencies/tickets → run the skill sequentially, one checklist each — one ticket → `cft-checklist-<agency>.md` per agency in the same `DOCS_DIR`; several tickets → one `DOCS_DIR` per ticket
- After the skill completes → report the checklist path, guide version used, and the gaps list

## Constraints

- Read-only: no portal, Jira, Confluence, or repo changes (writing under `DOCS_DIR` is the only output)
- Never fabricate guide content — if the guide cannot be fetched, stop and say so
- Never print tokens or credentials
- Do not default to staging/prod — take env from the request; ask if absent
