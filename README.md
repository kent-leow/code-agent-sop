<div align="center">

# 🤖✨ Kent's Copilot Agent SOP ✨🤖

**A production-ready collection of VS Code Copilot agents, skills, and instructions**
*Transforming raw requirements into shipped code — fully automated* 🚀

<br/>

[![VS Code](https://img.shields.io/badge/VS%20Code-Copilot-007ACC?style=for-the-badge&logo=visualstudiocode&logoColor=white)](https://code.visualstudio.com/)
[![GitHub Copilot](https://img.shields.io/badge/GitHub-Copilot-black?style=for-the-badge&logo=github&logoColor=white)](https://github.com/features/copilot)
[![Agents](https://img.shields.io/badge/🤖%20Agents-7-brightgreen?style=for-the-badge)](.github/agents/)
[![Skills](https://img.shields.io/badge/🧠%20Skills-2-orange?style=for-the-badge)](.github/skills/)
[![Status](https://img.shields.io/badge/Status-Production%20Ready%20✅-success?style=for-the-badge)](.github/)

<br/>

> 💡 **Say goodbye to manual planning, boilerplate, and context-switching.**
> Every agent in this SOP is a force multiplier — from first requirement to merged PR.

</div>

---

## 🗂️ Structure

```
.github/
├── 🤖 agents/          # Custom Copilot agent modes
├── 📋 instructions/    # Always-on Copilot instructions
└── 🧠 skills/          # Reusable capability modules
```

---

## 🤖 Agents

> Invoke with `@<agent-name>` in Copilot Chat — all agents auto-detect context, so you rarely need to specify a mode.

<details>
<summary>📋 &nbsp;<b>generate-plan</b> &nbsp;—&nbsp; Turn raw requirements into a structured <code>plan.md</code></summary>
<br/>

**What it does:** Creates or refines `.docs/<feature>/plan.md` with summary, scope, acceptance criteria, and open questions. Also creates a Jira story via the `jira-ticket` skill.

**Auto-detects mode:**
- 🆕 **Create** — no `plan.md` found → generate from your raw description
- ✏️ **Refine** — `plan.md` path provided → update in place, cascade to tasks

**Trigger with:** <kbd>plan</kbd> <kbd>I need</kbd> <kbd>create feature</kbd> <kbd>refine plan</kbd> <kbd>plan is ready</kbd>

📄 [View agent →](.github/agents/generate-plan.agent.md)

</details>

<details>
<summary>🗃️ &nbsp;<b>generate-task</b> &nbsp;—&nbsp; Break a <code>plan.md</code> into vertical-slice <code>task-NNN.md</code> files</summary>
<br/>

**What it does:** Generates independently-testable task slices from a ready plan. Each `task-NNN.md` has a file checklist, code guidance, test requirements, and Done When criteria.

**Auto-detects mode:**
- 🆕 **Generate** — no task files → slice the plan
- ✏️ **Refine** — `task-NNN.md` path provided → apply corrections

**Trigger with:** <kbd>generate tasks</kbd> <kbd>break down plan</kbd> <kbd>update task</kbd> <kbd>adjust slice</kbd>

📄 [View agent →](.github/agents/generate-task.agent.md)

</details>

<details>
<summary>⚡ &nbsp;<b>execute-task</b> &nbsp;—&nbsp; Implement a <code>task-NNN.md</code> end-to-end</summary>
<br/>

**What it does:** Reads the task slice, checks prerequisites, explores the codebase, writes production code + tests, marks all checkboxes `[x]`, syncs sibling tasks, and logs a Jira sub-task.

**Trigger with:** <kbd>execute task</kbd> <kbd>implement</kbd> <kbd>code this</kbd> <kbd>build this</kbd> <kbd>do the work</kbd>

📄 [View agent →](.github/agents/execute-task.agent.md)

</details>

<details>
<summary>🔧 &nbsp;<b>fix-task</b> &nbsp;—&nbsp; Apply post-implementation fixes and maintain <code>fix.md</code></summary>
<br/>

**What it does:** Ingests review comments, bug reports, or failing tests → creates/updates `fix.md` with numbered fix items (FIX-001, FIX-002, …) → applies minimal targeted changes → updates task and plan docs.

**Trigger with:** <kbd>fix</kbd> <kbd>bug</kbd> <kbd>review comment</kbd> <kbd>regression</kbd> <kbd>failing test</kbd> <kbd>hotfix</kbd>

📄 [View agent →](.github/agents/fix-task.agent.md)

</details>

<details>
<summary>🔍 &nbsp;<b>investigate</b> &nbsp;—&nbsp; Root-cause analysis and ad-hoc debugging</summary>
<br/>

**What it does:** Parses What / When / Where / Impact → traces through code and logs → produces a root-cause summary, evidence list, and a Mermaid flowchart showing the failure path.

**Trigger with:** <kbd>investigate</kbd> <kbd>why is</kbd> <kbd>root cause</kbd> <kbd>debug</kbd> <kbd>what happened</kbd> <kbd>deep dive</kbd>

📄 [View agent →](.github/agents/investigate.agent.md)

</details>

<details>
<summary>🦊 &nbsp;<b>gitlab-mr</b> &nbsp;—&nbsp; Review, summarise, or fix comments on a GitLab MR</summary>
<br/>

**What it does:** Reads a GitLab MR diff, summarises changes, highlights risks, and can apply fix-review-comment patches directly to source files.

**Trigger with:** <kbd>review MR</kbd> <kbd>fix comment</kbd> <kbd>show diff</kbd> <kbd>code review</kbd> or paste an MR URL

📄 [View agent →](.github/agents/gitlab-mr.agent.md)

</details>

<details>
<summary>📸 &nbsp;<b>snapshot-sync</b> &nbsp;—&nbsp; Create or refresh <code>SNAPSHOT.md</code> for any repo</summary>
<br/>

**What it does:** Scans a repo for purpose, tech stack, key commands, and source structure → writes or updates a terse `SNAPSHOT.md` that agents read first to orient themselves.

**Trigger with:** <kbd>snapshot</kbd> <kbd>update snapshot</kbd> <kbd>missing snapshot</kbd> <kbd>regenerate snapshot</kbd>

📄 [View agent →](.github/agents/snapshot-sync.agent.md)

</details>

---

## 🧠 Skills

> Loaded on demand by agents — or invoke directly when the domain applies.

| 🎨 Skill | 💡 Purpose |
|---|---|
| [`figma-design-context`](.github/skills/figma-design-context/SKILL.md) | Fetch layout, spacing, typography & screenshots from Figma via REST API (no MCP needed) |
| [`jira-ticket`](.github/skills/jira-ticket/SKILL.md) | Create stories, sub-tasks, and update story points via Jira REST API |

---

## 📋 Instructions

> Automatically applied to every Copilot interaction — no invocation needed.

| 📄 File | 🔍 Scope |
|---|---|
| [`guidelines.instructions.md`](.github/instructions/guidelines.instructions.md) | Core engineering principles — grounding, anti-hallucination, SOLID, quality gates |

---

## 🔄 Workflow

> Full pipeline details in [`.docs-workflow-README.md`](.docs-workflow-README.md)

```
╔══════════════════════════════════════════════════════════╗
║              🚀  REQUIREMENTS TO CODE PIPELINE           ║
╠══════════════════════════════════════════════════════════╣
║                                                          ║
║  📝 Raw Requirement                                      ║
║         │                                                ║
║         ▼                                                ║
║  📋 @generate-plan    →  plan.md  (re-run to refine)    ║
║         │                                                ║
║         ▼                                                ║
║  🗃️  @generate-task   →  task-NNN.md  (re-run to refine)║
║         │                                                ║
║         ▼                                                ║
║  ⚡ @execute-task     →  production code + tests ✅      ║
║         │                                                ║
║         ▼                                                ║
║  🔧 @fix-task         →  fix.md  (post-impl fixes)      ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
```

---

## ✅ Prerequisites

| Requirement | Details |
|---|---|
| 🖥️ **VS Code** | With [GitHub Copilot](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot) extension |
| 🔑 **Jira auth** | `JIRA_TOKEN`, `JIRA_EMAIL`, `JIRA_BASE_URL`, `JIRA_PROJECT_KEY` in `~/.zshenv` |
| 🎨 **Figma auth** | `FIGMA_TOKEN` in `~/.zshenv` *(only if using Figma skill without MCP)* |

### Credential Setup

All required env vars are listed in [`.env.example`](.env.example). Copy them into `~/.zshenv`:

```bash
# 1. Open .env.example, fill in your real values
# 2. Append to ~/.zshenv
cat .env.example >> ~/.zshenv   # then edit with actual values

# 3. Reload shell
source ~/.zshenv
```

> ⚠️ Never commit real tokens — `.env.example` contains only placeholders.

---

<div align="center">

*Built with 💙 for engineers who ship fast and sleep well.*

</div>
