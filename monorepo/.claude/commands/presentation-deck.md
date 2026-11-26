---
description: "Turns a work folder's artefacts (plan.md, spike.md, spike-report.md, investigation reports) into a public, audience-ready presentation.md for tech + non-tech audiences using first-principles thinking — Title, Description, Problem Statement, Hypotheses + Evidence + Research, 2-3 shortlisted solutions with end-to-end flowcharts, story points, blockers and trade-offs, Recommendation, Decisions, References — numbered sections with a clickable contents menu. Triggers: present, presentation, slides, deck, share, discussion doc, walk the team through, brief PM, pitch the spike, present the spike, prepare a talk."
tools: [read, search, edit, execute, todo]
argument-hint: "DOCS_DIR or a file in it (e.g. .docs/GOBIZWKST2-324-my-feature/spike.md) + optional audience and meeting goal."
---

**Input**: `DOCS_DIR` (or any artefact path in it) + audience / meeting goal → **Output**: `<DOCS_DIR>/presentation.md`

Load **feature-flow** (stage 4 Present), **docs-folder**, then **presentation-deck** skill — follow Phases 1–4 end to end. The skill owns the first-principles method, fixed section structure, visuals, anchors and self-check.

## Orchestrator responsibilities

- CALL: DOCS_FOLDER(REQUEST, PATH=<given path>) → DOCS_DIR, JIRA_KEY
- Map the request onto skill Phase 1 (audience, meeting goal, ask, key message); ask at most 1 clarifying question, only if the meeting goal is unknown and not inferable
- User answers to open questions in the artefacts → reflect them in the document; do not edit other artefacts unless asked (list any conflicts instead)
- RUN: `python3 .github/skills/docs-folder/scripts/validate_docs.py --folder <DOCS_DIR name>` → fix own violations
- After the skill completes → report path, options shortlisted (+ recommended), story-point totals, decisions table, and any artefact conflicts found
- CALL: SUGGEST_NEXT(Present, decisions made)

## Constraints

- Documents only: no Jira/Confluence/Slack writes
- Never invent facts — every number traces to an artefact in `DOCS_DIR` or is labelled "Estimate for discussion" with its basis
- Never include secrets, tokens, IPs, hostnames or personal data — the file is public
