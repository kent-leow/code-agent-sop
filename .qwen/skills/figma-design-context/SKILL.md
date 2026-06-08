---
name: figma-design-context
description: "Extract Figma design context via REST API (no MCP): layout, typography, colors, UI flow, components, variables, comments. Requires FIGMA_TOKEN in ~/.zshenv."
argument-hint: '<figma-url-or-file-key> [--node-id <nodeId>]'
---

# figma-design-context

Replaces Figma MCP tools (`get_metadata`, `get_screenshot`, `get_design_context`) using Figma REST API directly.

## Prerequisites

Check: `echo $FIGMA_TOKEN` — if empty, see [Credential Setup](#credential-setup).

## URL Parsing

`https://www.figma.com/design/AbCdEfGhIj/My-Project?node-id=2313-102848`
- `fileKey` = `AbCdEfGhIj` (segment after `/design/`)
- `nodeId`  = `2313:102848` (query param `node-id`, converting `-` → `:`)

All scripts accept both formats (`2313-102848` or `2313:102848`).

---

## Standard Workflow — Implement a UI Frame

### Step 1 — Discover Pages & Frames
```bash
bash .github/skills/figma-design-context/scripts/get-metadata.sh --file-key <fileKey>
```
Lists pages, top-level frames with node IDs and dimensions. Also flags pages that contain flow signals (connectors / prototype interactions).

### Step 2 — Screenshot (visual reference)
```bash
bash .github/skills/figma-design-context/scripts/get-screenshot.sh \
  --file-key <fileKey> --node-id <nodeId> --scale 2 --output ./figma-screenshot.png
```
Then `view_image ./figma-screenshot.png`. Script auto-resizes to fit Claude's 8000px limit via `sips`. For oversized frames: fetch child nodes with a tighter `--node-id` instead.

### Step 3 — Full Design Spec
```bash
bash .github/skills/figma-design-context/scripts/get-design-context.sh \
  --file-key <fileKey> --node-id <nodeId> --output ./figma-context.json
```
Optional flags:
- `--depth N` — limit tree depth (use 3-5 for very large frames to reduce response size)
- `--geometry` — include vector path data (bezier points) for custom shapes/icons

### Step 4 — Summarise Spec
```bash
bash .github/skills/figma-design-context/scripts/summarize-context.sh \
  --input ./figma-context.json [--depth 5]
```
Prints: frame dimensions, node-type breakdown, **CONNECTOR arrows**, **prototype interactions**, typography, fill colours, stroke colours, auto-layout (flexbox), component instances.

### Step 5 — Implement UI
1. Find existing project components matching Figma INSTANCE nodes — reuse over creating new.
2. Map Figma fills → project design tokens/CSS variables/Tailwind classes.
3. Map `layoutMode`/`primaryAxisAlignItems`/`counterAxisAlignItems`/`itemSpacing` → flexbox.
4. Map `paddingLeft/Right/Top/Bottom` → padding utilities.
5. Map `cornerRadius` → `rounded-N` or `border-radius`.

---

## UI Flow Workflow — Understand Screen Transitions

Use this when you need to understand navigation between screens (arrows, taps, prototypes).

### Step A — Full Page Tree (element inventory)
```bash
bash .github/skills/figma-design-context/scripts/get-page-full.sh \
  --file-key <fileKey> --page-id <pageId> [--depth 10] --output ./figma-page.json
```
Shows all top-level frames, node-type distribution, counts of CONNECTOR nodes and prototype interactions. Run `get-metadata.sh` first to find `pageId`.

### Step B — Extract Flow Graph
```bash
bash .github/skills/figma-design-context/scripts/get-flow.sh \
  --file-key <fileKey> [--page-id <pageId>] [--depth 6] --output ./figma-flow.json
```
Extracts two categories:
- **CONNECTOR nodes** — flow arrows drawn on the canvas (connectorStart → connectorEnd, with labels)
- **Prototype interactions** — `interactions[]` on nodes (trigger type → action type → destination frame)

Output is human-readable and also saved as JSON for further processing.

---

## Design System Workflows

### Components & Variants
```bash
bash .github/skills/figma-design-context/scripts/get-components.sh \
  --file-key <fileKey> --output ./figma-components.json
```
Lists all published components and component sets (variant groups). Use this to match Figma INSTANCE node names to design system component names before implementing.

### Shared Styles (colours, text, effects, grids)
```bash
bash .github/skills/figma-design-context/scripts/get-styles.sh --file-key <fileKey>
```
Returns all file-level shared styles grouped by type. Useful for files that don't use the Variables API.

### Design Variables / Tokens
```bash
bash .github/skills/figma-design-context/scripts/get-variables.sh \
  --file-key <fileKey> [--include-published] --output ./figma-variables.json
```
Fetches local Figma Variables (design tokens): colors, spacing, radii, typography scales, etc. grouped by collection and mode (e.g. light/dark). Falls back gracefully if the plan level doesn't support the Variables API.

### Designer Comments & Annotations
```bash
bash .github/skills/figma-design-context/scripts/get-comments.sh \
  --file-key <fileKey> --output ./figma-comments.json
```
Fetches all design comments threaded by conversation. Comments are anchored to specific nodes — use `@node:<id>` references to correlate with design elements.

---

## API Reference

| Script | Figma API Endpoint | Purpose |
|---|---|---|
| `get-metadata.sh` | `GET /v1/files/{key}?depth=N` | Pages, frames, last-modified |
| `get-screenshot.sh` | `GET /v1/images/{key}?ids=...&format=png` | Rendered PNG of any node |
| `get-design-context.sh` | `GET /v1/files/{key}/nodes?ids=...` | Full node subtree (layout, fills, text, interactions) |
| `get-page-full.sh` | `GET /v1/files/{key}/nodes?ids=<pageId>&depth=N` | Complete page tree with element counts |
| `get-flow.sh` | `GET /v1/files/{key}?depth=N` | CONNECTOR arrows + prototype interaction graph |
| `get-components.sh` | `GET /v1/files/{key}/components` + `/component_sets` | Published components and variant groups |
| `get-styles.sh` | `GET /v1/files/{key}/styles` | Shared colour/text/effect/grid styles |
| `get-variables.sh` | `GET /v1/files/{key}/variables/local` (+ `/published`) | Design tokens (Figma Variables API) |
| `get-comments.sh` | `GET /v1/files/{key}/comments` | Design annotations and review threads |

### Other Figma REST APIs (not yet scripted)
| Endpoint | Purpose |
|---|---|
| `GET /v1/files/{key}/versions` | Version history |
| `GET /v1/me` | Token owner info |
| `GET /v1/teams/{teamId}/projects` | List team projects |
| `GET /v1/projects/{projectId}/files` | List files in a project |
| `GET /v1/teams/{teamId}/components` | Team-published component library |
| `GET /v1/teams/{teamId}/styles` | Team-published style library |
| `POST /v1/files/{key}/comments` | Post a comment |

---

## Credential Setup

1. Go to https://www.figma.com/settings → Personal access tokens → Create new token.
2. Add to `~/.zshenv`: `export FIGMA_TOKEN="your-token-here"`
3. `source ~/.zshenv && echo $FIGMA_TOKEN`

---

## Errors

| Error | Cause | Fix |
|---|---|---|
| `FIGMA_TOKEN environment variable is required` | Var not exported | Add to `~/.zshenv` and source |
| `403` | Invalid/expired token | Regenerate at figma.com/settings |
| `404` | Wrong `fileKey` | Re-check URL — segment after `/design/` |
| Empty `images` in screenshot response | Node ID not found | Run `get-metadata.sh` to confirm |
| `err: Not found` in context JSON | Node ID missing in file | Confirm with `get-metadata.sh` |
| Image dimensions exceed 8000px | Too large | Script auto-resizes; or pass `--scale 1` |
| Variables API returns 403/404 | Plan doesn't support Variables | Use `get-styles.sh` instead |
| No CONNECTOR nodes in flow output | Flow arrows not used in this file | Check prototype interactions; try higher `--depth` |
