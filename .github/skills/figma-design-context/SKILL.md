---
name: figma-design-context
description: 'Extract Figma design specs via REST API (no MCP required). Use for: fetching layout/spacing/typography/color specs from a Figma file; getting a visual screenshot reference of a node; listing top-level frames and pages; implementing UI from a Figma design. Requires FIGMA_TOKEN set in ~/.zshenv. Handles: URL parsing, metadata discovery, screenshot download, full node spec extraction, design token summarisation.'
argument-hint: '<figma-url-or-file-key> [--node-id <nodeId>]'
---

# Figma Design Context (No MCP)

Replaces `mcp_com_figma_mcp_get_metadata`, `mcp_com_figma_mcp_get_screenshot`, `mcp_com_figma_mcp_get_design_context` using Figma REST API directly.

## Prerequisites

Check: `echo $FIGMA_TOKEN` — if empty, see [Credential Setup](#credential-setup).

## URL Parsing

`https://www.figma.com/design/AbCdEfGhIj/My-Project?node-id=2313-102848`
- `fileKey` = `AbCdEfGhIj` (segment after `/design/`)
- `nodeId` = `2313:102848` (query param `node-id`, converting `-` → `:`)

## Steps

### Step 1 — Discover Frames (when no node ID known)
```bash
bash .github/skills/figma-design-context/scripts/get-metadata.sh --file-key <fileKey>
```
Output lists pages and frames with node IDs.

### Step 2 — Screenshot
```bash
bash .github/skills/figma-design-context/scripts/get-screenshot.sh \
  --file-key <fileKey> --node-id <nodeId> --scale 2 --output ./figma-screenshot.png
```
Then `view_image ./figma-screenshot.png`. Script auto-resizes to fit Claude's 8000px limit via `sips`. For large frames: fetch child nodes with specific `--node-id` instead.

### Step 3 — Full Design Spec
```bash
bash .github/skills/figma-design-context/scripts/get-design-context.sh \
  --file-key <fileKey> --node-id <nodeId> --output ./figma-context.json
```

### Step 4 — Summarise Spec
```bash
bash .github/skills/figma-design-context/scripts/summarize-context.sh --input ./figma-context.json
```
Prints: frame dimensions, typography, fill colours, spacing/padding/gap, corner radii, component names.

### Step 5 — Implement UI
1. Find existing project components matching design — reuse over creating new.
2. Map Figma fills → project design tokens/CSS variables/Tailwind classes.
3. Map `layoutMode`/`primaryAxisAlignItems`/`counterAxisAlignItems`/`itemSpacing` → flexbox.
4. Map `paddingLeft/Right/Top/Bottom` → padding utilities.
5. Map `cornerRadius` → `rounded-N` or `border-radius`.

### Optional — Shared Styles
```bash
bash .github/skills/figma-design-context/scripts/get-styles.sh --file-key <fileKey>
```

## Credential Setup

1. Go to https://www.figma.com/settings → Personal access tokens → Create new token.
2. Add to `~/.zshenv`: `export FIGMA_TOKEN="your-token-here"`
3. `source ~/.zshenv && echo $FIGMA_TOKEN`

## Errors

| Error | Cause | Fix |
|---|---|---|
| `FIGMA_TOKEN environment variable is required` | Var not exported | Add to `~/.zshenv` and source |
| `403` | Invalid/expired token | Regenerate at figma.com/settings |
| `404` | Wrong `fileKey` | Re-check URL — segment after `/design/` |
| Empty `images` in screenshot response | Node ID not found | Run `get-metadata.sh` to confirm |
| `err: Not found` in context JSON | Node ID missing in file | Confirm with `get-metadata.sh` |
| Image dimensions exceed 8000px | Too large | Script auto-resizes; or pass `--scale 1` |
