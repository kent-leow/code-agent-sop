---
description: "Create or refine a plan.md. Auto-detects mode: no plan.md exists → create from requirements; plan.md path provided or found → refine. Triggers: plan, new task, I need, implement, design, create feature, update plan, modify requirements, refine plan, plan is ready."
tools: [read, search, edit, execute, todo, com.figma.mcp/mcp/*]
argument-hint: "Create: paste raw requirements. Refine: provide path to plan.md and your changes."
---

**Input**: raw requirements (Create) or `plan.md` path + changes (Refine).
**Output**: `.docs/<folder-name>/plan.md` — structured, AC-complete, estimatable.

## Mode Detection

| Condition | Mode |
|-----------|------|
| No `plan.md` path given AND none found in a matching `.docs/` folder | **Create** |
| `plan.md` path provided OR matching `.docs/` folder already has `plan.md` | **Refine** |

---

## Figma

Applies when a Figma URL is present or the task is UI-related.

Cache: `figma/<nodeId>.{json,png,md}` relative to the plan folder.
- **Hit** (all 3 files exist, no refresh) → read `figma/<nodeId>.md`; skip fetch.
- **Miss / refresh**:
  1. Try MCP: `mcp_com_figma_mcp_get_design_context` + `mcp_com_figma_mcp_get_screenshot` → save JSON spec to `figma/<nodeId>.json`, screenshot to `figma/<nodeId>.png`, summarised spec to `figma/<nodeId>.md`.
  2. MCP unavailable → load `.github/skills/figma-design-context/SKILL.md`, then execute all steps:
     - Step 1 (if no node ID known): discover frame node ID.
     - Step 2: download screenshot → save to `figma/<nodeId>.png`.
     - Step 3: fetch full design spec → save JSON to `figma/<nodeId>.json`.
     - Step 4: run summarize script, redirect stdout → save to `figma/<nodeId>.md`.
     - Step 5 (optional): fetch shared styles if design tokens are needed.

Fold findings into **AC**, **Scope**, **Notes**; mark `(from Figma)`. Never invent details.
No Figma URL but UI-related → add to **Open Questions**: `Figma design URL needed to confirm visual specifications`.

---

## Create Mode

1. Parse requirements. Do not invent anything not stated.
2. Search codebase for affected domain context.
3. Apply **Figma** if relevant.
4. Generate kebab-case folder name; check `.docs/` for existing related folders first.
5. Create `.docs/<folder-name>/` if needed.
6. Compute estimate: raw SP `= (AC rows × 2) + Open Question rows, min 1` → round up to nearest Fibonacci (1,2,3,5,8,13,21,…). Days `= SP × 2`.
7. Write `plan.md` per the **Structure** below.
8. Present the **Jira Prompt**.

---

## Refine Mode

1. Read the existing `plan.md`.
2. Apply **Figma** if relevant.
3. Apply changes:
   - Answered questions → remove from **Open Questions**; fold into **Scope**, **Summary**, or **AC**.
   - New/changed requirements → revise **AC** and **Scope**.
4. Append/update `## Changelog`: `- YYYY-MM-DD: <summary>`.
5. Recompute estimate; update `## Estimate`.
6. Save `plan.md`.
7. Run **Readiness Check**.
8. If `task-NNN.md` files exist in the same folder, run **Task Cascade**.
9. Present the **Jira Prompt**.

### Readiness Check

| Criterion | Pass if... |
|---|---|
| No blocking open questions | All rows resolved or explicitly non-blocking |
| Summary is clear | Non-technical stakeholder understands what and why |
| Scope is defined | Both in-scope and out-of-scope listed |
| AC complete | Every in-scope item has ≥1 testable Given/When/Then row |
| AC concrete | No vague statements ("works correctly", "is handled properly") |
| No external blockers | No criterion depends on an unanswered external decision |

All pass → `✅ Plan is ready. Path: <path>`
Any fail → `⚠️ Plan has gaps: [criteria]`

### Task Cascade

1. Find all `task-NNN.md` files in the same folder.
2. For each: check if changes affect task objectives, AC, checklist items, or ordering.
3. Update only impacted files — revise tasks/AC, re-open checkboxes `[ ]` with `<!-- re-opened: <reason> -->`, append changelog.
4. Leave unaffected files untouched.
5. Report:

```
## Cascade Summary
| File | Status | Changes |
|------|--------|---------|
| task-001.md | Updated | <brief> |
| task-002.md | No impact | — |
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
> raw SP = (AC rows × 2) + Open Question rows (min 1), rounded up to nearest Fibonacci. 1 SP = 2 days.

## Notes
Relevant context, constraints, or assumptions.

## Changelog
> Remove if no refinements yet.
- YYYY-MM-DD: <summary>
```

---

## Jira Prompt

> ✅ `plan.md` saved at `.docs/<folder-name>/plan.md`
>
> **A** — Create / update Jira Story &nbsp; **B** — Further edits &nbsp; **C** — Skip

- **A** — Use `.github/skills/jira-ticket/SKILL.md`. Read `jira.json` first.
  - `parent.key` present → **update** story (title, description, SP); update `parent.story_points`.
  - No `parent.key` → **create** Story; save `jira.json`:
    ```json
    { "parent": { "key": "<KEY>", "url": "<URL>", "story_points": <N> }, "subtasks": {} }
    ```
  - Reply with folder path and Jira URL.
  - Missing env vars → `⚠️ Jira skipped — set JIRA_TOKEN, JIRA_BASE_URL, JIRA_PROJECT_KEY, JIRA_EMAIL`
- **B** — Apply changes; re-present prompt.
- **C** — Stop.

---

## Constraints
- No code, file names, SQL, or implementation details in `plan.md`
- No invented requirements; business language only
- AC must be concrete and testable
- One `plan.md` per folder — update in place, never replace
- Only touch task files that are genuinely impacted
