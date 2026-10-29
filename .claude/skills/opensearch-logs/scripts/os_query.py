#!/usr/bin/env python3
"""Read-only OpenSearch log queries for MOLB / GoBusiness (dev, qa, staging, prod).

Subcommands (JSON on stdout; errors -> stderr `ERROR:` + exit 1):
  ping     --env E
  indices  --env E [--app PATTERN]
  fields   --env E --app A
  search   --env E [--app A] [filters] [--size 50] [--sort desc|asc] [--max-chars 500] [--stack] [--raw]
  count    --env E [--app A] [filters]
  agg      --env E [--app A] [filters] (--field F [--top 20] | --interval 5m)
  trace    --env E --id ID [--app A] [--from now-7d] [--size 200]
  sql      --env E --query "SELECT ..."
  raw      --env E --path /<index>/_search [--body JSON|@file]

Filters: --q "<Lucene query_string>" --level ERROR[,WARN] --trace ID --from now-1h --to now

Requires OPENSEARCH_URL_NONPROD (dev/qa/staging) and OPENSEARCH_URL_PROD. No auth; VPN required.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

ENVS = {
    "dev": ("dev", "OPENSEARCH_URL_NONPROD"),
    "qa": ("qa", "OPENSEARCH_URL_NONPROD"),
    "stg": ("staging", "OPENSEARCH_URL_NONPROD"),
    "staging": ("staging", "OPENSEARCH_URL_NONPROD"),
    "prod": ("prod", "OPENSEARCH_URL_PROD"),
    "production": ("prod", "OPENSEARCH_URL_PROD"),
}
SGT = timezone(timedelta(hours=8))
TRACE_FIELDS = ("trace_id.keyword", "correlation_id.keyword", "correlation.id.keyword")
MAX_SIZE = 1000
TIMEOUT_S = 60
# Only read endpoints are reachable through `raw`.
RAW_ALLOWED = re.compile(
    r"^/(?:[^/_][^/]*/)?(?:_search|_count|_msearch|_field_caps|_mapping|_validate/query)$"
    r"|^/_cat/[a-z_/]+(?:/[^/]+)?$|^/_cluster/health$|^/_resolve/index/[^/]+$"
    r"|^/_plugins/_(?:sql|ppl)(?:/_explain)?$|^/$"
)


def die(msg: str):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def resolve_env(env: str) -> tuple[str, str]:
    key = env.strip().lower()
    if key not in ENVS:
        die(f"unknown env '{env}' (use dev | qa | stg | prod)")
    prefix, var = ENVS[key]
    url = os.environ.get(var, "").strip().rstrip("/")
    if not url:
        die(f"{var} is not set (source ~/.zshenv)")
    return prefix, url


def request(base: str, method: str, path: str, body=None, params: dict | None = None):
    qs = f"?{urllib.parse.urlencode(params)}" if params else ""
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(f"{base}{path}{qs}", data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_S) as res:
            raw = res.read().decode()
    except urllib.error.HTTPError as e:
        die(f"HTTP {e.code} {method} {path}: {e.read().decode()[:2000]}")
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        die(f"cannot reach {base} ({e}). Connect to the VPN and retry.")
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def index_pattern(prefix: str, app: str | None) -> str:
    if not app:
        return f"{prefix}-*"
    parts = []
    for a in (x.strip() for x in app.split(",") if x.strip()):
        # Archived months live in `uw-reindex-<env>-<app>-YYYY-MM` indices.
        parts += [f"{prefix}-{a}*", f"uw-reindex-{prefix}-{a}-*"]
    return ",".join(parts)


def time_range(args) -> dict:
    return {"range": {"@timestamp": {"gte": args.since, "lte": args.until}}}


def trace_clause(trace_id: str) -> dict:
    return {"bool": {"should": [{"term": {f: trace_id}} for f in TRACE_FIELDS], "minimum_should_match": 1}}


def build_query(args) -> dict:
    must: list[dict] = [time_range(args)]
    if args.q:
        must.append({"query_string": {"query": args.q, "default_operator": "AND", "lenient": True}})
    if args.level:
        levels = [lv.strip().upper() for lv in args.level.split(",") if lv.strip()]
        must.append({"terms": {"log_level.keyword": levels}})
    if args.trace:
        must.append(trace_clause(args.trace))
    return {"bool": {"filter": must}}


SEARCH_PARAMS = {"ignore_unavailable": "true", "allow_no_indices": "true"}


def to_sgt(ts: str | None) -> str | None:
    if not ts:
        return ts
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00")).astimezone(SGT)
        return dt.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
    except ValueError:
        return ts


def get_path(src: dict, dotted: str):
    if dotted in src:
        return src[dotted]
    cur = src
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def clip(text, limit: int):
    if text is None or limit <= 0:
        return text
    text = str(text)
    return text if len(text) <= limit else f"{text[:limit]}…[+{len(text) - limit} chars]"


def summarise_hit(hit: dict, max_chars: int, stack: bool) -> dict:
    s = hit.get("_source", {})
    row = {
        "ts_sgt": to_sgt(s.get("@timestamp")),
        "level": s.get("log_level") or s.get("level"),
        "service": s.get("molb_service_name") or s.get("@log_group"),
        "trace_id": s.get("trace_id"),
        "correlation_id": s.get("correlation_id") or get_path(s, "correlation.id"),
        "message": clip(s.get("message") or s.get("@message"), max_chars),
    }
    for k in ("method", "uri", "status", "duration", "logger_name"):
        if s.get(k) is not None:
            row[k] = s[k]
    if stack and s.get("stack_trace"):
        row["stack_trace"] = clip(s["stack_trace"], max_chars * 4)
    row["_index"], row["_id"] = hit.get("_index"), hit.get("_id")
    return {k: v for k, v in row.items() if v not in (None, "")}


def emit(obj):
    print(json.dumps(obj, indent=2, ensure_ascii=False))


def cmd_ping(args):
    _, base = resolve_env(args.env)
    info = request(base, "GET", "/")
    health = request(base, "GET", "/_cluster/health")
    emit({"url": base, "cluster": info.get("cluster_name"), "version": info.get("version", {}).get("number"),
          "status": health.get("status")})


def cmd_indices(args):
    prefix, base = resolve_env(args.env)
    rows = request(base, "GET", f"/_cat/indices/{index_pattern(prefix, args.app)}", None,
                   {"format": "json", "h": "index,docs.count", "s": "index"})
    families: dict[str, dict] = {}
    for r in rows if isinstance(rows, list) else []:
        fam = re.sub(r"[-.]\d{4}[-.]\d{2}([-.]\d{2})?(_shrunken)?$", "", r["index"])
        f = families.setdefault(fam, {"family": fam, "indices": 0, "docs": 0, "latest": ""})
        f["indices"] += 1
        f["docs"] += int(r.get("docs.count") or 0)
        f["latest"] = max(f["latest"], r["index"])
    emit(sorted(families.values(), key=lambda x: x["family"]))


def cmd_fields(args):
    prefix, base = resolve_env(args.env)
    res = request(base, "GET", f"/{index_pattern(prefix, args.app)}/_field_caps", None,
                  {**SEARCH_PARAMS, "fields": "*"})
    fields = res.get("fields", {})
    out = {}
    for name, caps in sorted(fields.items()):
        if name.startswith("_") or name.endswith(".keyword"):
            continue
        out[name] = {"type": ",".join(caps.keys())}
        if f"{name}.keyword" in fields:
            out[name]["exact"] = f"{name}.keyword"
    emit(out)


def cmd_search(args):
    prefix, base = resolve_env(args.env)
    idx = index_pattern(prefix, args.app)
    body = {
        "size": min(args.size, MAX_SIZE),
        "track_total_hits": True,
        "sort": [{"@timestamp": {"order": args.sort}}],
        "query": build_query(args),
    }
    res = request(base, "POST", f"/{idx}/_search", body, SEARCH_PARAMS)
    hits = res.get("hits", {})
    raw_hits = hits.get("hits", [])
    rows = raw_hits if args.raw else [summarise_hit(h, args.max_chars, args.stack) for h in raw_hits]
    emit({"index": idx, "total": hits.get("total", {}).get("value"), "returned": len(rows), "hits": rows})


def cmd_count(args):
    prefix, base = resolve_env(args.env)
    idx = index_pattern(prefix, args.app)
    res = request(base, "POST", f"/{idx}/_count", {"query": build_query(args)}, SEARCH_PARAMS)
    emit({"index": idx, "count": res.get("count")})


def cmd_agg(args):
    prefix, base = resolve_env(args.env)
    if args.interval:
        agg = {"date_histogram": {"field": "@timestamp", "fixed_interval": args.interval,
                                  "time_zone": "+08:00", "min_doc_count": 1}}
    elif args.field:
        field = args.field if args.exact or args.field.endswith(".keyword") else f"{args.field}.keyword"
        agg = {"terms": {"field": field, "size": args.top}}
    else:
        die("agg needs --field or --interval")
    idx = index_pattern(prefix, args.app)
    res = request(base, "POST", f"/{idx}/_search", {"size": 0, "query": build_query(args), "aggs": {"a": agg}},
                  SEARCH_PARAMS)
    buckets = res.get("aggregations", {}).get("a", {}).get("buckets", [])
    emit({"index": idx, "buckets": [{"key": b.get("key_as_string", b.get("key")), "count": b["doc_count"]}
                                    for b in buckets]})


def cmd_trace(args):
    prefix, base = resolve_env(args.env)
    idx = index_pattern(prefix, args.app)
    body = {
        "size": min(args.size, MAX_SIZE),
        "sort": [{"@timestamp": {"order": "asc"}}],
        "query": {"bool": {"filter": [time_range(args), trace_clause(args.id)]}},
    }
    res = request(base, "POST", f"/{idx}/_search", body, SEARCH_PARAMS)
    hits = [summarise_hit(h, args.max_chars, True) for h in res.get("hits", {}).get("hits", [])]
    emit({"id": args.id, "index": idx, "returned": len(hits), "hits": hits})


def cmd_sql(args):
    _, base = resolve_env(args.env)
    if not re.match(r"^\s*(select|show|describe)\b", args.query, re.I):
        die("only SELECT / SHOW / DESCRIBE are allowed")
    res = request(base, "POST", "/_plugins/_sql", {"query": args.query}, {"format": "jdbc"})
    if isinstance(res, dict) and res.get("error"):
        die(f"SQL error: {json.dumps(res['error'])} (quote index names with backticks, e.g. `staging-ap-backend*`)")
    emit(res)


def cmd_raw(args):
    _, base = resolve_env(args.env)
    parsed = urllib.parse.urlsplit("/" + args.path.lstrip("/"))
    if not RAW_ALLOWED.match(parsed.path):
        die(f"path '{parsed.path}' is not an allowed read-only endpoint")
    body = None
    if args.body:
        text = open(args.body[1:]).read() if args.body.startswith("@") else args.body
        body = json.loads(text)
    params = dict(urllib.parse.parse_qsl(parsed.query))
    if parsed.path.endswith(("_search", "_count")):
        params = {**SEARCH_PARAMS, **params}
    emit(request(base, "POST" if body is not None else "GET", parsed.path, body, params or None))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def env_arg(p):
        p.add_argument("--env", required=True, help="dev | qa | stg | prod")

    def app_arg(p, required=False):
        p.add_argument("--app", required=required, help="app name(s), comma-separated, globs ok (e.g. ap-backend)")

    def window(p, default_from):
        p.add_argument("--from", dest="since", default=default_from, help="date math or ISO, e.g. now-1h")
        p.add_argument("--to", dest="until", default="now")

    def filters(p):
        p.add_argument("--q", help="Lucene query_string, e.g. 'message:\"timeout\" AND NOT uri:*health*'")
        p.add_argument("--level", help="log_level values, comma-separated (ERROR,WARN)")
        p.add_argument("--trace", help="trace_id / correlation_id")
        window(p, "now-1h")

    p = sub.add_parser("ping"); env_arg(p); p.set_defaults(fn=cmd_ping)
    p = sub.add_parser("indices"); env_arg(p); app_arg(p); p.set_defaults(fn=cmd_indices)
    p = sub.add_parser("fields"); env_arg(p); app_arg(p, True); p.set_defaults(fn=cmd_fields)

    p = sub.add_parser("search"); env_arg(p); app_arg(p); filters(p)
    p.add_argument("--size", type=int, default=50)
    p.add_argument("--sort", choices=["desc", "asc"], default="desc")
    p.add_argument("--max-chars", type=int, default=500, help="truncate message (0 = full)")
    p.add_argument("--stack", action="store_true", help="include stack_trace")
    p.add_argument("--raw", action="store_true", help="full _source hits")
    p.set_defaults(fn=cmd_search)

    p = sub.add_parser("count"); env_arg(p); app_arg(p); filters(p); p.set_defaults(fn=cmd_count)

    p = sub.add_parser("agg"); env_arg(p); app_arg(p); filters(p)
    p.add_argument("--field", help="terms agg field (.keyword appended automatically)")
    p.add_argument("--exact", action="store_true", help="use --field as-is (numeric/keyword fields)")
    p.add_argument("--top", type=int, default=20)
    p.add_argument("--interval", help="date_histogram fixed_interval, e.g. 5m, 1h")
    p.set_defaults(fn=cmd_agg)

    p = sub.add_parser("trace"); env_arg(p); app_arg(p)
    p.add_argument("--id", required=True, help="trace_id / correlation_id")
    window(p, "now-7d")
    p.add_argument("--size", type=int, default=200)
    p.add_argument("--max-chars", type=int, default=1000)
    p.set_defaults(fn=cmd_trace)

    p = sub.add_parser("sql"); env_arg(p); p.add_argument("--query", required=True); p.set_defaults(fn=cmd_sql)

    p = sub.add_parser("raw"); env_arg(p)
    p.add_argument("--path", required=True, help="e.g. /staging-ap-backend*/_search")
    p.add_argument("--body", help="JSON string or @file")
    p.set_defaults(fn=cmd_raw)

    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
