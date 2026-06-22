#!/usr/bin/env bash
# get-variables.sh — Fetch local design variables (design tokens) from a Figma file
# Usage: bash get-variables.sh --file-key <fileKey> [--output ./figma-variables.json]
#
# Covers:
#   GET /v1/files/{fileKey}/variables/local      — all local variable definitions + collections
#   GET /v1/files/{fileKey}/variables/published  — (optional) variables published to team library
#
# Variables map to design tokens: colors, spacing, typography, radii, etc.
# Note: Requires Figma Professional/Organization plan or files that use the Variables panel.
#       Falls back with a clear message on 403/404.
# Requires: FIGMA_TOKEN set in environment (see SKILL.md for setup)

set -euo pipefail

FILE_KEY=""
OUTPUT="./figma-variables.json"
INCLUDE_PUBLISHED="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file-key)          FILE_KEY="$2";          shift 2 ;;
    --output)            OUTPUT="$2";            shift 2 ;;
    --include-published) INCLUDE_PUBLISHED="true"; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# ── Validate ─────────────────────────────────────────────────────────────────
: "${FIGMA_TOKEN:?FIGMA_TOKEN environment variable is required. See SKILL.md#credential-setup}"
[[ -z "$FILE_KEY" ]] && { echo "Error: --file-key is required" >&2; exit 1; }

TMPFILE=$(mktemp "$TMPDIR/figma_vars_XXXXXX.json")
TMPFILE_PUB=$(mktemp "$TMPDIR/figma_vars_pub_XXXXXX.json")
trap 'rm -f "$TMPFILE" "$TMPFILE_PUB"' EXIT

echo "Fetching local variables..."

HTTP_STATUS=$(curl -s -w "%{http_code}" \
  -H "X-Figma-Token: $FIGMA_TOKEN" \
  "https://api.figma.com/v1/files/${FILE_KEY}/variables/local" \
  -o "$TMPFILE")

if [[ "$HTTP_STATUS" == "403" || "$HTTP_STATUS" == "404" ]]; then
  echo "Variables API unavailable (HTTP $HTTP_STATUS) — this file may not use Figma Variables,"
  echo "or the plan level does not support the Variables API."
  echo "Use get-styles.sh to get shared colour/text/effect styles instead."
  exit 0
fi

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "Error: Figma API returned HTTP $HTTP_STATUS" >&2
  cat "$TMPFILE" >&2
  exit 1
fi

PUB_STATUS="0"
if [[ "$INCLUDE_PUBLISHED" == "true" ]]; then
  echo "Fetching published variables..."
  PUB_STATUS=$(curl -s -w "%{http_code}" \
    -H "X-Figma-Token: $FIGMA_TOKEN" \
    "https://api.figma.com/v1/files/${FILE_KEY}/variables/published" \
    -o "$TMPFILE_PUB")
fi

python3 - "$TMPFILE" "$TMPFILE_PUB" "$PUB_STATUS" "$OUTPUT" <<'PYEOF'
import json, sys
from collections import defaultdict

with open(sys.argv[1]) as f:
    data = json.load(f)

pub_status = sys.argv[3]
out_path   = sys.argv[4]

if "err" in data:
    print(f"Figma API error: {data['err']}", file=sys.stderr)
    sys.exit(1)

meta         = data.get("meta", {})
variables    = meta.get("variables", {})          # id → variable object
collections  = meta.get("variableCollections", {}) # id → collection object

# Merge published if fetched
pub_variables   = {}
pub_collections = {}
if pub_status == "200":
    with open(sys.argv[2]) as f:
        pub_data = json.load(f)
    pub_meta = pub_data.get("meta", {})
    pub_variables   = pub_meta.get("variables", {})
    pub_collections = pub_meta.get("variableCollections", {})

all_vars  = {**variables,   **pub_variables}
all_colls = {**collections, **pub_collections}

combined = {
    "localVariables":       variables,
    "localCollections":     collections,
    "publishedVariables":   pub_variables,
    "publishedCollections": pub_collections,
}
with open(out_path, "w") as f:
    json.dump(combined, f, indent=2)

if not all_vars:
    print("No variables found. Use get-styles.sh for shared colour/text styles.")
    sys.exit(0)

print(f"Variables: {len(all_vars)}   Collections: {len(all_colls)}")
print(f"Saved to: {out_path}")
print()

def color_to_hex(c):
    r,g,b,a = round(c.get("r",0)*255), round(c.get("g",0)*255), round(c.get("b",0)*255), round(c.get("a",1),2)
    h = f"#{r:02X}{g:02X}{b:02X}"
    return h if a == 1.0 else f"{h} / {a}"

# ── Group variables by collection ─────────────────────────────────────────────
by_collection = defaultdict(list)
for var in all_vars.values():
    by_collection[var.get("variableCollectionId", "?")].append(var)

for coll_id in sorted(by_collection.keys(), key=lambda x: all_colls.get(x, {}).get("name", x)):
    vars_list = by_collection[coll_id]
    coll      = all_colls.get(coll_id, {})
    coll_name = coll.get("name", coll_id)
    modes     = {m["id"]: m["name"] for m in coll.get("modes", [])}
    is_pub    = coll_id in pub_collections
    pub_tag   = "  [published]" if is_pub else ""

    print(f"COLLECTION: {coll_name}{pub_tag}  ({len(vars_list)} variables)")
    if modes:
        print(f"  Modes: {', '.join(modes.values())}")
    print("-" * 60)

    for var in sorted(vars_list, key=lambda x: x.get("name", "")):
        vname  = var.get("name", "?")
        vtype  = var.get("resolvedType", var.get("type", "?"))
        values = var.get("valuesByMode", {})

        val_parts = []
        for mode_id, val in values.items():
            mname = modes.get(mode_id, mode_id)
            if isinstance(val, dict):
                if "r" in val:
                    v_str = color_to_hex(val)
                elif val.get("type") == "VARIABLE_ALIAS":
                    aliased_name = all_vars.get(val.get("id", ""), {}).get("name", val.get("id", "?"))
                    v_str = f"→ {aliased_name}"
                else:
                    v_str = str(val)
            else:
                v_str = str(val)
            val_parts.append(f"{mname}: {v_str}")

        print(f"  [{vtype:<8}] {vname:<40}  {' | '.join(val_parts)}")
    print()
PYEOF
