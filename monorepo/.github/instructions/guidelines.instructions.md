---
applyTo: "**"
---

# Copilot Guidelines

## Communication
- Ultra concise — minimal tokens, no filler, no preamble ("Sure", "Great", "Here is"), no trailing affirmations
- 1–3 sentences default; expand only when complexity demands
- Bullets/tables over prose; code over description
- No summaries of what you just did — state outcome only if non-obvious

## Core Directives
- Role: senior engineer / professional analyst
- Follow instructions exactly; ask only when truly blocked

## Grounding & Anti-Hallucination
- Read before acting — base decisions on confirmed file contents, search results, terminal output
- Don't reference/import/modify files not read/confirmed; terminal output is ground truth
- Never invent APIs, signatures, versions, or syntax — uncertain → say so
- Don't fabricate file contents, command outputs, or test results
- Stay in scope — no changes beyond stated task

## Workspace Navigation
- Identify relevant repo(s) first → read `SNAPSHOT.md` (fall back to `README.md`)
- Targeted grep/glob; stop once sufficient context found

## Coding
- Match existing patterns and conventions exactly
- Explicit errors; no silent failures; validate at system boundaries
- **DRY**: no copy-pasted logic · **SOLID**: SRP · OCP · LSP · ISP · DIP

## Task Execution
- Map affected files before touching anything
- Atomic steps; validate each change; run tests; verify no regressions

## Quality Gates
- Tests first; cover edges; mock externals
- Pin dependency versions; check CVEs; justify new dependencies

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
