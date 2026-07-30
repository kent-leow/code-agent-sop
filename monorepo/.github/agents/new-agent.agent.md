---
description: "Base agent mode with worktree conventions and authoring standards. Loaded by agents that need git worktree discipline and structured step authoring. Triggers: new agent, base agent, agent mode."
tools: [read, search, edit, execute]
argument-hint: "Describe the task to execute under agent mode conventions."
---

**Input**: task description → **Output**: task completed following agent + worktree conventions.

## Agent Mode

- `.agent.md` instructions are absolute and non-negotiable
- Read full `.agent.md` before any action; follow every step in order
- Plan-only → don't implement; implement → don't skip steps
- **Git write operations**: blocked by default — never `git commit`, `git push`, or create/switch branches unless explicitly required by an active SOP, `.agent.md`, or user command

## Worktree Discipline

- All file edits, test runs, builds, local service starts → `WORK_DIR` (worktree), never `REPO_DIR`
- `REPO_DIR` only for: `git worktree add/remove/prune`, `BRANCH_SETUP` (sync default branch)
- Poll-loop fix cycles: re-create worktree via `WORKTREE_SETUP` before fixes, teardown after push
- Start app/service: `cd "${WORK_DIR}" && <start command>`

## Authoring Standards (Agents & Skills)

All `.agent.md` and `SKILL.md` files must follow:

### Structure
- Frontmatter: `description`, `tools`, `argument-hint`
- One-line **Input → Output** summary
- Phases numbered: `## Phase N — Title`
- Steps use prefix format — no prose paragraphs

### Step Prefixes

| Prefix | Meaning |
|--------|---------|
| `DO:` | Execute action |
| `IF:` | Conditional (→ action) |
| `LOOP:` | Iterate collection |
| `CALL:` | Invoke skill(params) → outputs |
| `EMIT:` | Output to user/file |
| `STORE:` | Save value |
| `STOP:` | Halt with reason |

### Style
- Minimal tokens; no filler; tables over prose
- `CALL:` for skill invocations — never repeat skill internals
- Constraints section at end — short bullets
- No duplicate logic across agents — extract to skill

## Constraints

- Search codebase before asking user
- Stay in scope — no changes beyond stated task
- Every claim must cite file, code, or terminal output
