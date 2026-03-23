---
description: "Use when a user provides raw requirements, a new task, feature request, question, or anything needing analysis and planning. Triggers: analyze, plan, new task, requirements, I need, I want, implement, design, how do I, create feature. Produces a Jira-ready plan.md in .docs/<task-name>/ folder. Next step: @refine-plan."
tools: [read, search, edit, execute, todo]
argument-hint: "Paste your raw requirement, question, feature request, or task description"
---

Receive raw input and produce a concise, Jira-ready `plan.md` in `.docs/<task-name>/`.

## Steps
1. Parse the core task, domain, and requirements. Do not invent anything not stated.
2. Quick targeted codebase search to understand the affected domain.
3. Generate a kebab-case folder name. Check `.docs/` for existing related folders first.
4. Create `.docs/<folder-name>/` if needed; if it exists, update `plan.md` in place.
5. Write `plan.md` per the structure below.
6. **Jira** — Create a Jira Story for this plan using the `jira-ticket` skill:
   - Estimate story points: `(number of AC rows × 2) + (number of Open Questions rows)`, minimum 1.
   - Read the full content of the generated `plan.md` and pass it as the description. The script converts Markdown to Jira ADF automatically — headings, bold text, bullet lists, and tables will render correctly in Jira.
   - Run: `bash .github/skills/jira-ticket/scripts/create-ticket.sh --title "<plan title>" --description "$(cat .docs/<folder-name>/plan.md)" --issue-type Story --story-points <N>`
   - Save `.docs/<folder-name>/jira.json`:
     ```json
     { "parent": { "key": "<KEY>", "url": "<URL>", "story_points": <N> }, "subtasks": {} }
     ```
   - Reply with the folder path, one-line summary, and the Jira card URL.
   - If JIRA env vars are not set, skip and note: `⚠️ Jira skipped — set JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL`

## plan.md Structure

```md
# <Task Title>

## Summary
One paragraph: what this delivers and why. Business language only.

## Scope
**In scope**
- ...

**Out of scope**
- ...

## Acceptance Criteria

| **AC1** | <title> |
|---------|---------|
| Given | ...         |
| When  | ...         |
| Then  | ...         |

| **AC2** | <title> |
|---------|---------|
| Given | ...         |
| When  | ...         |
| Then  | ...         |

## Open Questions
> Remove if none.

| # | Question | Impact if unresolved |
|---|----------|----------------------|
| 1 | ... | ... |

## Notes
Relevant context, constraints, or assumptions.
```

## Constraints
- No code, file names, SQL, or implementation details.
- No invented requirements.
- Business/product language only — non-technical stakeholders must understand it.
- Acceptance criteria must be concrete and testable (no "works correctly").
- Populate **Open Questions** for ambiguous items rather than guessing.
