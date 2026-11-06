#!/usr/bin/env python3
"""health.py — one-shot readiness check for every investigation integration. Never prints secret values.

  python3 health.py                 # offline: which credentials/config are present (booleans) — instant
  python3 health.py --net           # + live read-only probes (parallel, 15s each): HTTP status / cluster health / SSO
  python3 health.py --net --only jira,gitlab,opensearch   # subset
  python3 health.py --json

Integrations: jira · gitlab · figma · opensearch · apex · postgres · aws · slack
Exit: 0 all required OK · 2 something required is missing/failing (details in table). Source ~/.zshenv first.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

SKILLS_DIR = Path(__file__).resolve().parents[2]
TIMEOUT = 15
GITLAB_API = "https://sgts.gitlab-dedicated.com/api/v4"
APEX_URLS = {"stg": "https://gvt-gds-apex-apex-stg.es.ap-southeast-1.aws.found.io",
             "prod": "https://gvt-gds-apex-apex-prod.es.ap-southeast-1.aws.found.io"}

# name → (required env vars, optional?, hint when missing)
CONFIG = {
    "jira": (["JIRA_EMAIL", "JIRA_TOKEN", "JIRA_BASE_URL"], False, "Atlassian API token in ~/.zshenv"),
    "gitlab": (["GITLAB_TOKEN"], False, "GitLab PAT (read_api) in ~/.zshenv"),
    "figma": (["FIGMA_TOKEN"], True, "Figma PAT in ~/.zshenv"),
    "opensearch": (["OPENSEARCH_URL_NONPROD", "OPENSEARCH_URL_PROD"], False, "URLs in ~/.zshenv; VPN needed"),
    "apex": (["APEX_LOG_TOKEN_STAGING", "APEX_LOG_TOKEN_PROD"], True, "APEX Elastic API keys in ~/.zshenv"),
    "postgres": ([], False, "DB_<DB>_<ENV>_* in ~/.zshenv (pg_query.py env-template)"),
    "aws": ([], False, "~/.aws/config profiles staging + prod-elevated"),
    "slack": (["SLACK_TOKEN"], True, "Slack token in ~/.zshenv (used by monorepo slack-search skill)"),
}


def env(name: str) -> str:
    return os.environ.get(name, "").strip()


def http_status(url: str, headers: dict) -> tuple[int, bytes]:
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            return r.status, r.read(4096)
    except urllib.error.HTTPError as e:
        return e.code, b""
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        reason = getattr(e, "reason", e)
        return 0, str(reason).encode()


def verdict(code: int, body: bytes, ok_note: str = "") -> tuple[str, str]:
    if code == 200:
        return "OK", ok_note
    if code in (401, 403):
        return "FAIL", f"HTTP {code} — token expired/invalid or lacks scope"
    if code == 0:
        return "FAIL", f"unreachable ({body.decode(errors='replace')[:80]}) — VPN/network?"
    return "FAIL", f"HTTP {code}"


def probe_jira() -> tuple[str, str]:
    auth = base64.b64encode(f"{env('JIRA_EMAIL')}:{env('JIRA_TOKEN')}".encode()).decode()
    return verdict(*http_status(env("JIRA_BASE_URL").rstrip("/") + "/rest/api/3/myself",
                                {"Authorization": f"Basic {auth}", "Accept": "application/json"}))


def probe_gitlab() -> tuple[str, str]:
    return verdict(*http_status(f"{GITLAB_API}/user", {"PRIVATE-TOKEN": env("GITLAB_TOKEN")}))


def probe_figma() -> tuple[str, str]:
    return verdict(*http_status("https://api.figma.com/v1/me", {"X-Figma-Token": env("FIGMA_TOKEN")}))


def probe_opensearch() -> tuple[str, str]:
    notes, worst = [], "OK"
    for label, var in (("nonprod", "OPENSEARCH_URL_NONPROD"), ("prod", "OPENSEARCH_URL_PROD")):
        code, body = http_status(env(var).rstrip("/") + "/_cluster/health", {})
        if code == 200:
            notes.append(f"{label}={json.loads(body or b'{}').get('status', '?')}")
        else:
            worst = "FAIL"
            notes.append(f"{label}: {verdict(code, body)[1]}")
    return worst, " · ".join(notes)


def probe_apex() -> tuple[str, str]:
    notes, worst = [], "OK"
    for label, var in (("stg", "APEX_LOG_TOKEN_STAGING"), ("prod", "APEX_LOG_TOKEN_PROD")):
        if not env(var):
            notes.append(f"{label}: not set")
            continue
        code, body = http_status(APEX_URLS[label] + "/apigw-traffic-summary*/_count",
                                 {"Authorization": f"ApiKey {env(var)}"})
        if code != 200:
            worst = "FAIL"
        notes.append(f"{label}={'ok' if code == 200 else verdict(code, body)[1]}")
    return worst, " · ".join(notes)


def probe_slack() -> tuple[str, str]:
    code, body = http_status("https://slack.com/api/auth.test", {"Authorization": f"Bearer {env('SLACK_TOKEN')}"})
    if code == 200:
        data = json.loads(body or b"{}")
        return ("OK", "") if data.get("ok") else ("FAIL", f"auth.test: {data.get('error', '?')}")
    return verdict(code, body)


def run(cmd: list[str], timeout: int = 60) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def config_postgres() -> tuple[bool, str]:
    script = SKILLS_DIR / "postgres-query" / "scripts" / "pg_query.py"
    if not script.exists():
        return False, "postgres-query skill not installed"
    r = run([sys.executable, str(script), "check"])
    try:
        rows = json.loads(r.stdout)
    except json.JSONDecodeError:
        return False, (r.stderr.strip() or "pg_query.py check failed")[:120]
    ready = [f"{x['db']}/{x['env']}" for x in rows if x.get("ready")]
    return bool(ready), f"{len(ready)}/{len(rows)} db×env ready"


def probe_postgres() -> tuple[str, str]:
    script = SKILLS_DIR / "postgres-query" / "scripts" / "pg_query.py"
    r = run([sys.executable, str(script), "check", "--db", "licence", "--env", "stg", "--connect"], timeout=45)
    if r.returncode == 0 and "read_only" in r.stdout:
        return "OK", "licence/stg login ok"
    return "FAIL", (r.stderr.strip().splitlines() or ["connect failed — VPN?"])[-1][:120]


def config_aws() -> tuple[bool, str]:
    cfg = Path.home() / ".aws" / "config"
    if not cfg.exists():
        return False, "~/.aws/config missing"
    text = cfg.read_text(errors="replace")
    missing = [p for p in ("staging", "prod-elevated") if f"[profile {p}]" not in text]
    return not missing, f"missing profiles: {', '.join(missing)}" if missing else "profiles staging + prod-elevated"


def probe_aws() -> tuple[str, str]:
    script = SKILLS_DIR / "aws-access" / "scripts" / "aws_ro.sh"
    if not script.exists():
        return "FAIL", "aws-access skill not installed"
    r = run(["bash", str(script), "preflight", "--env", "staging"], timeout=60)
    first = (r.stdout.strip().splitlines() or [""])[0]
    if r.returncode == 0:
        return "OK", first
    if r.returncode == 3:
        return "EXPIRED", "SSO expired — `aws sso login --profile staging` (user approves in browser)"
    return "FAIL", (r.stdout + r.stderr).strip().splitlines()[-1][:120] if (r.stdout + r.stderr).strip() else "preflight failed"


PROBES = {"jira": probe_jira, "gitlab": probe_gitlab, "figma": probe_figma, "opensearch": probe_opensearch,
          "apex": probe_apex, "postgres": probe_postgres, "aws": probe_aws, "slack": probe_slack}
CONFIG_FN = {"postgres": config_postgres, "aws": config_aws}


def check(name: str, net: bool) -> dict:
    vars_, optional, hint = CONFIG[name]
    if name in CONFIG_FN:
        configured, cfg_note = CONFIG_FN[name]()
    else:
        missing = [v for v in vars_ if not env(v)]
        configured = not missing
        cfg_note = "" if configured else f"unset: {', '.join(missing)} — {hint}"
    row = {"name": name, "optional": optional, "configured": configured, "config_note": cfg_note,
           "live": "-", "live_note": ""}
    if net and configured:
        try:
            row["live"], row["live_note"] = PROBES[name]()
        except Exception as e:  # noqa: BLE001 — one broken probe must not hide the others
            row["live"], row["live_note"] = "FAIL", f"probe error: {e}"[:120]
    return row


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--net", action="store_true", help="run live read-only probes")
    p.add_argument("--only", help="comma-separated subset: " + ",".join(CONFIG))
    p.add_argument("--json", action="store_true")
    a = p.parse_args()
    names = [n.strip() for n in a.only.split(",")] if a.only else list(CONFIG)
    unknown = [n for n in names if n not in CONFIG]
    if unknown:
        print(f"ERROR: unknown integration(s): {', '.join(unknown)}", file=sys.stderr)
        sys.exit(1)

    with ThreadPoolExecutor(max_workers=len(names)) as pool:
        rows = list(pool.map(lambda n: check(n, a.net), names))

    bad = [r for r in rows if not r["optional"] and (not r["configured"] or r["live"] in ("FAIL", "EXPIRED"))]
    if a.json:
        print(json.dumps({"ok": not bad, "integrations": rows}, indent=2))
    else:
        print("| Integration | Config | Live | Note |")
        print("|---|---|---|---|")
        for r in rows:
            cfg = "✅" if r["configured"] else ("➖ optional" if r["optional"] else "❌")
            live = {"OK": "✅", "FAIL": "❌", "EXPIRED": "⚠️ expired", "-": "–"}[r["live"]]
            note = r["live_note"] or r["config_note"]
            print(f"| {r['name']} | {cfg} | {live} | {note} |")
        if not a.net:
            print("\n(offline — add --net for live probes)")
    sys.exit(2 if bad else 0)


if __name__ == "__main__":
    main()
