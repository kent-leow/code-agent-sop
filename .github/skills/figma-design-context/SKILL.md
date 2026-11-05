---
name: figma-design-context
description: "Extract minimal, meaningful Figma design context (layout, tokens, components, UX flow) via REST API, structured to mirror the official Figma Dev Mode MCP Server's tool contract. Use when MCP servers are unavailable/disallowed (e.g. enterprise policy). Requires FIGMA_TOKEN in ~/.zshenv."
argument-hint: '<figma-url-or-file-key> [--node-id <nodeId>]'
---

# figma-design-context

REST implementation of the Figma Dev Mode MCP contract (`get_metadata`, `get_design_context`, `get_variable_defs`, `get_screenshot`, `get_code_connect_map`) at the same low token cost.

`S=.github/skills/figma-design-context/scripts` — every script sources `_http.sh`: `FIGMA_TOKEN` guard, token via curl config (never argv), 10s connect / 120s timeout, reads retry 429/5xx with backoff (honours `Retry-After`), `post-comment.sh` never retried, pre-signed image URLs downloaded without the token.

## Core principle: minimum context, maximum signal

Never fetch or read a whole file. Escalate one step at a time; **stop as soon as you can act**:

| Step | MCP tool | Do this, not more |
|---|---|---|
| 1. Outline | `get_metadata` | ids/names/types only → pick the ONE node needed |
| 2. Targeted context | `get_design_context` | that node only, `--depth 3-5` |
| 3. Tokens | `get_variable_defs` | only variables/styles the node uses |
| 4. Visual check | `get_screenshot` | only if the summary leaves layout ambiguous |
| 5. Reuse | `get_code_connect_map` (approx.) | map `INSTANCE` nodes → existing project components |

Read `context.summary.md` (from `summarize-context.sh`), never raw `context.json` (10-100× tokens) — except to resolve one ambiguous node.

## Fidelity Contract — zero discrepancy (mandatory)

- Build from the **`NODE TREE`** section (per-node, document order). Aggregated sections (`NODE TYPES`, `TYPOGRAPHY`, `COLOURS`, `AUTO-LAYOUT`, `COMPONENT INSTANCES`) are cross-checks only.
- Never invent, add, remove, reorder, round, or "improve" anything — exact px/hex/opacity/copy.
- Ambiguous/missing value → read raw `context.json` for that node; never guess a default.
- Screenshot = sanity check; tree/JSON wins on conflict.
- Before marking UI done: diff implementation vs tree node-by-node (size, fills, padding, gap, radius, font, text).

## Caching Convention (mandatory)

Cache root `<DOCS_DIR>/figma/<fileKey>/` (`DOCS_DIR` = ticket folder from docs-folder skill). Downstream agents (generate-task, execute-task, fix-task) read the cache, never memory; `fix-task` reuses the same root.

```
<DOCS_DIR>/figma/<fileKey>/
├── metadata.txt  variables.json  styles.txt  components.json
├── <nodeId>/  context.json  context.summary.md  screenshot.png
└── <pageId>/  page.json  flow.json
```

Fetch only if the target file is missing/empty or the user asks to refresh — this also keeps under the rate limit (~30 req/min; images ~10/min).

## URL Parsing

`https://www.figma.com/design/<fileKey>/<name>?node-id=2313-102848` → `fileKey` = segment after `/design/`; `nodeId` = `2313:102848` (`-` → `:`; scripts accept both).

## Workflow A — Implement a UI Frame

```bash
C="<DOCS_DIR>/figma/<fileKey>"; N="$C/<nodeId>"; mkdir -p "$N"
[[ -s $C/metadata.txt ]]       || bash $S/get-metadata.sh --file-key <fileKey> > $C/metadata.txt                                   # 1
[[ -s $N/context.json ]]       || bash $S/get-design-context.sh --file-key <fileKey> --node-id <nodeId> --depth 4 --output $N/context.json  # 2
[[ -s $N/context.summary.md ]] || bash $S/summarize-context.sh --input $N/context.json --depth 4 > $N/context.summary.md           # 2
[[ -s $N/screenshot.png ]]     || bash $S/get-screenshot.sh --file-key <fileKey> --node-id <nodeId> --scale 2 --output $N/screenshot.png  # 4 (only if ambiguous)
[[ -s $C/components.json ]]    || bash $S/get-components.sh --file-key <fileKey> --output $C/components.json                      # 5
```

Then: reuse project components matching `INSTANCE` nodes → fills → tokens/CSS vars → auto-layout → flex → padding/radius (see mapping).

## Workflow B — Understand UX Flow

```bash
P="<DOCS_DIR>/figma/<fileKey>/<pageId>"; mkdir -p "$P"
[[ -s $P/page.json ]] || bash $S/get-page-full.sh --file-key <fileKey> --page-id <pageId> --depth 6 --output $P/page.json
[[ -s $P/flow.json ]] || bash $S/get-flow.sh --file-key <fileKey> --page-id <pageId> --output $P/flow.json
```

Use `CONNECTOR ARROWS / UI FLOW` + prototype `interactions` to fix screen/route order before coding.

## Workflow C — Reuse Design System

```bash
C="<DOCS_DIR>/figma/<fileKey>"; mkdir -p "$C"
[[ -s $C/variables.json ]]  || bash $S/get-variables.sh --file-key <fileKey> --output $C/variables.json   # 403/404 → styles only
[[ -s $C/styles.txt ]]      || bash $S/get-styles.sh --file-key <fileKey> > $C/styles.txt
[[ -s $C/components.json ]] || bash $S/get-components.sh --file-key <fileKey> --output $C/components.json
```

## Script Reference

| MCP tool | Script(s) |
|---|---|
| `get_metadata` | `get-metadata.sh` |
| `get_design_context` | `get-design-context.sh [--depth N] [--geometry]` → `summarize-context.sh` |
| `get_variable_defs` | `get-variables.sh`, `get-styles.sh` |
| `get_screenshot` | `get-screenshot.sh` (auto-resizes >8000px) |
| `download_assets` | `export-assets.sh`, `get-image-fills.sh` |
| `get_code_connect_map` (approx.) | `get-components.sh`, `get-team-components.sh` |
| `search_design_system` (approx.) | `get-team-components.sh`, `get-team-styles.sh`, `get-team-projects.sh`, `get-project-files.sh` |
| UX flow | `get-page-full.sh`, `get-flow.sh` |
| annotations / misc | `get-comments.sh`, `post-comment.sh` (writes), `get-versions.sh`, `whoami.sh` |

`--geometry` only when recreating custom icons/illustrations.

## Figma → CSS/Tailwind

| Figma | CSS / Tailwind |
|---|---|
| `layoutMode` `VERTICAL` / `HORIZONTAL` | `flex flex-col` / `flex flex-row` |
| `primaryAxisAlignItems` `MIN/CENTER/MAX/SPACE_BETWEEN` | `justify-start/center/end/between` |
| `counterAxisAlignItems` `MIN/CENTER/MAX/BASELINE` | `items-start/center/end/baseline` |
| `itemSpacing` · `padding*` · `cornerRadius` | `gap-*` · `p-*`/`px-*`/`py-*` · `rounded-*` (exact px if no token) |
| `fills[0].color` · `strokes[0].color` · `opacity` | `bg-*`/CSS var · `border-*` · `opacity-*` |

Colour: Figma `r,g,b` are 0–1 → hex = `round(v*255)` per channel.

## Credential Setup

figma.com/settings → Personal access tokens → scope `file_read` (+ `file_write` only to post comments) → `export FIGMA_TOKEN=...` in `~/.zshenv` → `source ~/.zshenv`.

## Errors

| Error | Fix |
|---|---|
| `FIGMA_TOKEN is required` | export in `~/.zshenv`, source it |
| 403 | token invalid/expired, or plan lacks Variables API → `get-styles.sh` |
| 404 | wrong fileKey/nodeId → `get-metadata.sh` |
| image >8000px | `--scale 1` or a child node |
| 429 | already retried with backoff → rely on cache, batch node ids |

REST is read-only + comments: creating/editing canvas nodes needs the Plugin API / MCP `use_figma`.
