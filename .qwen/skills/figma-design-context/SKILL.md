---
name: figma-design-context
description: "Extract Figma design context via REST API (no MCP): layout, typography, colors, UI flow, components, variables, comments. Requires FIGMA_TOKEN in ~/.zshenv."
argument-hint: '<figma-url-or-file-key> [--node-id <nodeId>]'
---

# figma-design-context

## Prerequisites

- DO: `echo $FIGMA_TOKEN` — if empty, see [Credential Setup](#credential-setup)

## URL Parsing

`https://www.figma.com/design/AbCdEfGhIj/My-Project?node-id=2313-102848`
- `fileKey` = `AbCdEfGhIj` (segment after `/design/`)
- `nodeId` = `2313:102848` (query param `node-id`, convert `-` → `:`)

---

## Standard Workflow — Implement a UI Frame

- DO: Discover pages & frames
```bash
bash .github/skills/figma-design-context/scripts/get-metadata.sh --file-key <fileKey>
```

- DO: Screenshot (visual reference)
```bash
bash .github/skills/figma-design-context/scripts/get-screenshot.sh \
  --file-key <fileKey> --node-id <nodeId> --scale 2 --output ./figma-screenshot.png
```
Then `view_image ./figma-screenshot.png`. Auto-resizes to 8000px limit. Oversized → fetch child nodes with tighter `--node-id`.

- DO: Full design spec
```bash
bash .github/skills/figma-design-context/scripts/get-design-context.sh \
  --file-key <fileKey> --node-id <nodeId> --output ./figma-context.json
```
Flags: `--depth N` (3-5 for large frames), `--geometry` (vector path data)

- DO: Summarise spec
```bash
bash .github/skills/figma-design-context/scripts/summarize-context.sh \
  --input ./figma-context.json [--depth 5]
```

- DO: Implement UI
  - Find existing project components matching Figma INSTANCE nodes — reuse over creating new
  - Map fills → design tokens/CSS variables/Tailwind classes
  - Map `layoutMode`/`primaryAxisAlignItems`/`counterAxisAlignItems`/`itemSpacing` → flexbox
  - Map `paddingLeft/Right/Top/Bottom` → padding utilities
  - Map `cornerRadius` → `rounded-N` or `border-radius`

---

## UI Flow Workflow — Screen Transitions

- DO: Full page tree (element inventory)
```bash
bash .github/skills/figma-design-context/scripts/get-page-full.sh \
  --file-key <fileKey> --page-id <pageId> [--depth 10] --output ./figma-page.json
```
Run `get-metadata.sh` first to find `pageId`.

- DO: Extract flow graph
```bash
bash .github/skills/figma-design-context/scripts/get-flow.sh \
  --file-key <fileKey> [--page-id <pageId>] [--depth 6] --output ./figma-flow.json
```
Extracts CONNECTOR nodes (flow arrows) + prototype interactions (trigger → action → destination).

---

## Design System Workflows

- DO: Components & variants
```bash
bash .github/skills/figma-design-context/scripts/get-components.sh \
  --file-key <fileKey> --output ./figma-components.json
```

- DO: Shared styles (colours, text, effects, grids)
```bash
bash .github/skills/figma-design-context/scripts/get-styles.sh --file-key <fileKey>
```

- DO: Design variables / tokens
```bash
bash .github/skills/figma-design-context/scripts/get-variables.sh \
  --file-key <fileKey> [--include-published] --output ./figma-variables.json
```
Falls back gracefully if plan doesn't support Variables API.

- DO: Designer comments & annotations
```bash
bash .github/skills/figma-design-context/scripts/get-comments.sh \
  --file-key <fileKey> --output ./figma-comments.json
```

---

## API Reference

| Script | Endpoint | Purpose |
|---|---|---|
| `get-metadata.sh` | `GET /v1/files/{key}?depth=N` | Pages, frames, last-modified |
| `get-screenshot.sh` | `GET /v1/images/{key}?ids=...&format=png` | Rendered PNG of any node |
| `get-design-context.sh` | `GET /v1/files/{key}/nodes?ids=...` | Full node subtree |
| `get-page-full.sh` | `GET /v1/files/{key}/nodes?ids=<pageId>&depth=N` | Complete page tree |
| `get-flow.sh` | `GET /v1/files/{key}?depth=N` | CONNECTORs + prototype interactions |
| `get-components.sh` | `GET /v1/files/{key}/components` + `/component_sets` | Components and variants |
| `get-styles.sh` | `GET /v1/files/{key}/styles` | Shared styles |
| `get-variables.sh` | `GET /v1/files/{key}/variables/local` (+ `/published`) | Design tokens |
| `get-comments.sh` | `GET /v1/files/{key}/comments` | Annotations and threads |

### Other Figma REST APIs (not scripted)

| Endpoint | Purpose |
|---|---|
| `GET /v1/files/{key}/versions` | Version history |
| `GET /v1/me` | Token owner info |
| `GET /v1/teams/{teamId}/projects` | List team projects |
| `GET /v1/projects/{projectId}/files` | List files in a project |
| `GET /v1/teams/{teamId}/components` | Team component library |
| `GET /v1/teams/{teamId}/styles` | Team style library |
| `POST /v1/files/{key}/comments` | Post a comment |

---

## Credential Setup

1. Go to https://www.figma.com/settings → Personal access tokens → Create new token
2. Add to `~/.zshenv`: `export FIGMA_TOKEN="your-token-here"`
3. `source ~/.zshenv && echo $FIGMA_TOKEN`

---

## Errors

| Error | Cause | Fix |
|---|---|---|
| `FIGMA_TOKEN environment variable is required` | Var not exported | Add to `~/.zshenv` and source |
| `403` | Invalid/expired token | Regenerate at figma.com/settings |
| `404` | Wrong `fileKey` | Re-check URL segment after `/design/` |
| Empty `images` in screenshot response | Node ID not found | Run `get-metadata.sh` to confirm |
| Image dimensions exceed 8000px | Too large | Script auto-resizes; or pass `--scale 1` |
| Variables API returns 403/404 | Plan doesn't support Variables | Use `get-styles.sh` instead |
| No CONNECTOR nodes in flow output | Flow arrows not used | Check prototype interactions; try higher `--depth` |
