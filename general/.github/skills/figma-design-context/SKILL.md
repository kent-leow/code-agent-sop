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
# 1. Outline — find the frame, don't guess
bash .github/skills/figma-design-context/scripts/get-metadata.sh --file-key <fileKey>

# 2. Targeted context — ONE node, capped depth
bash .github/skills/figma-design-context/scripts/get-design-context.sh \
  --file-key <fileKey> --node-id <nodeId> --depth 4 --output ./figma-context.json

# 3. Summarize — read this, never the raw JSON
bash .github/skills/figma-design-context/scripts/summarize-context.sh \
  --input ./figma-context.json --depth 4

# 4. Visual check — only if summary is ambiguous
bash .github/skills/figma-design-context/scripts/get-screenshot.sh \
  --file-key <fileKey> --node-id <nodeId> --scale 2 --output ./figma-screenshot.png

# 5. Reuse — map INSTANCE nodes to real components before coding new ones
bash .github/skills/figma-design-context/scripts/get-components.sh --file-key <fileKey>
```

Then implement:
1. Reuse existing project components matching Figma `INSTANCE` nodes (step 5) — never re-author a component that already exists.
2. Map fills → design tokens/CSS variables/Tailwind (see Implementation Guide).
3. Map `layoutMode`/`primaryAxisAlignItems`/`itemSpacing` → flexbox.
4. Map `paddingLeft/Right/Top/Bottom` → padding utilities; `cornerRadius` → border-radius.

## Workflow B — Understand UX Flow

No REST equivalent of a single "flow" tool exists, so combine two calls into one flow graph:

```bash
bash .github/skills/figma-design-context/scripts/get-page-full.sh \
  --file-key <fileKey> --page-id <pageId> --depth 6 --output ./figma-page.json

bash .github/skills/figma-design-context/scripts/get-flow.sh \
  --file-key <fileKey> --page-id <pageId> --output ./figma-flow.json
```

Read the `summarize-context.sh` output for `CONNECTOR ARROWS / UI FLOW` and prototype `interactions` sections — this is the sequence of screens/states, and which trigger navigates where. Use it to decide route/screen order before writing any code.

## Workflow C — Reuse Design System (tokens + components)

```bash
bash .github/skills/figma-design-context/scripts/get-variables.sh --file-key <fileKey> --output ./figma-variables.json
bash .github/skills/figma-design-context/scripts/get-styles.sh --file-key <fileKey>
bash .github/skills/figma-design-context/scripts/get-components.sh --file-key <fileKey>
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
