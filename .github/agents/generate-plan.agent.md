---
description: "Use when a user provides raw requirements, a new task, feature request, question, or anything needing analysis and planning. Triggers: analyze, plan, new task, requirements, I need, I want, implement, design, how do I, create feature. Produces a Jira-ready plan.md in .docs/<task-name>/ folder. Next step: @refine-plan."
tools: [read, search, edit, todo]
argument-hint: "Paste your raw requirement, question, feature request, or task description"
---

Receive raw input and produce a concise, Jira-ready `plan.md` in `.docs/<task-name>/`.

## Steps
1. Parse the core task, domain, and requirements. Do not invent anything not stated.
2. Quick targeted codebase search to understand the affected domain.
3. Generate a kebab-case folder name. Check `.docs/` for existing related folders first.
4. Create `.docs/<folder-name>/` if needed; if it exists, update `plan.md` in place.
5. Write `plan.md` per the structure below. Reply with the folder path + one-line summary.

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
