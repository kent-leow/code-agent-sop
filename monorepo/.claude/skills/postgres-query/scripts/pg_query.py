#!/usr/bin/env python3
"""PostgreSQL access for MOLB / GoBusiness databases via psql.

Databases: licence | agency-portal | formbuilder | onboarding-portal | payment
Envs:      dev | qa | stg | prod

Subcommands (errors -> stderr `ERROR:` + exit 1):
  check     [--db D] [--env E] [--connect]           which env vars are set (values never printed); optional login test
  tables    --db D --env E [--schema S] [--like PAT]   list tables
  describe  --db D --env E --table [schema.]table      columns, types, nullability
  query     --db D --env E (--sql SQL | --file F) [--csv] [--timeout 60]
            [--write [--rollback]]                     --write: DEV/QA/STG only, after explicit user approval
  env-template                                         print ~/.zshenv placeholder block

Safety: every session runs inside `BEGIN READ ONLY` unless --write is given (refused for PROD).
Statements are also screened client-side for write/DDL/admin keywords.
Credentials: DB_<DB>_<ENV>_{HOST,PORT,NAME,USER,PASSWORD,ROLE} in ~/.zshenv.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys

DBS = {
    "LICENCE": ("licence", "licence-service", "license", "ls"),
    "AGENCY_PORTAL": ("agency-portal", "agencyportal", "ap"),
    "FORMBUILDER": ("formbuilder", "form-builder", "fb"),
    "ONBOARDING_PORTAL": ("onboarding-portal", "onboarding", "op"),
    "PAYMENT": ("payment", "payment-service", "pay"),
}
ENVS = {"dev": "DEV", "qa": "QA", "stg": "STG", "staging": "STG", "prod": "PROD", "production": "PROD"}
FIELDS = ("HOST", "PORT", "NAME", "USER", "PASSWORD", "ROLE")
REQUIRED = ("HOST", "NAME", "USER", "PASSWORD")
READ_LEADS = {"select", "with", "explain", "show", "table", "values"}
# Statement-level commands (SET, BEGIN, VACUUM, DO, ...) are already rejected by READ_LEADS;
# these catch writes nested inside CTEs / EXPLAIN / SELECT INTO / row locks.
WRITE_WORDS = "insert update delete merge truncate drop alter create grant revoke copy call into share".split()
DENY_FUNCS = (
    "set_config pg_terminate_backend pg_cancel_backend pg_reload_conf pg_rotate_logfile pg_switch_wal "
    "pg_advisory_lock pg_advisory_xact_lock lo_import lo_export lo_unlink dblink dblink_exec "
    "pg_read_file pg_read_binary_file pg_ls_dir pg_file_write nextval setval"
).split()
VPN_HINTS = ("timeout", "could not connect", "connection refused", "could not translate host", "no route to host",
             "network is unreachable")


def die(msg: str):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def resolve_db(db: str) -> str:
    key = db.strip().lower().replace("_", "-")
    for canon, aliases in DBS.items():
        if key in aliases or key == canon.lower().replace("_", "-"):
            return canon
    die(f"unknown db '{db}' (use {' | '.join(a[0] for a in DBS.values())})")


def resolve_env(env: str) -> str:
    key = env.strip().lower()
    if key not in ENVS:
        die(f"unknown env '{env}' (use dev | qa | stg | prod)")
    return ENVS[key]


def var(db: str, env: str, field: str) -> str:
    return f"DB_{db}_{env}_{field}"


def conn_settings(db: str, env: str) -> dict:
    vals = {f: os.environ.get(var(db, env, f), "").strip() for f in FIELDS}
    missing = [var(db, env, f) for f in REQUIRED if not vals[f]]
    if missing:
        die(f"not set: {', '.join(missing)} (fill them in ~/.zshenv, then `source ~/.zshenv`)")
    vals["PORT"] = vals["PORT"] or "5432"
    return vals


def strip_sql(sql: str) -> str:
    """Blank out comments, string literals, quoted identifiers and dollar-quoted bodies."""
    out, i, n = [], 0, len(sql)
    while i < n:
        c, nxt = sql[i], sql[i + 1] if i + 1 < n else ""
        if c == "-" and nxt == "-":
            j = sql.find("\n", i)
            i = n if j < 0 else j
        elif c == "/" and nxt == "*":
            j = sql.find("*/", i + 2)
            i = n if j < 0 else j + 2
            out.append(" ")
        elif c in ("'", '"'):
            j = i + 1
            while j < n:
                if sql[j] == c and j + 1 < n and sql[j + 1] == c:
                    j += 2
                elif sql[j] == c:
                    break
                else:
                    j += 1
            out.append(" '' " if c == "'" else ' "x" ')
            i = j + 1
        elif c == "$":
            m = re.match(r"\$[A-Za-z_]*\$", sql[i:])
            if m:
                tag = m.group(0)
                j = sql.find(tag, i + len(tag))
                out.append(" '' ")
                i = n if j < 0 else j + len(tag)
            else:
                out.append(c)
                i += 1
        else:
            out.append(c)
            i += 1
    return "".join(out)


def write_reasons(sql: str) -> list[str]:
    """Empty list == statement is safe to run read-only."""
    body = strip_sql(sql).lower()
    reasons = []
    if "\\" in body:
        reasons.append("psql meta-commands (\\) are not allowed")
    for stmt in (s.strip() for s in body.split(";")):
        if not stmt:
            continue
        lead = re.match(r"[a-z]+", stmt)
        if not lead or lead.group(0) not in READ_LEADS:
            reasons.append(f"statement starts with '{lead.group(0) if lead else stmt[:20]}'")
        hits = sorted({w for w in WRITE_WORDS if re.search(rf"\b{w}\b", stmt)})
        if hits:
            reasons.append(f"write/admin keyword(s): {', '.join(hits)}")
        funcs = sorted({f for f in DENY_FUNCS if re.search(rf"\b{f}\s*\(", stmt)})
        if funcs:
            reasons.append(f"side-effect function(s): {', '.join(funcs)}")
    return reasons


def quote_ident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def quote_lit(text: str) -> str:
    return "'" + text.replace("'", "''") + "'"


def run_psql(db: str, env: str, sql: str, *, write: bool = False, rollback: bool = False, csv: bool = False,
             timeout_s: int = 60) -> int:
    psql = shutil.which("psql")
    if not psql:
        die("psql not found (brew install libpq && brew link --force libpq)")
    c = conn_settings(db, env)
    if write and env == "PROD":
        die("PROD is read-only; writes are refused")
    if not write:
        reasons = write_reasons(sql)
        if reasons:
            hint = "" if env == "PROD" else " — rerun with --write only after the user explicitly approves this SQL"
            die(f"non-read SQL refused ({'; '.join(reasons)}){hint}")
    elif re.search(r"\b(begin|commit|rollback|savepoint)\b", strip_sql(sql).lower()):
        die("do not include transaction control; the script wraps --write in a single transaction")

    lines = [
        "\\set ON_ERROR_STOP on",
        "\\set QUIET on",
        "BEGIN;" if write else "BEGIN READ ONLY;",
        f"SET LOCAL statement_timeout = {int(timeout_s) * 1000};",
        "SET LOCAL lock_timeout = 5000;",
    ]
    if c["ROLE"]:
        lines.append(f"SET LOCAL ROLE {quote_ident(c['ROLE'])};")
    lines += ["\\set QUIET off", sql.rstrip().rstrip(";") + ";", "\\set QUIET on",
              "ROLLBACK;" if (rollback or not write) else "COMMIT;"]
    if write:
        lines.append(f"\\echo '-- {'ROLLED BACK (preview only)' if rollback else 'COMMITTED'}'")

    cmd = [psql, "-X", "-w", "-P", "pager=off", "-h", c["HOST"], "-p", c["PORT"], "-d", c["NAME"], "-U", c["USER"],
           "-f", "-"]
    if csv:
        cmd.insert(1, "--csv")
    env_vars = {**os.environ, "PGPASSWORD": c["PASSWORD"], "PGCONNECT_TIMEOUT": "10",
                "PGAPPNAME": "code-agent-investigate"}
    proc = subprocess.run(cmd, input="\n".join(lines) + "\n", text=True, capture_output=True, env=env_vars)
    sys.stdout.write(proc.stdout)
    if proc.returncode != 0:
        err = proc.stderr.replace(c["PASSWORD"], "***") if c["PASSWORD"] else proc.stderr
        sys.stderr.write(err)
        if any(h in err.lower() for h in VPN_HINTS):
            print(f"HINT: cannot reach {db}/{env} — connect to the VPN and retry.", file=sys.stderr)
    return proc.returncode


def cmd_check(args):
    dbs = [resolve_db(args.db)] if args.db else list(DBS)
    envs = [resolve_env(args.env)] if args.env else ["DEV", "QA", "STG", "PROD"]
    report = []
    for db in dbs:
        for env in envs:
            present = {f: bool(os.environ.get(var(db, env, f), "").strip()) for f in FIELDS}
            row = {"db": db, "env": env, "ready": all(present[f] for f in REQUIRED),
                   "missing": [f for f in REQUIRED if not present[f]],
                   "role": present["ROLE"]}
            report.append(row)
    print(json.dumps(report, indent=2))
    if args.connect:
        for row in (r for r in report if r["ready"]):
            print(f"--- {row['db']} {row['env']}", flush=True)
            run_psql(row["db"], row["env"], "SELECT current_user, session_user, current_database(), "
                                            "current_setting('transaction_read_only') AS read_only, version()",
                     csv=True)


def cmd_tables(args):
    db, env = resolve_db(args.db), resolve_env(args.env)
    where = ["table_schema NOT IN ('pg_catalog','information_schema')"]
    if args.schema:
        where.append(f"table_schema = {quote_lit(args.schema)}")
    if args.like:
        where.append(f"table_name ILIKE {quote_lit(args.like)}")
    sql = ("SELECT table_schema, table_name, table_type FROM information_schema.tables WHERE "
           + " AND ".join(where) + " ORDER BY 1, 2 LIMIT 500")
    sys.exit(run_psql(db, env, sql, csv=args.csv))


def cmd_describe(args):
    db, env = resolve_db(args.db), resolve_env(args.env)
    schema, _, table = args.table.rpartition(".")
    where = f"table_name = {quote_lit(table)}" + (f" AND table_schema = {quote_lit(schema)}" if schema else "")
    sql = ("SELECT table_schema, column_name, data_type, is_nullable, column_default "
           f"FROM information_schema.columns WHERE {where} ORDER BY table_schema, ordinal_position")
    sys.exit(run_psql(db, env, sql, csv=args.csv))


def cmd_query(args):
    db, env = resolve_db(args.db), resolve_env(args.env)
    if bool(args.sql) == bool(args.file):
        die("give exactly one of --sql or --file")
    sql = args.sql or open(args.file).read()
    if args.rollback and not args.write:
        die("--rollback only applies with --write")
    lead = strip_sql(sql).strip().lower()
    if not args.write and lead.startswith(("select", "with")) and not re.search(r"\blimit\b", lead):
        print("WARN: no LIMIT — add one to avoid large result sets", file=sys.stderr)
    sys.exit(run_psql(db, env, sql, write=args.write, rollback=args.rollback, csv=args.csv, timeout_s=args.timeout))


def cmd_env_template(_args):
    print("# PostgreSQL — values from DBeaver (Main: Host/Port/Database/Username/Password; session role).")
    print("# Single-quote values containing special characters. DEV/QA/STG = read+write, PROD = read-only.")
    for db in DBS:
        for env in ("DEV", "QA", "STG", "PROD"):
            print(f"# {db} {env}")
            for f in FIELDS:
                print(f"export {var(db, env, f)}='{'5432' if f == 'PORT' else ''}'")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    def target(p):
        p.add_argument("--db", required=True, help=" | ".join(a[0] for a in DBS.values()))
        p.add_argument("--env", required=True, help="dev | qa | stg | prod")
        p.add_argument("--csv", action="store_true")

    p = sub.add_parser("check")
    p.add_argument("--db"); p.add_argument("--env"); p.add_argument("--connect", action="store_true")
    p.set_defaults(fn=cmd_check)

    p = sub.add_parser("tables"); target(p); p.add_argument("--schema"); p.add_argument("--like")
    p.set_defaults(fn=cmd_tables)

    p = sub.add_parser("describe"); target(p); p.add_argument("--table", required=True)
    p.set_defaults(fn=cmd_describe)

    p = sub.add_parser("query"); target(p)
    p.add_argument("--sql"); p.add_argument("--file")
    p.add_argument("--timeout", type=int, default=60, help="statement timeout seconds")
    p.add_argument("--write", action="store_true", help="allow DML/DDL (DEV/QA/STG only; needs user approval)")
    p.add_argument("--rollback", action="store_true", help="with --write: run then ROLLBACK (preview row counts)")
    p.set_defaults(fn=cmd_query)

    p = sub.add_parser("env-template"); p.set_defaults(fn=cmd_env_template)

    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
