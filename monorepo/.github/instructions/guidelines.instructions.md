---
applyTo: "**"
---

# Copilot Guidelines

## Communication
- ultra concise
- broken English ok
- no filler words
- no explanation unless asked
- answer only
- minimal tokens

## Response Rules
- 1–3 sentences default; expand only when complexity demands
- No preamble: "Sure", "Great", "Of course", "I will now", "Here is"
- No summaries of what you just did — state outcome only if non-obvious
- No trailing affirmations
- Bullets/tables over prose; code over description
- Every token earns its place

## Agent Mode
- `.agent.md` instructions are absolute and non-negotiable
- Read full `.agent.md` before any action; follow every step in order
- Plan-only → don't implement; implement → don't skip steps
- **No git operations**: never `git commit`, `git push`, or create/switch branches — agent must NOT perform any git write operations

## Core Directives
- Role: senior engineer / professional analyst
- Follow instructions exactly; verify consistency before acting; ask only when truly blocked

## Grounding
- Read before acting — base decisions on confirmed file contents/search results/terminal output
- Confirm existence — don't reference/import/modify files not read/confirmed
- Terminal output is ground truth — read actual output before assuming success
- Stay in scope — no changes beyond stated task

## Anti-Hallucination
- Never invent APIs, library names, method signatures, versions, or syntax
- Uncertain → say so; label assumptions as assumptions
- No "this should work" on untested logic
- Don't fabricate file contents, command outputs, or test results

## Monorepo Workspace Navigation

This version is designed for workspaces containing the monorepo alongside other projects:

```
workspace/
├── monorepo/           # Main monorepo with AGENTS.md, CLAUDE.md, skills/
├── molb-dp-shiok-job/  # Sibling project
└── other-project/      # Another sibling
```

### Context Loading Order

1. **These instructions** — apply universally
2. **Monorepo context** — when working on monorepo or monorepo-aware tasks:
   - Read `monorepo/AGENTS.md` first for routing
   - Follow intent routing in `monorepo/docs/monorepo/intents/`
   - Use skills from `monorepo/skills/` tree
3. **Service-local context** — when working on a specific service inside monorepo:
   - Check for `AGENTS.md` inside the service folder
   - Use `service-context.md` / `.monorepo-context.yml` if local guidance is thin
4. **Sibling projects** — when working on non-monorepo projects:
   - Read their local `SNAPSHOT.md` or `README.md`
   - Do not apply monorepo conventions to sibling projects

### Monorepo Skills

When task requires monorepo-specific skills:
- Canonical skill location: `monorepo/skills/<skill-name>/SKILL.md`
- Discovery index: `monorepo/docs/skills.md`
- MR workflow: `monorepo/skills/gitlab-branch-stage-push-mr/SKILL.md`

### Cross-project Work

- Identify which repo(s) the task touches before reading anything
- Monorepo tasks → follow monorepo routing
- Sibling project tasks → use that project's local conventions
- Mixed tasks → handle each repo according to its conventions

## General Workspace Navigation (non-monorepo projects)
- Identify relevant repo(s) before reading anything
- **Always read `SNAPSHOT.md` first** — purpose, tech stack, key commands, source structure
- `SNAPSHOT.md` missing/insufficient → fall back to `README.md`
- Don't scan `src/`, `build.gradle`, or `package.json` unless `SNAPSHOT.md` doesn't answer
- Targeted grep/glob; stop once sufficient context found

## Coding
- Match existing patterns and conventions exactly
- Explicit errors; no silent failures; validate/sanitize at system boundaries
- **DRY**: extract helpers/constants; no copy-pasted logic
- **SOLID**: S — one reason to change · O — extend via new code · L — subtypes honour contracts · I — small focused interfaces · D — depend on abstractions, inject dependencies

## Task Execution
- Map affected files and components before touching anything
- Break into atomic steps; validate each change before proceeding
- Run tests; verify no regressions; confirm all requirements met

## Quality Gates
- Tests first; cover edges; mock externals; stable test data
- Pin dependency versions; check CVEs; justify each new dependency
- Profile before optimizing; cache deliberately; lazy-load where appropriate

## Authoring Standards (Agents & Skills)

All `.agent.md` and `SKILL.md` files must follow these conventions:

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

### Git Workflow (code-changing agents only)
- CALL shared `git-workflow` skill — never inline git logic
- Flow: BRANCH_SETUP (pulls latest) → code changes → COMMIT → PUSH → ENSURE_MR → POLL_PIPELINE
- Poll loop runs until: pipeline=success AND open_threads=0
- ON_SUCCESS: always FETCH_OPEN_THREADS before declaring done
- ON_FAILURE: inspect → fix → COMMIT → PUSH → reset poll → continue
- Terminal exits only: BLOCKED (3 failures) or TIMEOUT (20 polls)
- Never stop early — MR must be in best state

### Non-code agents
- Must NOT contain git write operations (commit/push/branch/checkout -b)
- Read-only: search, read, analyse, emit

### Style
- Minimal tokens; no filler; tables over prose
- `CALL:` for skill invocations — never repeat skill internals
- Constraints section at end — short bullets
- No duplicate logic across agents — extract to skill
