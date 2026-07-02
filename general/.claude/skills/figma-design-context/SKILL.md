---
name: figma-design-context
description: "Extract Figma design context via REST API: layout, typography, colors, UI flow, components, variables, comments, assets. Requires FIGMA_TOKEN in ~/.zshenv."
argument-hint: '<figma-url-or-file-key> [--node-id <nodeId>]'
---

# figma-design-context

Extract design context from Figma using the **REST API** with `FIGMA_TOKEN`.

---

## Prerequisites

```bash
echo $FIGMA_TOKEN  # If empty, see Credential Setup below
```

---

## URL Parsing

`https://www.figma.com/design/AbCdEfGhIj/My-Project?node-id=2313-102848`
- `fileKey` = `AbCdEfGhIj` (segment after `/design/`)
- `nodeId` = `2313:102848` (query param `node-id`, convert `-` → `:`)

URL types:
| URL Pattern | Type |
|-------------|------|
| `figma.com/design/...` | Design file |
| `figma.com/file/...` | Design file (legacy) |
| `figma.com/board/...` | FigJam |
| `figma.com/slides/...` | Slides |

---

## Standard Workflow — Implement a UI Frame

### Step 1: Discover Pages & Frames
```bash
bash .github/skills/figma-design-context/scripts/get-metadata.sh --file-key <fileKey>
```
Lists pages, top-level frames with node IDs and dimensions.

### Step 2: Screenshot (visual reference)
```bash
bash .github/skills/figma-design-context/scripts/get-screenshot.sh \
  --file-key <fileKey> --node-id <nodeId> --scale 2 --output ./figma-screenshot.png
```
Then `view_image ./figma-screenshot.png`. Auto-resizes to 8000px limit.

### Step 3: Full Design Spec
```bash
bash .github/skills/figma-design-context/scripts/get-design-context.sh \
  --file-key <fileKey> --node-id <nodeId> --output ./figma-context.json
```
Flags: `--depth N` (3-5 for large frames), `--geometry` (vector paths)

### Step 4: Summarize Spec
```bash
bash .github/skills/figma-design-context/scripts/summarize-context.sh \
  --input ./figma-context.json [--depth 5]
```
Outputs: frame dimensions, node-type breakdown, typography, colors, auto-layout, component instances.

### Step 5: Implement UI
1. Find existing project components matching Figma INSTANCE nodes — reuse over creating new
2. Map fills → design tokens/CSS variables/Tailwind classes
3. Map `layoutMode`/`primaryAxisAlignItems`/`counterAxisAlignItems`/`itemSpacing` → flexbox
4. Map `paddingLeft/Right/Top/Bottom` → padding utilities
5. Map `cornerRadius` → `rounded-*` or `border-radius`

---

## UI Flow Workflow — Screen Transitions

### Full Page Tree
```bash
bash .github/skills/figma-design-context/scripts/get-page-full.sh \
  --file-key <fileKey> --page-id <pageId> [--depth 10] --output ./figma-page.json
```
Run `get-metadata.sh` first to find `pageId`.

### Extract Flow Graph
```bash
bash .github/skills/figma-design-context/scripts/get-flow.sh \
  --file-key <fileKey> [--page-id <pageId>] [--depth 6] --output ./figma-flow.json
```
Extracts CONNECTOR nodes + prototype interactions (trigger → action → destination).

---

## Design System Workflows

### Components & Variants
```bash
bash .github/skills/figma-design-context/scripts/get-components.sh \
  --file-key <fileKey> --output ./figma-components.json
```

### Shared Styles (colors, text, effects, grids)
```bash
bash .github/skills/figma-design-context/scripts/get-styles.sh --file-key <fileKey>
```

### Design Variables / Tokens
```bash
bash .github/skills/figma-design-context/scripts/get-variables.sh \
  --file-key <fileKey> [--include-published] --output ./figma-variables.json
```
Falls back gracefully if plan doesn't support Variables API.

### Designer Comments & Annotations
```bash
bash .github/skills/figma-design-context/scripts/get-comments.sh \
  --file-key <fileKey> --output ./figma-comments.json
```

---

## Asset Export Workflows

### Export Images (PNG/JPG/SVG/PDF)
```bash
bash .github/skills/figma-design-context/scripts/export-assets.sh \
  --file-key <fileKey> --node-ids "1:2,3:4,5:6" \
  --format svg --scale 2 --output ./assets/
```
Formats: `png` (default), `jpg`, `svg`, `pdf`
Scale: 0.01–4 (default 1)

### Export All Images from Frame
```bash
bash .github/skills/figma-design-context/scripts/export-assets.sh \
  --file-key <fileKey> --node-id <frameId> --all-images --output ./assets/
```
Finds all image fills in frame subtree and exports originals.

### Get Image Fills (raw uploaded images)
```bash
bash .github/skills/figma-design-context/scripts/get-image-fills.sh \
  --file-key <fileKey> --output ./image-refs.json
```
Returns URLs to original uploaded images (not rendered).

---

## Team Library Workflows

### Team Components
```bash
bash .github/skills/figma-design-context/scripts/get-team-components.sh \
  --team-id <teamId> --output ./team-components.json
```

### Team Styles
```bash
bash .github/skills/figma-design-context/scripts/get-team-styles.sh \
  --team-id <teamId> --output ./team-styles.json
```

### List Team Projects
```bash
bash .github/skills/figma-design-context/scripts/get-team-projects.sh \
  --team-id <teamId> --output ./projects.json
```

### List Project Files
```bash
bash .github/skills/figma-design-context/scripts/get-project-files.sh \
  --project-id <projectId> --output ./files.json
```

---

## File Management

### Version History
```bash
bash .github/skills/figma-design-context/scripts/get-versions.sh \
  --file-key <fileKey> --output ./versions.json
```

### Post Comment
```bash
bash .github/skills/figma-design-context/scripts/post-comment.sh \
  --file-key <fileKey> --message "Review this section" \
  [--node-id <nodeId>] [--x 100 --y 200]
```

### Current User Info
```bash
bash .github/skills/figma-design-context/scripts/whoami.sh
```
Returns authenticated user's name, email, and ID.

---

## API Reference

### File Operations

| Script | Endpoint | Purpose |
|---|---|---|
| `get-metadata.sh` | `GET /v1/files/{key}?depth=N` | Pages, frames, last-modified |
| `get-design-context.sh` | `GET /v1/files/{key}/nodes?ids=...` | Full node subtree |
| `get-page-full.sh` | `GET /v1/files/{key}/nodes?ids=<pageId>` | Complete page tree |
| `get-flow.sh` | `GET /v1/files/{key}?depth=N` | Connectors + prototype interactions |
| `get-versions.sh` | `GET /v1/files/{key}/versions` | Version history |

### Design System

| Script | Endpoint | Purpose |
|---|---|---|
| `get-components.sh` | `GET /v1/files/{key}/components` | File components |
| `get-styles.sh` | `GET /v1/files/{key}/styles` | File styles |
| `get-variables.sh` | `GET /v1/files/{key}/variables/local` | Design tokens |
| `get-team-components.sh` | `GET /v1/teams/{id}/components` | Team library components |
| `get-team-styles.sh` | `GET /v1/teams/{id}/styles` | Team library styles |

### Images & Assets

| Script | Endpoint | Purpose |
|---|---|---|
| `get-screenshot.sh` | `GET /v1/images/{key}?ids=...&format=png` | Rendered PNG |
| `export-assets.sh` | `GET /v1/images/{key}?ids=...&format=X` | Export PNG/JPG/SVG/PDF |
| `get-image-fills.sh` | `GET /v1/files/{key}/images` | Original uploaded images |

### Collaboration

| Script | Endpoint | Purpose |
|---|---|---|
| `get-comments.sh` | `GET /v1/files/{key}/comments` | All comments |
| `post-comment.sh` | `POST /v1/files/{key}/comments` | Add comment |

### Organization

| Script | Endpoint | Purpose |
|---|---|---|
| `whoami.sh` | `GET /v1/me` | Current user info |
| `get-team-projects.sh` | `GET /v1/teams/{id}/projects` | Team projects |
| `get-project-files.sh` | `GET /v1/projects/{id}/files` | Project files |

---

## Implementation Guide

### Translating Figma to Code

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

### Auto Layout Mapping

```
layoutMode + alignItems → flexbox
┌─────────────────────────────────────────────────────────┐
│ primaryAxisAlignItems:                                  │
│   MIN → justify-start                                   │
│   CENTER → justify-center                               │
│   MAX → justify-end                                     │
│   SPACE_BETWEEN → justify-between                       │
│                                                         │
│ counterAxisAlignItems:                                  │
│   MIN → items-start                                     │
│   CENTER → items-center                                 │
│   MAX → items-end                                       │
│   BASELINE → items-baseline                             │
└─────────────────────────────────────────────────────────┘
```

### Color Conversion

Figma uses 0–1 range; CSS uses 0–255:
```javascript
const toHex = ({r, g, b}) => '#' + [r, g, b]
  .map(v => Math.round(v * 255).toString(16).padStart(2, '0'))
  .join('');
```

---

## Credential Setup

1. Go to https://www.figma.com/settings → Personal access tokens → Create new token
2. Add to `~/.zshenv`:
   ```bash
   export FIGMA_TOKEN="your-token-here"
   ```
3. Reload: `source ~/.zshenv && echo $FIGMA_TOKEN`

### Token Scopes

| Scope | Required For |
|-------|-------------|
| `file_read` | All read operations (default) |
| `file_write` | Post comments |
| `webhooks` | Webhook management |

---

## Errors

| Error | Cause | Fix |
|---|---|---|
| `FIGMA_TOKEN environment variable is required` | Var not exported | Add to `~/.zshenv` and source |
| `403 Forbidden` | Invalid/expired token | Regenerate at figma.com/settings |
| `404 Not Found` | Wrong fileKey or nodeId | Re-check URL segments |
| Empty `images` response | Node ID not found | Run `get-metadata.sh` to confirm |
| Image dimensions exceed 8000px | Node too large | Use `--scale 1` or fetch child nodes |
| Variables API 403/404 | Plan doesn't support Variables | Use `get-styles.sh` instead |
| `429 Too Many Requests` | Rate limited | Wait and retry; reduce parallel calls |

---

## Rate Limits

Figma REST API has rate limits per user:
- **Tier 1** (most endpoints): ~30 requests/minute
- **Images endpoint**: Lower limit, ~10 requests/minute

Tips:
- Batch node IDs in single requests where possible
- Cache responses locally
- Use `--depth` to limit response size

---

## Limitations (REST API vs Plugin API)

These operations require the **Plugin API** (not available via REST):
- ❌ Create/modify nodes on canvas
- ❌ Bind variables to properties
- ❌ Generate diagrams from Mermaid
- ❌ Execute arbitrary JavaScript in file context
- ❌ Real-time collaboration features

REST API supports **read operations** + comments only.
