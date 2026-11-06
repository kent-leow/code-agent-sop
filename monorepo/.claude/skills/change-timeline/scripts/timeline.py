#!/usr/bin/env python3
"""timeline.py — "what changed" around an incident, read-only, one chronological table (SGT).

Sources (each optional, failures are reported per source, never fatal):
  deploy   GitLab deployments to <app>/<env> environments (default: success/failed/running/canceled only)
  merge    GitLab MRs merged in the window (with --app: only MRs whose diff touches a path containing it)
  chope    current Occupied cards for the env on the Chope board (via env-chope/scripts/chope_board.py)
  ecs      ECS service deployments + events (via aws-access/scripts/aws_ro.sh; needs a valid SSO session)

Usage:
  python3 timeline.py --env stg --since 6h [--until 2026-11-06T14:00] [--app licence-service]
                      [--project <group/path>] [--ecs] [--no-chope] [--all-statuses] [--json]
  --since/--until: 30m | 6h | 2d | ISO / "YYYY-MM-DD HH:MM" (naive = SGT)

Env: GITLAB_TOKEN (+ JIRA_* for chope); source ~/.zshenv first. Exit 0 = ran (check per-source status), 1 = bad input.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

SGT = timezone(timedelta(hours=8))
GITLAB_API = "https://sgts.gitlab-dedicated.com/api/v4"
DEFAULT_PROJECT = "wog/gvt/gobiz/molb-gobusiness/molb-monorepo"
ENV_SUFFIX = {"dev": "dev", "qa": "qa", "stg": "staging", "prod": "production"}
ENV_ALIASES = {"staging": "stg", "production": "prod"}
AWS_ENV = {"dev": "staging", "qa": "staging", "stg": "staging", "prod": "prod"}
CLUSTER_HINT = {"dev": "dev", "qa": "qa", "stg": "staging", "prod": "prod"}
CHOPE_ENV = {"dev": "dev", "qa": "qa", "stg": "staging"}
REAL_DEPLOY_STATUSES = {"success", "failed", "running", "canceled"}
MAX_PAGES = 10
SKILLS_DIR = Path(__file__).resolve().parents[2]
JIRA_KEY_RE = re.compile(r"\b[A-Z][A-Z0-9]+-\d+\b")


def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def parse_time(value: str, now: datetime) -> datetime:
    m = re.fullmatch(r"(\d+)([mhd])", value.strip())
    if m:
        n, unit = int(m.group(1)), m.group(2)
        return now - {"m": timedelta(minutes=n), "h": timedelta(hours=n), "d": timedelta(days=n)}[unit]
    try:
        dt = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
    except ValueError:
        die(f"bad time '{value}' (use 30m / 6h / 2d / ISO / 'YYYY-MM-DD HH:MM')")
    return dt if dt.tzinfo else dt.replace(tzinfo=SGT)


def to_dt(iso: str | None) -> datetime | None:
    if not iso:
        return None
    return datetime.fromisoformat(iso.replace("Z", "+00:00"))


def sgt(dt: datetime) -> str:
    return dt.astimezone(SGT).strftime("%Y-%m-%d %H:%M")


def gitlab_get(path: str, params: dict) -> list:
    token = os.environ.get("GITLAB_TOKEN", "").strip()
    if not token:
        raise RuntimeError("GITLAB_TOKEN not set (source ~/.zshenv)")
    out = []
    for page in range(1, MAX_PAGES + 1):
        q = urllib.parse.urlencode({**params, "per_page": 100, "page": page})
        req = urllib.request.Request(f"{GITLAB_API}{path}?{q}", headers={"PRIVATE-TOKEN": token})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                batch = json.load(r)
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"GET {path} -> HTTP {e.code}: {e.read()[:200].decode(errors='replace')}") from None
        except urllib.error.URLError as e:
            raise RuntimeError(f"GET {path} -> {e.reason}") from None
        out.extend(batch)
        if len(batch) < 100:
            break
    return out


def source_deploy(a, proj: str, since: datetime, until: datetime) -> list[dict]:
    suffix = "/" + ENV_SUFFIX[a.env]
    deps = gitlab_get(f"/projects/{proj}/deployments", {
        "updated_after": since.astimezone(timezone.utc).isoformat(),
        "updated_before": until.astimezone(timezone.utc).isoformat(),
        "order_by": "updated_at", "sort": "asc"})
    rows = []
    for d in deps:
        env_name = (d.get("environment") or {}).get("name", "")
        if not (env_name.endswith(suffix) or (a.env == "prod" and env_name == "production")):
            continue
        app = env_name.rsplit("/", 1)[0] if "/" in env_name else env_name
        if a.app and a.app not in app:
            continue
        if not a.all_statuses and d.get("status") not in REAL_DEPLOY_STATUSES:
            continue
        job = d.get("deployable") or {}
        when = to_dt(job.get("finished_at")) or to_dt(job.get("started_at")) or to_dt(d.get("created_at"))
        ref = d.get("ref", "")
        mr = re.search(r"merge-requests/(\d+)", ref)
        rows.append({
            "time": when, "source": "deploy", "target": app,
            "event": f"deploy {d.get('status')}",
            "ref": f"!{mr.group(1)}" if mr else ref, "sha": (d.get("sha") or "")[:8],
            "who": (d.get("user") or {}).get("username", ""),
            "link": (job.get("pipeline") or {}).get("web_url") or job.get("web_url", ""),
        })
    return rows


def mr_touches(proj: str, iid: int, needle: str) -> bool:
    diffs = gitlab_get(f"/projects/{proj}/merge_requests/{iid}/diffs", {})
    return any(needle in (f.get("new_path") or "") or needle in (f.get("old_path") or "") for f in diffs)


def source_merge(a, proj: str, since: datetime, until: datetime) -> list[dict]:
    mrs = gitlab_get(f"/projects/{proj}/merge_requests", {
        "state": "merged", "updated_after": since.astimezone(timezone.utc).isoformat(),
        "order_by": "updated_at", "sort": "asc"})
    rows = []
    for m in mrs:
        merged = to_dt(m.get("merged_at"))
        if not merged or not (since <= merged <= until):
            continue
        if a.app and not mr_touches(proj, m["iid"], a.app):
            continue
        keys = sorted(set(JIRA_KEY_RE.findall(f"{m.get('title', '')} {m.get('source_branch', '')}")))
        rows.append({
            "time": merged, "source": "merge", "target": m.get("target_branch", ""),
            "event": f"merged: {m.get('title', '')[:70]}", "ref": f"!{m['iid']}" + (f" {','.join(keys)}" if keys else ""),
            "sha": (m.get("merge_commit_sha") or m.get("squash_commit_sha") or "")[:8],
            "who": (m.get("merged_by") or m.get("author") or {}).get("username", ""), "link": m.get("web_url", ""),
        })
    return rows


def source_chope(a, now: datetime) -> list[dict]:
    if a.env not in CHOPE_ENV:
        return []
    script = SKILLS_DIR / "env-chope" / "scripts" / "chope_board.py"
    if not script.exists():
        raise RuntimeError("env-chope skill not installed")
    r = subprocess.run([sys.executable, str(script), "list", "--env", CHOPE_ENV[a.env]],
                       capture_output=True, text=True, timeout=120)
    if r.returncode != 0:
        raise RuntimeError((r.stderr.strip().splitlines() or [f"exit {r.returncode}"])[-1])
    rows = []
    for c in json.loads(r.stdout):
        if c.get("column") != "Occupied" or (a.app and a.app not in (c.get("app") or "")):
            continue
        rows.append({
            "time": now, "source": "chope", "target": c.get("app", ""),
            "event": f"occupied ({c.get('status')}) {c.get('key')}",
            "ref": ",".join(JIRA_KEY_RE.findall(c.get("summary", ""))),
            "sha": "", "who": c.get("assignee") or "", "link": c.get("url", ""),
        })
    return rows


def aws_ro(env: str, *args: str) -> dict:
    script = SKILLS_DIR / "aws-access" / "scripts" / "aws_ro.sh"
    if not script.exists():
        raise RuntimeError("aws-access skill not installed")
    r = subprocess.run(["bash", str(script), "--env", env, "--", *args, "--output", "json"],
                       capture_output=True, text=True, timeout=180)
    if r.returncode == 3:
        raise RuntimeError("SSO expired — run `aws sso login --profile staging` (user approves in browser)")
    if r.returncode != 0:
        raise RuntimeError((r.stderr.strip().splitlines() or [f"exit {r.returncode}"])[-1])
    return json.loads(r.stdout or "{}")


def source_ecs(a, since: datetime, until: datetime) -> list[dict]:
    if not a.app:
        raise RuntimeError("--ecs needs --app (service name fragment)")
    aws_env, hint = AWS_ENV[a.env], CLUSTER_HINT[a.env]
    clusters = [c for c in aws_ro(aws_env, "ecs", "list-clusters").get("clusterArns", [])
                if hint in c.rsplit("/", 1)[-1]]
    if not clusters:
        raise RuntimeError(f"no ECS cluster name contains '{hint}'")
    rows = []
    for cluster in clusters:
        services = [s for s in aws_ro(aws_env, "ecs", "list-services", "--cluster", cluster).get("serviceArns", [])
                    if a.app in s.rsplit("/", 1)[-1]]
        for i in range(0, len(services), 10):
            desc = aws_ro(aws_env, "ecs", "describe-services", "--cluster", cluster, "--services", *services[i:i + 10])
            for s in desc.get("services", []):
                name = s.get("serviceName", "")
                for d in s.get("deployments", []):
                    t = to_dt(d.get("createdAt"))
                    if t and since <= t <= until:
                        rows.append({"time": t, "source": "ecs", "target": name,
                                     "event": f"deployment {d.get('status')}/{d.get('rolloutState', '')}",
                                     "ref": d.get("taskDefinition", "").rsplit("/", 1)[-1],
                                     "sha": "", "who": "", "link": ""})
                for ev in s.get("events", []):
                    t = to_dt(ev.get("createdAt"))
                    if t and since <= t <= until and "has reached a steady state" not in ev.get("message", ""):
                        rows.append({"time": t, "source": "ecs", "target": name, "event": ev.get("message", "")[:110],
                                     "ref": "", "sha": "", "who": "", "link": ""})
    return rows


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--env", required=True, help="dev | qa | stg | prod")
    p.add_argument("--since", default="24h")
    p.add_argument("--until")
    p.add_argument("--app", help="app/service name fragment, e.g. licence-service")
    p.add_argument("--project", action="append", help=f"GitLab project path (repeatable; default {DEFAULT_PROJECT})")
    p.add_argument("--ecs", action="store_true", help="include ECS deployments/events (needs SSO)")
    p.add_argument("--no-chope", action="store_true")
    p.add_argument("--all-statuses", action="store_true", help="include blocked/created/skipped deployments")
    p.add_argument("--json", action="store_true")
    a = p.parse_args()

    a.env = ENV_ALIASES.get(a.env.lower(), a.env.lower())
    if a.env not in ENV_SUFFIX:
        die("--env must be dev | qa | stg | prod")
    now = datetime.now(timezone.utc)
    since = parse_time(a.since, now)
    until = parse_time(a.until, now) if a.until else now
    if since >= until:
        die("--since must be before --until")

    rows, status = [], {}
    for proj_path in a.project or [DEFAULT_PROJECT]:
        proj = urllib.parse.quote(proj_path, safe="")
        for name, fn in (("deploy", source_deploy), ("merge", source_merge)):
            key = f"{name}:{proj_path.rsplit('/', 1)[-1]}"
            try:
                got = fn(a, proj, since, until)
                rows += got
                status[key] = f"ok ({len(got)})"
            except Exception as e:  # noqa: BLE001 — per-source isolation is the contract
                status[key] = f"FAILED: {e}"
    extra = [] if a.no_chope else [("chope", lambda: source_chope(a, now))]
    if a.ecs:
        extra.append(("ecs", lambda: source_ecs(a, since, until)))
    for name, fn in extra:
        try:
            got = fn()
            rows += got
            status[name] = f"ok ({len(got)})"
        except Exception as e:  # noqa: BLE001
            status[name] = f"FAILED: {e}"

    rows.sort(key=lambda r: r["time"])
    if a.json:
        print(json.dumps({"env": a.env, "since": since.isoformat(), "until": until.isoformat(), "sources": status,
                          "events": [{**r, "time": r["time"].isoformat()} for r in rows]}, indent=2))
        return
    print(f"# Change timeline — {a.env}{f' · {a.app}' if a.app else ''} · {sgt(since)} → {sgt(until)} SGT")
    print("Sources: " + " · ".join(f"{k} {v}" for k, v in status.items()))
    print()
    print("| Time (SGT) | Source | Target | Event | Ref | SHA | Who | Link |")
    print("|---|---|---|---|---|---|---|---|")
    for r in rows:
        t = "now (snapshot)" if r["source"] == "chope" else sgt(r["time"])
        cells = [t, r["source"], r["target"], r["event"], r["ref"], r["sha"], r["who"], r["link"]]
        print("| " + " | ".join(str(c).replace("|", "\\|") for c in cells) + " |")
    if not rows:
        print("| — | — | — | no events in window | | | | |")


if __name__ == "__main__":
    main()
