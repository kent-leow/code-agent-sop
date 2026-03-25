---
name: figma-design-context
description: 'Extract Figma design specs via REST API (no MCP required). Use for: fetching layout/spacing/typography/color specs from a Figma file; getting a visual screenshot reference of a node; listing top-level frames and pages; implementing UI from a Figma design. Requires FIGMA_TOKEN set in ~/.zshenv. Handles: URL parsing, metadata discovery, screenshot download, full node spec extraction, design token summarisation.'
argument-hint: '<figma-url-or-file-key> [--node-id <nodeId>]'
---

# Figma Design Context (No MCP)

Replaces `mcp_com_figma_mcp_get_metadata`, `mcp_com_figma_mcp_get_screenshot`, and `mcp_com_figma_mcp_get_design_context` using the Figma REST API directly.

## When to Use
- You are in an environment where the Figma MCP server cannot be started (e.g. enterprise GHCP)
- User provides a Figma URL and wants you to implement the UI
- You need to identify the correct frame node ID before fetching specs
- You need a screenshot as a visual reference for development

---

## Prerequisites

### Required environment variable

| Variable | Description |
|---|---|
| `FIGMA_TOKEN` | Figma Personal Access Token (PAT) |

Check by running:
```bash
echo $FIGMA_TOKEN
```

If empty, see the [Credential Setup](#credential-setup) section below.

---

## Parsing a Figma URL

Given a URL like:
```
https://www.figma.com/design/AbCdEfGhIj/My-Project?node-id=2313-102848
```

Extract:
- **`fileKey`** = `AbCdEfGhIj` (the segment after `/design/`)
- **`nodeId`** = `2313:102848` (the `node-id` query param, converting `-` → `:`)

---

## Procedure

### Step 1 — Discover frames (when no node ID is known)

Run [get-metadata.sh](./scripts/get-metadata.sh) to list all pages and their top-level frames:

```bash
bash .github/skills/figma-design-context/scripts/get-metadata.sh \
  --file-key <fileKey>
```

Output example:
```
Page: Page 1  (id: 0:1)
  Frame: Home  (id: 2313:102848)  type: FRAME
  Frame: Dashboard  (id: 514:47004)  type: FRAME
```

Identify the target frame name and note its node ID.

---

### Step 2 — Get a visual screenshot reference

Run [get-screenshot.sh](./scripts/get-screenshot.sh) to download a rendered PNG of the target node:

```bash
bash .github/skills/figma-design-context/scripts/get-screenshot.sh \
  --file-key <fileKey> \
  --node-id <nodeId> \
  --scale 2 \
  --output ./figma-screenshot.png
```

Then use the `view_image` tool to view `./figma-screenshot.png`.  
This gives you the visual reference equivalent to `mcp_com_figma_mcp_get_screenshot`.

---

### Step 3 — Get full design spec

Run [get-design-context.sh](./scripts/get-design-context.sh) to extract the complete node spec (layout, spacing, typography, colours, component hierarchy):

```bash
bash .github/skills/figma-design-context/scripts/get-design-context.sh \
  --file-key <fileKey> \
  --node-id <nodeId> \
  --output ./figma-context.json
```

The JSON saved at `./figma-context.json` contains the full Figma document node tree.  
This is the equivalent of `mcp_com_figma_mcp_get_design_context`.

---

### Step 4 — Summarise the spec

Run [summarize-context.sh](./scripts/summarize-context.sh) to extract a human-readable summary of key design properties:

```bash
bash .github/skills/figma-design-context/scripts/summarize-context.sh \
  --input ./figma-context.json
```

This prints:
- Frame dimensions
- Typography (font family, size, weight per text node)
- Fill colours (hex)
- Spacing / padding / gap (auto-layout)
- Corner radii
- Component names

---

### Step 5 — Implement the UI

Using the screenshot (visual reference) and the spec summary:

1. Check the target project for **existing components** that match the design intent — reuse them instead of creating new ones.
2. Map Figma fill colours to the project's **design tokens / CSS variables / Tailwind classes**.
3. Map `layoutMode`, `primaryAxisAlignItems`, `counterAxisAlignItems`, `itemSpacing` to **flexbox** (`flex-col`, `flex-row`, `gap-N`, `justify-*`, `items-*`).
4. Map `paddingLeft/Right/Top/Bottom` to **padding utilities**.
5. Map `cornerRadius` to **rounded-N** (Tailwind) or `border-radius`.
6. Adapt stack: the Figma REST API returns raw specs — translate to the project's actual component library and conventions.

---

### Optional — Fetch shared styles (design tokens)

Run [get-styles.sh](./scripts/get-styles.sh) to list all shared colour, text, and effect styles defined in the file:

```bash
bash .github/skills/figma-design-context/scripts/get-styles.sh \
  --file-key <fileKey>
```

---

## Credential Setup

### Generate a Figma Personal Access Token

1. Open [https://www.figma.com/settings](https://www.figma.com/settings)
2. Scroll to **Personal access tokens** → click **Create new token**
3. Give it a name (e.g. `copilot-dev`), set expiry, click **Create token**
4. Copy the token — it is shown **only once**

### Add to `~/.zshenv`

```bash
# Open ~/.zshenv in an editor, e.g.:
open -e ~/.zshenv
```

Add the following line:
```bash
export FIGMA_TOKEN="your-token-here"
```

Save, then reload:
```bash
source ~/.zshenv
echo $FIGMA_TOKEN   # should print the token
```

> `~/.zshenv` is sourced for all zsh sessions (interactive and non-interactive), ensuring the variable is always available to scripts.

---

## Error Reference

| Error | Cause | Fix |
|---|---|---|
| `FIGMA_TOKEN environment variable is required` | Var not exported | Add to `~/.zshenv` and `source ~/.zshenv` |
| `curl: (22) The requested URL returned error: 403` | Invalid or expired token | Regenerate PAT at figma.com/settings |
| `curl: (22) The requested URL returned error: 404` | Wrong `fileKey` | Re-check the URL — segment immediately after `/design/` |
| Empty `images` object in screenshot response | Node ID not found | Run `get-metadata.sh` to confirm the correct node ID |
| `err: Not found` in context JSON | Node ID missing in file | Confirm node ID with `get-metadata.sh` |
