---
description: "Create or refine a plan.md. Auto-detects mode: if a plan.md path is provided or already exists in a related .docs/ folder → refine; otherwise → create from raw requirements. Replaces @refine-plan. Triggers: analyze, plan, new task, I need, I want, implement, design, how do I, create feature, answer questions, update plan, modify requirements, refine plan, plan is ready."
tools: [read, search, edit, execute, todo, com.figma.mcp/mcp/*]
argument-hint: "Create: paste raw requirements. Refine: provide path to plan.md and your changes / answers."
---

Create or refine a `plan.md` in `.docs/<task-name>/`. Detect the mode first, then proceed.

## Mode Detection

| Condition | Mode |
|-----------|------|
| No `plan.md` path given AND no `plan.md` found in a matching `.docs/` folder | **Create** |
| `plan.md` path provided OR a matching `.docs/` folder already contains `plan.md` | **Refine** |

---

## Figma (UI tasks)

Applies to both modes whenever a Figma URL is present or the task is clearly UI-related.

Cache: `figma/<nodeId>.{json,png,md}` relative to the plan folder.
- **Hit** (all three files exist, no update requested) → read `figma/<nodeId>.md`; skip fetching entirely.
- **Miss / refresh**:
  - **Try Figma MCP first**: call `mcp_com_figma_mcp_get_design_context` + `mcp_com_figma_mcp_get_screenshot`; save the design JSON to `figma/<nodeId>.json`, the screenshot to `figma/<nodeId>.png`, and write a human-readable summary to `figma/<nodeId>.md`.
  - **If MCP is unavailable or blocked by admin**: load the `figma-design-context` skill (`.github/skills/figma-design-context/SKILL.md`) and follow its procedure, directing output to `figma/<nodeId>.{json,png,md}`.

Incorporate findings into **AC**, **Scope**, and **Notes**; mark items `(from Figma)`. Do not invent details absent from the design.
No Figma URL but clearly UI-related → add to **Open Questions**: `Figma design URL needed to confirm visual specifications`.

---

## Create Mode

1. Parse the core task, domain, and requirements. Do not invent anything not stated.
2. Quick targeted codebase search to understand the affected domain.
3. Apply the **Figma** block above if relevant.
4. Generate a kebab-case folder name. Check `.docs/` for existing related folders first.
5. Create `.docs/<folder-name>/` if needed.
6. Compute estimate: raw SP `= (AC rows × 2) + Open Question rows, minimum 1`, then round up to the nearest Fibonacci number (1, 2, 3, 5, 8, 13, 21, …). Days `= SP × 2`.
7. Write `plan.md` per the **plan.md Structure** below.
8. Present the **Jira Confirmation Prompt** and wait for the user's reply.

---

## Refine Mode

1. Read the existing `plan.md`.
2. Apply the **Figma** block above if relevant (re-fetch on new/updated URLs).
3. Apply the provided context:
   - Answered questions → remove from **Open Questions**; fold into **Scope**, **Summary**, or **AC**
   - New/changed requirements → revise **AC** and **Scope**
   - Append/update `## Changelog`: `- YYYY-MM-DD: <one-line summary>`
4. Recompute estimate and update `## Estimate`.
5. Save `plan.md` in place.
6. Run the **Readiness Check** below.
7. If `execute-plan-NNN.md` files exist in the same folder, run the **Execute Plan Cascade** below.
8. Present the **Jira Confirmation Prompt** and wait for the user's reply.

### Readiness Check

| Criterion | Pass if... |
|---|---|
| No blocking open questions | All rows resolved or explicitly non-blocking |
| Summary is clear | Non-technical stakeholder understands what will be built and why |
| Scope is defined | Both in-scope and out-of-scope items listed |
| AC complete | Every in-scope item has ≥1 testable Given/When/Then row |
| AC concrete | No vague statements ("works correctly", "is handled properly") |
| No external blockers | No criterion depends on an unanswered external decision |

**All pass →** `✅ Plan is ready. Path: <plan path>`

**Any fail →** `⚠️ Plan has gaps: [list failing criteria]`

### Execute Plan Cascade

1. Find all `execute-plan-NNN.md` files in the same folder.
2. For each, check whether changes affect task objectives, AC, checklist items, or ordering.
3. Update only impacted files — revise tasks/AC, mark re-opened checkboxes `[ ]` with `<!-- re-opened: <reason> -->`, append to changelog.
4. Leave unaffected files untouched.
5. Report:

```
## Cascade Summary
| File | Status | Changes |
|------|--------|---------|
| execute-plan-001.md | Updated | <brief description> |
| execute-plan-002.md | No impact | — |
```

---

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
| Given | ... |
| When  | ... |
| Then  | ... |

## Open Questions
> Remove if none.

| # | Question | Impact if unresolved |
|---|----------|----------------------|
| 1 | ... | ... |

## Estimate
**Story Points**: <N> SP (~<N × 2> days)
> Formula: raw SP = (AC rows × 2) + Open Question rows (minimum 1), rounded up to the nearest Fibonacci number (1, 2, 3, 5, 8, 13, 21, …). 1 SP = 2 days work.

## Notes
Relevant context, constraints, or assumptions.

## Changelog
> Remove if no refinements yet.
- YYYY-MM-DD: <one-line summary>
```

---

## Jira Confirmation Prompt

Present after saving `plan.md`. **Wait for the user's reply before doing anything else.**

> ✅ `plan.md` saved/updated at `.docs/<folder-name>/plan.md`
>
> What would you like to do next?
> **A** — Create / update the Jira Story for this plan
> **B** — Make further updates to this plan
> **C** — Nothing (skip Jira)

- **A** — Jira Story sync (use the `jira-ticket` skill — `.github/skills/jira-ticket/SKILL.md`):
  - Use the full contents of `plan.md` as the Jira description (pass as `--description`).
  - **Always read `jira.json` first — if `parent.key` is present, you MUST update; never create a new ticket.**
  - `jira.json` with `parent.key` exists → **update** the story (title, description, story points); update `parent.story_points` in `jira.json`.
  - No `jira.json` or missing `parent.key` → **create** a Story; save `jira.json`:
    ```json
    { "parent": { "key": "<KEY>", "url": "<URL>", "story_points": <N> }, "subtasks": {} }
    ```
  - Reply with folder path, one-line summary, and Jira card URL.
  - If JIRA env vars are missing: `⚠️ Jira skipped — set JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL`
- **B** — Wait for instructions; apply; re-present this prompt.
- **C** — Stop.

---

## Constraints
- No code, file names, SQL, or implementation details in `plan.md`.
- No invented requirements; business/product language only.
- AC must be concrete and testable.
- One `plan.md` per folder — always update in place when refining.
- Only touch execute-plan files that are genuinely impacted.
