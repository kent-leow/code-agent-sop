#!/usr/bin/env bash
# summarize-context.sh — Extract human-readable design specs from a figma-context.json file
# Usage: bash summarize-context.sh --input ./figma-context.json [--depth 3]
#
# Prints: frame dimensions, typography, fill colours, spacing/padding, corner radii, component names.
# This replaces needing to read 200+ KB of raw JSON manually.

set -euo pipefail

INPUT=""
MAX_DEPTH="3"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)  INPUT="$2";     shift 2 ;;
    --depth)  MAX_DEPTH="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$INPUT" ]] && { echo "Error: --input is required" >&2; exit 1; }
[[ ! -f "$INPUT" ]] && { echo "Error: file not found: $INPUT" >&2; exit 1; }

python3 - "$INPUT" "$MAX_DEPTH" <<'PYEOF'
import json, sys
from collections import defaultdict

def rgba_to_hex(c):
    r = round(c.get("r", 0) * 255)
    g = round(c.get("g", 0) * 255)
    b = round(c.get("b", 0) * 255)
    a = round(c.get("a", 1), 2)
    hex_col = f"#{r:02X}{g:02X}{b:02X}"
    return hex_col if a == 1.0 else f"{hex_col} (opacity: {a})"

def describe_fill(fill):
    ftype = fill.get("type", "?")
    if ftype == "SOLID":
        return f"solid {rgba_to_hex(fill['color'])}"
    elif ftype in ("GRADIENT_LINEAR", "GRADIENT_RADIAL", "GRADIENT_ANGULAR", "GRADIENT_DIAMOND"):
        stops = fill.get("gradientStops", [])
        colours = " → ".join(rgba_to_hex(s["color"]) for s in stops)
        return f"{ftype.lower().replace('_', ' ')} ({colours})"
    elif ftype == "IMAGE":
        return f"image fill"
    return ftype

typography_seen = {}
colours_seen = set()
components_seen = []
layout_summary = []

def walk(node, depth, max_depth):
    if depth > max_depth:
        return
    ntype = node.get("type", "?")
    name = node.get("name", "")

    # ── Colour fills ────────────────────────────────────────────────
    for fill in node.get("fills", []):
        if fill.get("visible", True):
            colours_seen.add(describe_fill(fill))

    # ── Typography ──────────────────────────────────────────────────
    if ntype == "TEXT":
        style = node.get("style", {})
        key = (
            style.get("fontFamily", "?"),
            style.get("fontPostScriptName", style.get("fontWeight", "?")),
            style.get("fontSize", "?"),
            style.get("lineHeightPx"),
            style.get("letterSpacing", 0),
        )
        label = (
            f"  font: {key[0]}  weight: {key[1]}  size: {key[2]}px"
            + (f"  line-height: {round(key[3], 1)}px" if key[3] else "")
            + (f"  letter-spacing: {key[4]}" if key[4] else "")
        )
        sample = (node.get("characters", "")[:60] + "…") if len(node.get("characters", "")) > 60 else node.get("characters", "")
        typography_seen[key] = (label, sample)

    # ── Auto-layout / flexbox ────────────────────────────────────────
    layout_mode = node.get("layoutMode")
    if layout_mode and layout_mode != "NONE":
        pad = {k: node.get(k, 0) for k in ("paddingLeft", "paddingRight", "paddingTop", "paddingBottom")}
        gap = node.get("itemSpacing", 0)
        primary = node.get("primaryAxisAlignItems", "")
        counter = node.get("counterAxisAlignItems", "")
        layout_summary.append({
            "name": name,
            "mode": layout_mode,
            "gap": gap,
            "padding": pad,
            "primaryAxis": primary,
            "counterAxis": counter,
            "depth": depth,
        })

    # ── Component instances ──────────────────────────────────────────
    if ntype == "INSTANCE":
        components_seen.append(name)

    # ── Recurse ─────────────────────────────────────────────────────
    for child in node.get("children", []):
        walk(child, depth + 1, max_depth)


with open(sys.argv[1]) as f:
    data = json.load(f)

max_depth = int(sys.argv[2])
nodes = data.get("nodes", {})
for node_id, node_data in nodes.items():
    doc = node_data.get("document", {})
    file_name = doc.get("name", "unknown")
    bounds = doc.get("absoluteBoundingBox", doc.get("absoluteRenderBounds", {}))
    print("=" * 60)
    print(f"FRAME: {file_name}  (id: {node_id})")
    if bounds:
        print(f"  Dimensions: {bounds.get('width', '?')} × {bounds.get('height', '?')} px")
    cr = doc.get("cornerRadius")
    if cr:
        print(f"  Corner radius: {cr}px")
    print()
    walk(doc, 0, max_depth)

# ── Typography report ────────────────────────────────────────────────────────
if typography_seen:
    print("TYPOGRAPHY")
    print("-" * 40)
    for (label, sample) in typography_seen.values():
        print(label)
        if sample:
            print(f'    sample: "{sample}"')
    print()

# ── Colour report ────────────────────────────────────────────────────────────
if colours_seen:
    print("COLOURS (fills)")
    print("-" * 40)
    for c in sorted(colours_seen):
        print(f"  {c}")
    print()

# ── Layout report ────────────────────────────────────────────────────────────
if layout_summary:
    print("AUTO-LAYOUT (flexbox equivalents)")
    print("-" * 40)
    for L in layout_summary:
        direction = "flex-row" if L["mode"] == "HORIZONTAL" else "flex-col"
        pad = L["padding"]
        pad_str = f"pt:{pad['paddingTop']} pr:{pad['paddingRight']} pb:{pad['paddingBottom']} pl:{pad['paddingLeft']}"
        print(f"  [{L['depth']}] {L['name']}")
        print(f"       {direction}  gap:{L['gap']}  {pad_str}")
        print(f"       justify:{L['primaryAxis']}  align:{L['counterAxis']}")
    print()

# ── Component instances ──────────────────────────────────────────────────────
if components_seen:
    from collections import Counter
    print("COMPONENT INSTANCES (check project for existing equivalents)")
    print("-" * 40)
    for comp, count in Counter(components_seen).most_common():
        print(f"  {comp}  ×{count}")
    print()
PYEOF
