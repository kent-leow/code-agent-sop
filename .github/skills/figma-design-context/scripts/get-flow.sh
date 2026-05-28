#!/usr/bin/env bash
# get-flow.sh — Extract UI flow: prototype interactions + CONNECTOR arrow nodes from a Figma file
# Usage: bash get-flow.sh --file-key <fileKey> [--page-id <pageId>] [--depth 6] [--output ./figma-flow.json]
#
# Outputs two categories:
#   - CONNECTOR nodes  : flow arrows drawn on canvas (connectorStart / connectorEnd)
#   - PROTOTYPE links  : node interactions[] — click/hover → navigate to another frame
#
# Accepts page IDs in both API format (0:1) and URL format (0-1)
# Requires: FIGMA_TOKEN set in environment (see SKILL.md for setup)

set -euo pipefail

FILE_KEY=""
PAGE_ID=""
DEPTH="6"
OUTPUT="./figma-flow.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file-key) FILE_KEY="$2"; shift 2 ;;
    --page-id)  PAGE_ID="$2";  shift 2 ;;
    --depth)    DEPTH="$2";    shift 2 ;;
    --output)   OUTPUT="$2";   shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required. See SKILL.md#credential-setup}"
[[ -z "$FILE_KEY" ]] && { echo "Error: --file-key is required" >&2; exit 1; }

TMPFILE=$(mktemp "$TMPDIR/figma_flow_XXXXXX.json")
trap 'rm -f "$TMPFILE"' EXIT

echo "Fetching file tree (depth=${DEPTH}) for UI flow analysis..."

HTTP_STATUS=$(curl -s -w "%{http_code}" \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/${FILE_KEY}?depth=${DEPTH}" \
  -o "$TMPFILE")

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "Error: Figma API returned HTTP $HTTP_STATUS" >&2
  cat "$TMPFILE" >&2
  exit 1
fi

python3 - "$TMPFILE" "$PAGE_ID" "$OUTPUT" <<'PYEOF'
import json, sys
from collections import defaultdict

with open(sys.argv[1]) as f:
    data = json.load(f)

page_filter = sys.argv[2].strip() if len(sys.argv) > 2 and sys.argv[2] else None
out_path    = sys.argv[3]

if "err" in data:
    print(f"Figma API error: {data['err']}", file=sys.stderr)
    sys.exit(1)

doc = data.get("document", {})

# ── Build id → name index across the entire file ────────────────────────────
id_to_name = {}

def index_names(node):
    nid = node.get("id")
    if nid:
        id_to_name[nid] = node.get("name", "?")
    for child in node.get("children", []):
        index_names(child)

for page in doc.get("children", []):
    index_names(page)

# ── Traversal: collect connectors and interactions ────────────────────────────
interactions = []   # prototype links
connectors   = []   # CONNECTOR nodes (drawn arrows)

NAV_TYPES = {
    "NAVIGATE":   "navigate",
    "OVERLAY":    "open overlay",
    "SWAP":       "swap overlay",
    "SCROLL_TO":  "scroll to",
    "CHANGE_TO":  "change to",
    "BACK":       "back",
    "CLOSE":      "close overlay",
    "URL":        "open URL",
}

TRIGGER_LABELS = {
    "ON_CLICK":          "click",
    "ON_HOVER":          "hover",
    "ON_PRESS":          "press",
    "ON_DRAG":           "drag",
    "AFTER_TIMEOUT":     "after timeout",
    "MOUSE_ENTER":       "mouse enter",
    "MOUSE_LEAVE":       "mouse leave",
    "MOUSE_UP":          "mouse up",
    "MOUSE_DOWN":        "mouse down",
    "ON_KEY_DOWN":       "key down",
    "ON_COMPONENT_LOAD": "component load",
}

def extract_flow(node, page_name):
    ntype = node.get("type", "")
    nid   = node.get("id", "")
    nname = node.get("name", "")

    # ── CONNECTOR node (drawn flow arrow) ─────────────────────────────────
    if ntype == "CONNECTOR":
        start  = node.get("connectorStart", {})
        end    = node.get("connectorEnd",   {})
        label  = node.get("characters", "") or ""
        stroke = None
        for s in node.get("strokes", []):
            c = s.get("color", {})
            if c:
                stroke = f"#{round(c.get('r',0)*255):02X}{round(c.get('g',0)*255):02X}{round(c.get('b',0)*255):02X}"
                break
        connectors.append({
            "id":            nid,
            "name":          nname,
            "page":          page_name,
            "label":         label,
            "startNodeId":   start.get("endpointNodeId"),
            "startMagnet":   start.get("magnet"),
            "endNodeId":     end.get("endpointNodeId"),
            "endMagnet":     end.get("magnet"),
            "strokeColor":   stroke,
        })

    # ── Prototype interactions ─────────────────────────────────────────────
    for interaction in node.get("interactions", []):
        trigger  = interaction.get("trigger", {})
        # `actions` (plural, newer) or `action` (singular, older)
        action_list = interaction.get("actions") or []
        if not action_list and interaction.get("action"):
            action_list = [interaction["action"]]

        for action in action_list:
            if not action:
                continue
            atype = action.get("type", "?")
            dest  = action.get("destinationId")

            entry = {
                "fromId":      nid,
                "fromName":    nname,
                "page":        page_name,
                "triggerType": trigger.get("type", "?"),
                "actionType":  atype,
                "toId":        dest,
                "toName":      id_to_name.get(dest, dest) if dest else None,
                "url":         action.get("url"),
                "overlayPosition": action.get("overlayRelativePosition"),
            }
            tx = action.get("transition") or {}
            if tx:
                entry["transition"] = tx.get("type")
                entry["duration"]   = tx.get("duration")
                entry["easing"]     = (tx.get("easing") or {}).get("type")
            interactions.append(entry)

    for child in node.get("children", []):
        extract_flow(child, page_name)

for page in doc.get("children", []):
    pid = page.get("id", "")
    if page_filter and pid != page_filter and page.get("name", "") != page_filter:
        continue
    extract_flow(page, page.get("name", "?"))

# ── Resolve IDs to names ──────────────────────────────────────────────────────
for c in connectors:
    c["startNodeName"] = id_to_name.get(c["startNodeId"], c["startNodeId"]) if c["startNodeId"] else None
    c["endNodeName"]   = id_to_name.get(c["endNodeId"],   c["endNodeId"])   if c["endNodeId"]   else None

# ── Save output ───────────────────────────────────────────────────────────────
result = {"connectors": connectors, "interactions": interactions}
with open(out_path, "w") as f:
    json.dump(result, f, indent=2)

# ── Print summary ─────────────────────────────────────────────────────────────
print(f"UI flow saved to: {out_path}")
print()

if connectors:
    print(f"CONNECTOR ARROWS ({len(connectors)})  — drawn flow arrows on canvas")
    print("-" * 60)
    for c in connectors:
        sname  = c.get("startNodeName") or c.get("startNodeId") or "(canvas)"
        ename  = c.get("endNodeName")   or c.get("endNodeId")   or "(canvas)"
        label  = f'  "{c["label"]}"' if c.get("label") else ""
        color  = f"  [{c['strokeColor']}]" if c.get("strokeColor") else ""
        print(f"  [{c['page']}]  {sname}  ──{label}──>  {ename}{color}")
    print()
else:
    print("No CONNECTOR nodes found (no flow arrows drawn on canvas).")
    print()

if interactions:
    print(f"PROTOTYPE INTERACTIONS ({len(interactions)})  — tap/click/hover → navigate")
    print("-" * 60)
    for i in interactions:
        trigger = TRIGGER_LABELS.get(i.get("triggerType", ""), i.get("triggerType", "?"))
        nav     = NAV_TYPES.get(i.get("actionType", ""), i.get("actionType", "?"))
        dest    = i.get("toName") or i.get("toId") or i.get("url") or "?"
        tx      = f"  ({i['transition']} {int((i.get('duration') or 0)*1000)}ms)" if i.get("transition") else ""
        print(f"  [{i['page']}]  {i['fromName']}  --[{trigger}]-->  {dest}  ({nav}){tx}")
    print()
else:
    print("No prototype interactions found.")
    print()

if not connectors and not interactions:
    print("Tip: UI flow can also be documented via Figma sections/annotations.")
    print("     Try get-comments.sh to fetch designer notes.")
PYEOF
