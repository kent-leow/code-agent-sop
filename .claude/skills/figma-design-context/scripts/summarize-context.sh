#!/usr/bin/env bash
# summarize-context.sh — Extract human-readable design specs from a figma-context.json file
# Usage: bash summarize-context.sh --input ./figma-context.json [--depth 5]
#
# Prints: frame dimensions, typography, fill colours, spacing/padding, corner radii,
#         component instances, CONNECTOR arrows, prototype interactions, node-type breakdown.
# This replaces needing to read 200+ KB of raw JSON manually.

set -euo pipefail

INPUT=""
MAX_DEPTH="5"

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
from collections import defaultdict, Counter

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
        return "image fill"
    return ftype

# ── Accumulators ─────────────────────────────────────────────────────────────
typography_seen  = {}
colours_seen     = set()
stroke_seen      = set()
components_seen  = []
layout_summary   = []
connectors_seen  = []   # CONNECTOR nodes (flow arrows)
interactions_seen = []  # prototype interactions
node_type_counts = Counter()

# ── Build id→name index (used for interaction destination resolution) ─────────
id_to_name = {}

def index_names(node):
    nid = node.get("id")
    if nid:
        id_to_name[nid] = node.get("name", "?")
    for child in node.get("children", []):
        index_names(child)

def walk(node, depth, max_depth):
    if depth > max_depth:
        return
    ntype = node.get("type", "?")
    name  = node.get("name", "")
    nid   = node.get("id", "")

    node_type_counts[ntype] += 1

    # ── CONNECTOR (flow arrow) ───────────────────────────────────────
    if ntype == "CONNECTOR":
        start = node.get("connectorStart", {})
        end   = node.get("connectorEnd",   {})
        label = node.get("characters", "") or ""
        sname = id_to_name.get(start.get("endpointNodeId"), start.get("endpointNodeId", "?"))
        ename = id_to_name.get(end.get("endpointNodeId"),   end.get("endpointNodeId",   "?"))
        connectors_seen.append((sname, ename, label, name))

    # ── Colour fills ─────────────────────────────────────────────────
    for fill in node.get("fills", []):
        if fill.get("visible", True):
            colours_seen.add(describe_fill(fill))

    # ── Strokes ──────────────────────────────────────────────────────
    for stroke in node.get("strokes", []):
        if stroke.get("visible", True):
            c = stroke.get("color")
            if c:
                stroke_seen.add(f"solid {rgba_to_hex(c)}")

    # ── Typography ───────────────────────────────────────────────────
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
        chars = node.get("characters", "")
        sample = (chars[:60] + "…") if len(chars) > 60 else chars
        typography_seen[key] = (label, sample)

    # ── Auto-layout / flexbox ─────────────────────────────────────────
    layout_mode = node.get("layoutMode")
    if layout_mode and layout_mode != "NONE":
        pad = {k: node.get(k, 0) for k in ("paddingLeft", "paddingRight", "paddingTop", "paddingBottom")}
        layout_summary.append({
            "name":        name,
            "mode":        layout_mode,
            "gap":         node.get("itemSpacing", 0),
            "padding":     pad,
            "primaryAxis": node.get("primaryAxisAlignItems", ""),
            "counterAxis": node.get("counterAxisAlignItems", ""),
            "wrap":        node.get("layoutWrap", "NO_WRAP"),
            "depth":       depth,
        })

    # ── Prototype interactions ────────────────────────────────────────
    for interaction in node.get("interactions", []):
        trigger     = interaction.get("trigger", {})
        action_list = interaction.get("actions") or []
        if not action_list and interaction.get("action"):
            action_list = [interaction["action"]]
        for action in action_list:
            if not action:
                continue
            dest = action.get("destinationId")
            interactions_seen.append({
                "fromName":    name,
                "fromId":      nid,
                "triggerType": trigger.get("type", "?"),
                "actionType":  action.get("type", "?"),
                "toId":        dest,
                "url":         action.get("url"),
            })

    # ── Component instances ───────────────────────────────────────────
    if ntype == "INSTANCE":
        components_seen.append(name)

    # ── Recurse ───────────────────────────────────────────────────────
    for child in node.get("children", []):
        walk(child, depth + 1, max_depth)


with open(sys.argv[1]) as f:
    data = json.load(f)

max_depth = int(sys.argv[2])
nodes = data.get("nodes", {})

# ── Index names first (needed for connector + interaction resolution) ─────────
for node_id, node_data in nodes.items():
    index_names(node_data.get("document", {}))

# ── Walk each node ────────────────────────────────────────────────────────────
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

# ── Node-type breakdown ───────────────────────────────────────────────────────
if node_type_counts:
    print("NODE TYPES")
    print("-" * 40)
    for ntype, count in node_type_counts.most_common():
        print(f"  {ntype:<25} {count:>4}")
    print()

# ── CONNECTOR arrows (UI flow) ────────────────────────────────────────────────
if connectors_seen:
    print(f"CONNECTOR ARROWS / UI FLOW ({len(connectors_seen)})")
    print("-" * 40)
    for (sname, ename, label, cname) in connectors_seen:
        lab = f'  "{label}"' if label else ""
        print(f"  {sname}  ──{lab}──>  {ename}")
    print()

# ── Prototype interactions ────────────────────────────────────────────────────
if interactions_seen:
    TRIGGER_LABELS = {
        "ON_CLICK": "click", "ON_HOVER": "hover", "ON_PRESS": "press",
        "AFTER_TIMEOUT": "timeout", "MOUSE_ENTER": "enter", "MOUSE_LEAVE": "leave",
    }
    NAV_TYPES = {
        "NAVIGATE": "navigate", "OVERLAY": "overlay", "SWAP": "swap",
        "SCROLL_TO": "scroll-to", "BACK": "back", "URL": "open-url",
    }
    print(f"PROTOTYPE INTERACTIONS ({len(interactions_seen)})")
    print("-" * 40)
    for i in interactions_seen:
        trigger = TRIGGER_LABELS.get(i["triggerType"], i["triggerType"])
        nav     = NAV_TYPES.get(i["actionType"], i["actionType"])
        dest    = id_to_name.get(i["toId"], i["toId"]) if i.get("toId") else i.get("url", "?")
        print(f"  {i['fromName']}  --[{trigger}]-->  {dest}  ({nav})")
    print()

# ── Typography ────────────────────────────────────────────────────────────────
if typography_seen:
    print("TYPOGRAPHY")
    print("-" * 40)
    for (label, sample) in typography_seen.values():
        print(label)
        if sample:
            print(f'    sample: "{sample}"')
    print()

# ── Colours ───────────────────────────────────────────────────────────────────
if colours_seen:
    print("COLOURS (fills)")
    print("-" * 40)
    for c in sorted(colours_seen):
        print(f"  {c}")
    print()

if stroke_seen:
    print("COLOURS (strokes/borders)")
    print("-" * 40)
    for c in sorted(stroke_seen):
        print(f"  {c}")
    print()

# ── Layout ────────────────────────────────────────────────────────────────────
if layout_summary:
    print("AUTO-LAYOUT (flexbox equivalents)")
    print("-" * 40)
    for L in layout_summary:
        direction = "flex-row" if L["mode"] == "HORIZONTAL" else "flex-col"
        pad = L["padding"]
        pad_str = f"pt:{pad['paddingTop']} pr:{pad['paddingRight']} pb:{pad['paddingBottom']} pl:{pad['paddingLeft']}"
        wrap_str = "  flex-wrap" if L.get("wrap") == "WRAP" else ""
        print(f"  [{L['depth']}] {L['name']}")
        print(f"       {direction}  gap:{L['gap']}  {pad_str}{wrap_str}")
        print(f"       justify:{L['primaryAxis']}  align:{L['counterAxis']}")
    print()

# ── Component instances ───────────────────────────────────────────────────────
if components_seen:
    print("COMPONENT INSTANCES (check project for existing equivalents)")
    print("-" * 40)
    for comp, count in Counter(components_seen).most_common():
        print(f"  {comp}  ×{count}")
    print()
PYEOF
