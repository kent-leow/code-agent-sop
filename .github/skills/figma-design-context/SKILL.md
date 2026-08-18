---
name: figma-design-context
description: "Extract minimal, meaningful Figma design context (layout, tokens, components, UX flow) via REST API, structured to mirror the official Figma Dev Mode MCP Server's tool contract. Use when MCP servers are unavailable/disallowed (e.g. enterprise policy). Requires FIGMA_TOKEN in ~/.zshenv."
argument-hint: '<figma-url-or-file-key> [--node-id <nodeId>]'
---

# figma-design-context

REST-API implementation of the same context contract the official **Figma Dev Mode MCP Server** exposes (`get_metadata`, `get_design_context`, `get_variable_defs`, `get_screenshot`, `get_code_connect_map`). Use wherever the MCP server can't be connected — it returns the same *shape* of signal at the same low token cost, not raw file dumps.

## Core principle: minimum context, maximum signal

Never fetch or read a whole Figma file. Escalate one step at a time and **stop as soon as you can act**:

| Step | Mirrors MCP tool | Do this, not more |
|---|---|---|
| 1. Outline | `get_metadata` | Sparse ids/names/types only. Identify the ONE frame/node you need. |
| 2. Targeted context | `get_design_context` | Full spec for that node only. Cap with `--depth`. |
| 3. Tokens | `get_variable_defs` | Only variables/styles that node actually uses. |
| 4. Visual check | `get_screenshot` | Only if the summarized spec leaves layout ambiguous. |
| 5. Reuse | `get_code_connect_map` (approx.) | Map `INSTANCE` nodes → existing project components before writing new markup. |

Always pipe raw JSON through `summarize-context.sh` — never read a `figma-context.json` file directly; it is 10-100x more tokens than the summary.

## Fidelity Contract — zero discrepancy (mandatory)

The goal is to build **exactly** what is in the Figma file — same layout, same spacing, same colours, same copy, same component hierarchy. Not an "improved" version, not a best-guess, not a stylistic reinterpretation.

- **Build from the `NODE TREE` section** of `context.summary.md` (produced by `summarize-context.sh`), not the aggregated sections below it (`NODE TYPES`, `TYPOGRAPHY`, `COLOURS`, `AUTO-LAYOUT`, `COMPONENT INSTANCES`). The tree preserves per-node parent/child structure and each node's own exact properties in document order; the aggregated sections are deduplicated/flattened and lose that structure — use them only as a cross-check, never as the primary spec.
- **Never invent, add, remove, reorder, or "improve" anything** not present in the tree — no extra elements, no rewritten copy, no different spacing/colours/radii "because it looks better", no rounding of numeric values (use the exact px/hex/opacity values printed).
- **If a value is ambiguous or missing** from the tree (e.g. truncated text sample, unclear nesting), read the raw `context.json` for that specific node — do not guess or fall back to a plausible-looking default.
- **Screenshot is a visual sanity check only** — the JSON/tree values are ground truth. If the screenshot and the tree ever appear to disagree, trust the tree/JSON and re-fetch/re-check rather than eyeballing the image.
- **Before marking a UI task complete**, diff your implementation against the tree node-by-node (dimensions, fills, padding, gap, corner-radius, font, text content) — not just an overall glance.

## Caching Convention (mandatory)

Every fetch from Figma MUST be saved to a deterministic, reusable path. Never fetch the same fileKey+nodeId twice in one task, and never let a downstream agent (generate-task, execute-task, fix-task) re-derive design facts from memory — they read the cached file instead. This is the single biggest lever against hallucination: the cache is the source of truth, not the model's recollection of it.

**Cache root**: `<task-folder>/figma/` where `<task-folder>` is the same `.docs/<kebab-folder>/` used for `plan.md`/`task-NNN.md`. `fix-task` reuses this same cache root (never creates its own) so it verifies against the exact spec the original implementation was built from.

**Layout**:

```
<task-folder>/figma/
└── <fileKey>/
    ├── metadata.txt           # get-metadata.sh (stdout redirect — no --output flag)
    ├── variables.json          # get-variables.sh
    ├── styles.txt              # get-styles.sh (stdout redirect — no --output flag)
    ├── components.json         # get-components.sh
    ├── <nodeId>/
    │   ├── context.json        # get-design-context.sh (raw)
    │   ├── context.summary.md  # summarize-context.sh output (piped, not regenerated)
    │   └── screenshot.png      # get-screenshot.sh
    └── <pageId>/
        ├── page.json            # get-page-full.sh
        └── flow.json            # get-flow.sh
```

**Rule — check cache before every fetch**:

```bash
CACHE_DIR="<task-folder>/figma/<fileKey>"; mkdir -p "$CACHE_DIR/<nodeId>"

[[ -f "$CACHE_DIR/<nodeId>/context.json" ]] || \
  bash .github/skills/figma-design-context/scripts/get-design-context.sh \
    --file-key <fileKey> --node-id <nodeId> --depth 4 --output "$CACHE_DIR/<nodeId>/context.json"
```

Only re-fetch when the user explicitly asks for a refresh, or the cached file is missing/empty — otherwise read the cached file directly. This also keeps every call under the rate limit (~30 req/min).

## Prerequisites

```bash
echo $FIGMA_TOKEN  # If empty, see Credential Setup below
```

## URL Parsing

`https://www.figma.com/design/AbCdEfGhIj/My-Project?node-id=2313-102848`
- `fileKey` = `AbCdEfGhIj` (segment after `/design/`)
- `nodeId` = `2313:102848` (query param, convert `-` → `:`)

---

## Workflow A — Implement a UI Frame

```bash
CACHE="<task-folder>/figma/<fileKey>"; mkdir -p "$CACHE/<nodeId>"

# 1. Outline — find the frame, don't guess (skip if cached)
[[ -f "$CACHE/metadata.txt" ]] || \
  bash .github/skills/figma-design-context/scripts/get-metadata.sh --file-key <fileKey> > "$CACHE/metadata.txt"

# 2. Targeted context — ONE node, capped depth (skip if cached)
[[ -f "$CACHE/<nodeId>/context.json" ]] || \
  bash .github/skills/figma-design-context/scripts/get-design-context.sh \
    --file-key <fileKey> --node-id <nodeId> --depth 4 --output "$CACHE/<nodeId>/context.json"

# 3. Summarize — cache the summary too; read this, never the raw JSON.
#    Output has a NODE TREE section (exact per-node structure — build from this)
#    followed by aggregated cross-check sections (colours/typography/etc).
[[ -f "$CACHE/<nodeId>/context.summary.md" ]] || \
  bash .github/skills/figma-design-context/scripts/summarize-context.sh \
    --input "$CACHE/<nodeId>/context.json" --depth 4 > "$CACHE/<nodeId>/context.summary.md"

# 4. Visual check — only if summary is ambiguous (skip if cached)
[[ -f "$CACHE/<nodeId>/screenshot.png" ]] || \
  bash .github/skills/figma-design-context/scripts/get-screenshot.sh \
    --file-key <fileKey> --node-id <nodeId> --scale 2 --output "$CACHE/<nodeId>/screenshot.png"

# 5. Reuse — map INSTANCE nodes to real components before coding new ones (skip if cached)
[[ -f "$CACHE/components.json" ]] || \
  bash .github/skills/figma-design-context/scripts/get-components.sh --file-key <fileKey> --output "$CACHE/components.json"
```

Then implement:
1. Reuse existing project components matching Figma `INSTANCE` nodes (step 5) — never re-author a component that already exists.
2. Map fills → design tokens/CSS variables/Tailwind (see Implementation Guide).
3. Map `layoutMode`/`primaryAxisAlignItems`/`itemSpacing` → flexbox.
4. Map `paddingLeft/Right/Top/Bottom` → padding utilities; `cornerRadius` → border-radius.

## Workflow B — Understand UX Flow

No REST equivalent of a single "flow" tool exists, so combine two calls into one flow graph:

```bash
CACHE="<task-folder>/figma/<fileKey>/<pageId>"; mkdir -p "$CACHE"

[[ -f "$CACHE/page.json" ]] || \
  bash .github/skills/figma-design-context/scripts/get-page-full.sh \
    --file-key <fileKey> --page-id <pageId> --depth 6 --output "$CACHE/page.json"

[[ -f "$CACHE/flow.json" ]] || \
  bash .github/skills/figma-design-context/scripts/get-flow.sh \
    --file-key <fileKey> --page-id <pageId> --output "$CACHE/flow.json"
```

Read the `summarize-context.sh` output for `CONNECTOR ARROWS / UI FLOW` and prototype `interactions` sections — this is the sequence of screens/states, and which trigger navigates where. Use it to decide route/screen order before writing any code.

## Workflow C — Reuse Design System (tokens + components)

```bash
CACHE="<task-folder>/figma/<fileKey>"; mkdir -p "$CACHE"

[[ -f "$CACHE/variables.json" ]] || \
  bash .github/skills/figma-design-context/scripts/get-variables.sh --file-key <fileKey> --output "$CACHE/variables.json"
[[ -f "$CACHE/styles.txt" ]] || \
  bash .github/skills/figma-design-context/scripts/get-styles.sh --file-key <fileKey> > "$CACHE/styles.txt"
[[ -f "$CACHE/components.json" ]] || \
  bash .github/skills/figma-design-context/scripts/get-components.sh --file-key <fileKey> --output "$CACHE/components.json"
```

If Variables API returns 403/404 (plan doesn't support it), fall back to `get-styles.sh`.

---

## Script Reference (MCP tool parity)

| Official MCP tool | Script(s) | Purpose |
|---|---|---|
| `get_metadata` | `get-metadata.sh` | Sparse outline: pages, frames, ids, types |
| `get_design_context` | `get-design-context.sh` → `summarize-context.sh` | Layout, typography, colour, spacing for one node |
| `get_variable_defs` | `get-variables.sh`, `get-styles.sh` | Design tokens actually used |
| `get_screenshot` | `get-screenshot.sh` | Visual fidelity reference (PNG) |
| `download_assets` | `export-assets.sh`, `get-image-fills.sh` | Deliver/export assets (svg/jpg/pdf, raw source images) |
| `get_code_connect_map` (approx.) | `get-components.sh`, `get-team-components.sh` | Map `INSTANCE` nodes → reusable components |
| `search_design_system` (approx.) | `get-team-components.sh`, `get-team-styles.sh`, `get-team-projects.sh`, `get-project-files.sh` | Find reusable library assets across the team |
| UX flow (no direct MCP tool) | `get-page-full.sh`, `get-flow.sh` | Prototype interactions + connector arrows |
| — | `get-comments.sh`, `post-comment.sh` | Read/write design annotations |
| — | `get-versions.sh`, `whoami.sh` | File history, current user |

Flags worth knowing: `--depth N` (3-5 for large frames, caps token size), `--geometry` (vector paths, only when recreating custom icons/illustrations).

---

## Implementation Guide

### Figma → CSS/Tailwind

| Figma Property | CSS/Tailwind Equivalent |
|----------------|------------------------|
| `layoutMode: "VERTICAL"` | `flex flex-col` |
| `layoutMode: "HORIZONTAL"` | `flex flex-row` |
| `primaryAxisAlignItems: "CENTER"` | `justify-center` |
| `counterAxisAlignItems: "CENTER"` | `items-center` |
| `itemSpacing: 16` | `gap-4` |
| `paddingLeft/Right/Top/Bottom` | `p-*`, `px-*`, `py-*` |
| `cornerRadius: 8` | `rounded-lg` |
| `fills[0].color` | `bg-*` or CSS variable |
| `strokes[0].color` | `border-*` |
| `opacity: 0.5` | `opacity-50` |

`primaryAxisAlignItems`: `MIN→justify-start` `CENTER→justify-center` `MAX→justify-end` `SPACE_BETWEEN→justify-between`
`counterAxisAlignItems`: `MIN→items-start` `CENTER→items-center` `MAX→items-end` `BASELINE→items-baseline`

### Colour conversion (Figma 0–1 range → CSS hex)

```javascript
const toHex = ({r, g, b}) => '#' + [r, g, b]
  .map(v => Math.round(v * 255).toString(16).padStart(2, '0'))
  .join('');
```

---

## Credential Setup

1. https://www.figma.com/settings → Personal access tokens → Create new token (scope: `file_read`, add `file_write` only if posting comments).
2. Add to `~/.zshenv`: `export FIGMA_TOKEN="your-token-here"`, then `source ~/.zshenv`.

---

## Errors & Rate Limits

| Error | Cause | Fix |
|---|---|---|
| `FIGMA_TOKEN environment variable is required` | Var not exported | Add to `~/.zshenv` and source |
| `403 Forbidden` | Invalid/expired token, or plan lacks Variables API | Regenerate token; fall back to `get-styles.sh` |
| `404 Not Found` | Wrong fileKey/nodeId | Re-check URL segments, or run `get-metadata.sh` |
| Image dimensions exceed 8000px | Node too large | Use `--scale 1` or fetch child nodes |
| `429 Too Many Requests` | Rate limited (~30 req/min, ~10 req/min for images) | Batch node IDs per request; cache locally; retry with backoff |

## Limitations (REST vs Plugin API)

Read-only + comments only. Creating/modifying canvas nodes, binding variables, or generating diagrams requires the Plugin API / MCP `use_figma` tool — not available here.
