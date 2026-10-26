#!/usr/bin/env python3
"""Gobiz Chope Env board (MOLBLT, board 4529) operations.

Subcommands (all print JSON to stdout; errors → stderr + exit 1):
  list    [--ws WS2&WS3] [--env STAGING] [--mine]
  check   --env STAGING --apps a,b [--ws WS2&WS3]
  title   --env STAGING --app molb-x --until "27 OCT 6PM" --flyway yes|no --jira MOLBLT-1
  chope   --key K --env E --app A --until U --flyway yes|no --jira J [--pair-label NAME] [--status "Dev In Progress"]
  release --key K --env E --app A [--remove-label NAME ...] [--status "To Do"] [--force]
  clone   --from K --env E --app A
  attach  --key K --file PATH

Requires JIRA_EMAIL, JIRA_TOKEN, JIRA_BASE_URL.
"""
from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

BOARD_ID = 4529
PROJECT_KEY = "MOLBLT"
BASE_JQL = f"project = {PROJECT_KEY} AND labels = CHOPE"
STANDARD_LABELS = {"CHOPE", "Announcements"}
WS_LABEL_RE = re.compile(r"^WS\d")
ENV_ALIASES = {"DEV": "DEV", "QA": "QA", "STAGING": "STAGING", "STG": "STAGING"}
DEFAULT_OCCUPIED_STATUS = "Dev In Progress"
DEFAULT_AVAILABLE_STATUS = "To Do"
# Monorepo service name -> card name, where the board uses a different name.
APP_ALIASES = {
    "molb-sftp-send-to-edh-job": "molb-send-to-edh-job",
    "onboarding-portal-service": "molb-onboarding-portal-service",
}

BASE_URL = ""
AUTH = ""


def die(msg: str):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def env_or_die(name: str) -> str:
    val = os.environ.get(name, "").strip()
    if not val:
        die(f"{name} is not set (source ~/.zshenv)")
    return val


def init_auth() -> None:
    global BASE_URL, AUTH
    BASE_URL = env_or_die("JIRA_BASE_URL").rstrip("/")
    creds = f"{env_or_die('JIRA_EMAIL')}:{env_or_die('JIRA_TOKEN')}"
    AUTH = "Basic " + base64.b64encode(creds.encode()).decode()


def api(method: str, path: str, body=None, raw: bytes | None = None, headers: dict | None = None):
    hdrs = {"Authorization": AUTH, "Accept": "application/json"}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        hdrs["Content-Type"] = "application/json"
    if raw is not None:
        data = raw
    hdrs.update(headers or {})
    req = urllib.request.Request(BASE_URL + path, data=data, method=method, headers=hdrs)
    try:
        with urllib.request.urlopen(req) as resp:
            txt = resp.read().decode()
            return json.loads(txt) if txt else None
    except urllib.error.HTTPError as e:
        die(f"{method} {path} -> HTTP {e.code}: {e.read().decode()[:500]}")


# ── Title helpers ─────────────────────────────────────────────────────────────

def norm_env(value: str) -> str:
    env = ENV_ALIASES.get(value.strip().upper())
    if not env:
        die(f"unknown env '{value}' (expected DEV|QA|STAGING)")
    return env


def parse_title(summary: str) -> dict:
    tokens = [t.strip() for t in re.findall(r"\[([^\[\]]*)", summary)]
    env = next((ENV_ALIASES[t.upper()] for t in tokens if t.upper() in ENV_ALIASES), None)
    app = next((t for t in tokens if re.fullmatch(r"[a-z][a-z0-9]*(-[a-z0-9]+)+", t)), None)
    return {"env": env, "app": app}


def chope_title(env: str, app: str, until: str, flyway: str, jira: str) -> str:
    if not re.fullmatch(r"\d{1,2} (JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC) \d{1,2}(:\d{2})?(AM|PM)", until):
        die(f"--until must look like '27 OCT 6PM' (got '{until}')")
    if not re.fullmatch(r"[A-Z][A-Z0-9]+-\d+", jira):
        die(f"--jira must be a Jira key (got '{jira}')")
    fw = {"yes": "Yes", "no": "No"}.get(flyway.lower())
    if not fw:
        die("--flyway must be yes|no")
    # House convention, verbatim: no space between app and Until; "Flyway= <Yes|No>".
    return f"[{env}] [{app}][Until {until}] [Flyway= {fw}] [JIRA {jira}]"


def placeholder_title(env: str, app: str) -> str:
    return f"[{env}] [{app}] [Until ???] [Flyway=false] [JIRA ???]"


# ── Board helpers ─────────────────────────────────────────────────────────────

_COLS: dict | None = None


def column_map() -> dict:
    global _COLS
    if _COLS is None:
        cfg = api("GET", f"/rest/agile/1.0/board/{BOARD_ID}/configuration")
        _COLS = {s["id"]: c["name"] for c in cfg["columnConfig"]["columns"] for s in c["statuses"]}
    return _COLS


def fetch_cards(ws: str | None) -> list[dict]:
    cols = column_map()
    jql = BASE_JQL + (f' AND labels = "{ws}"' if ws else "") + " ORDER BY key DESC"
    cards, token = [], None
    while True:
        q = {"jql": jql, "fields": "summary,status,labels,assignee", "maxResults": 100}
        if token:
            q["nextPageToken"] = token
        res = api("GET", "/rest/api/3/search/jql?" + urllib.parse.urlencode(q))
        for i in res.get("issues", []):
            f = i["fields"]
            if "Announcements" in f.get("labels", []):
                continue
            parsed = parse_title(f["summary"])
            cards.append({
                "key": i["key"],
                "url": f"{BASE_URL}/browse/{i['key']}",
                "summary": f["summary"],
                "env": parsed["env"],
                "app": parsed["app"],
                "status": f["status"]["name"],
                "column": cols.get(f["status"]["id"], "NOT_ON_BOARD"),
                "assignee": (f.get("assignee") or {}).get("displayName"),
                "assignee_id": (f.get("assignee") or {}).get("accountId"),
                "labels": f.get("labels", []),
            })
        token = res.get("nextPageToken")
        if res.get("isLast", True) or not token:
            break
    return cards


def card_name_candidates(app: str) -> list[str]:
    names = [app]
    if app in APP_ALIASES:
        names.append(APP_ALIASES[app])
    if not app.startswith("molb-"):
        names.append("molb-" + app)
    return list(dict.fromkeys(names))


def check(env: str, apps: list[str], ws: str) -> dict:
    all_cards = [c for c in fetch_cards(None) if c["column"] != "NOT_ON_BOARD"]
    result, ok = [], True
    for app in apps:
        names = card_name_candidates(app)
        env_cards = [c for c in all_cards if c["env"] == env and c["app"] in names]
        ws_cards = [c for c in env_cards if ws in c["labels"]]
        entry: dict = {"app": app, "card_names_tried": names}
        if not ws_cards:
            other = [c for c in env_cards if ws not in c["labels"]]
            if other:
                entry.update(verdict="other-workstream", cards=other)
            else:
                same_env = [c for c in all_cards if c["env"] == env and ws in c["labels"]]
                entry.update(verdict="missing", clone_source=same_env[0]["key"] if same_env else None)
        elif len(ws_cards) > 1:
            entry.update(verdict="ambiguous", cards=ws_cards)
        else:
            c = ws_cards[0]
            if c["column"] == "Available" and not c["assignee"]:
                entry.update(verdict="available", card=c)
            elif c["column"] == "Available":
                entry.update(verdict="available-but-assigned", card=c)
            else:
                entry.update(verdict="occupied", card=c)
        ok = ok and entry["verdict"] == "available"
        result.append(entry)
    return {"env": env, "workstream": ws, "all_available": ok, "apps": result}


def resolve_transition(key: str, status_name: str) -> str:
    ts = api("GET", f"/rest/api/3/issue/{key}/transitions")["transitions"]
    match = next((t for t in ts if t["to"]["name"].lower() == status_name.lower()), None)
    if not match:
        die(f"{key}: no transition to '{status_name}' (available: {[t['to']['name'] for t in ts]})")
    return match["id"]


def do_transition(key: str, transition_id: str) -> None:
    api("POST", f"/rest/api/3/issue/{key}/transitions", {"transition": {"id": transition_id}})


def get_issue(key: str) -> dict:
    return api("GET", f"/rest/api/3/issue/{key}?fields=summary,status,labels,assignee,attachment,issuetype")


def snapshot(key: str) -> dict:
    f = get_issue(key)["fields"]
    return {
        "key": key,
        "url": f"{BASE_URL}/browse/{key}",
        "summary": f["summary"],
        "status": f["status"]["name"],
        "column": column_map().get(f["status"]["id"], "NOT_ON_BOARD"),
        "assignee": (f.get("assignee") or {}).get("displayName"),
        "labels": f.get("labels", []),
        "attachments": [a["filename"] for a in f.get("attachment", [])],
    }


def assert_card_matches(key: str, env: str, app: str) -> dict:
    f = get_issue(key)["fields"]
    parsed = parse_title(f["summary"])
    if parsed["env"] != env or parsed["app"] not in card_name_candidates(app):
        die(f"{key} title '{f['summary']}' does not match env={env} app={app}")
    return f


# ── Commands ──────────────────────────────────────────────────────────────────

def cmd_chope(a) -> dict:
    env = norm_env(a.env)
    f = assert_card_matches(a.key, env, a.app)
    if column_map().get(f["status"]["id"]) != "Available":
        die(f"{a.key} is not in Available (status '{f['status']['name']}') — refusing to chope")
    if f.get("assignee"):
        die(f"{a.key} is assigned to {f['assignee']['displayName']} — refusing to chope")
    summary = chope_title(env, parse_title(f["summary"])["app"], a.until, a.flyway, a.jira)
    tid = resolve_transition(a.key, a.status)
    me = api("GET", "/rest/api/3/myself")["accountId"]
    body: dict = {"fields": {"summary": summary, "assignee": {"accountId": me}}}
    if a.pair_label:
        body["update"] = {"labels": [{"add": a.pair_label}]}
    api("PUT", f"/rest/api/3/issue/{a.key}", body)
    do_transition(a.key, tid)
    return snapshot(a.key)


def cmd_release(a) -> dict:
    env = norm_env(a.env)
    f = assert_card_matches(a.key, env, a.app)
    me = api("GET", "/rest/api/3/myself")["accountId"]
    owner = (f.get("assignee") or {}).get("accountId")
    if owner != me and not a.force:
        who = f["assignee"]["displayName"] if owner else "nobody"
        die(f"{a.key} is assigned to {who}, not you — pass --force only if the user confirmed")
    if column_map().get(f["status"]["id"]) != "Occupied" and not a.force:
        die(f"{a.key} is not in Occupied (status '{f['status']['name']}') — nothing to release")
    labels = f.get("labels", [])
    missing = [l for l in a.remove_label if l not in labels]
    if missing:
        die(f"{a.key} has no label(s) {missing}; current labels: {labels}")
    tid = resolve_transition(a.key, a.status)
    body: dict = {"fields": {"summary": placeholder_title(env, parse_title(f["summary"])["app"]), "assignee": None}}
    if a.remove_label:
        body["update"] = {"labels": [{"remove": l} for l in a.remove_label]}
    api("PUT", f"/rest/api/3/issue/{a.key}", body)
    do_transition(a.key, tid)
    removed = []
    for att in f.get("attachment", []):
        if re.fullmatch(r"cleanup-.*\.sql", att["filename"]):
            api("DELETE", f"/rest/api/3/attachment/{att['id']}")
            removed.append(att["filename"])
    kept = [l for l in labels if l not in a.remove_label and l not in STANDARD_LABELS and not WS_LABEL_RE.match(l)]
    return snapshot(a.key) | {"removed_labels": a.remove_label, "other_labels_kept": kept,
                              "removed_attachments": removed}


def cmd_clone(a) -> dict:
    env = norm_env(a.env)
    src_key = getattr(a, "from")
    src = get_issue(src_key)["fields"]
    if "Announcements" in src.get("labels", []):
        die("never clone the ReadMe/Announcements card")
    if parse_title(src["summary"])["env"] != env:
        die(f"clone source must be a same-env ({env}) card; got '{src['summary']}'")
    labels = [l for l in src.get("labels", []) if l in STANDARD_LABELS or WS_LABEL_RE.match(l)]
    body = {"fields": {
        "project": {"key": PROJECT_KEY},
        "issuetype": {"id": src["issuetype"]["id"]},
        "summary": placeholder_title(env, a.app),
        "labels": labels,
    }}
    created = api("POST", "/rest/api/3/issue", body)
    return snapshot(created["key"]) | {"cloned_from": src_key}


def cmd_attach(a) -> dict:
    if not os.path.isfile(a.file):
        die(f"file not found: {a.file}")
    boundary = uuid.uuid4().hex
    name = os.path.basename(a.file)
    ctype = mimetypes.guess_type(name)[0] or "text/plain"
    with open(a.file, "rb") as fh:
        content = fh.read()
    payload = (
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{name}\"\r\n"
        f"Content-Type: {ctype}\r\n\r\n"
    ).encode() + content + f"\r\n--{boundary}--\r\n".encode()
    api("POST", f"/rest/api/3/issue/{a.key}/attachments", raw=payload, headers={
        "Content-Type": f"multipart/form-data; boundary={boundary}",
        "X-Atlassian-Token": "no-check",
    })
    return snapshot(a.key)


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("list")
    s.add_argument("--ws", default="WS2&WS3")
    s.add_argument("--env")
    s.add_argument("--mine", action="store_true", help="only cards assigned to you")
    s = sub.add_parser("check")
    s.add_argument("--env", required=True)
    s.add_argument("--apps", required=True, help="comma-separated app/service names")
    s.add_argument("--ws", default="WS2&WS3")
    s = sub.add_parser("title")
    for k in ("env", "app", "until", "flyway", "jira"):
        s.add_argument(f"--{k}", required=True)
    s = sub.add_parser("chope")
    for k in ("key", "env", "app", "until", "flyway", "jira"):
        s.add_argument(f"--{k}", required=True)
    s.add_argument("--pair-label")
    s.add_argument("--status", default=DEFAULT_OCCUPIED_STATUS)
    s = sub.add_parser("release")
    for k in ("key", "env", "app"):
        s.add_argument(f"--{k}", required=True)
    s.add_argument("--remove-label", action="append", default=[], help="pair-partner label to remove (repeatable)")
    s.add_argument("--status", default=DEFAULT_AVAILABLE_STATUS)
    s.add_argument("--force", action="store_true")
    s = sub.add_parser("clone")
    s.add_argument("--from", required=True)
    s.add_argument("--env", required=True)
    s.add_argument("--app", required=True)
    s = sub.add_parser("attach")
    s.add_argument("--key", required=True)
    s.add_argument("--file", required=True)

    a = p.parse_args()
    if a.cmd == "title":
        out = {"summary": chope_title(norm_env(a.env), a.app, a.until, a.flyway, a.jira)}
    else:
        init_auth()
        if a.cmd == "list":
            env = norm_env(a.env) if a.env else None
            me = api("GET", "/rest/api/3/myself")["accountId"] if a.mine else None
            out = [c for c in fetch_cards(a.ws) if (not env or c["env"] == env) and (not me or c["assignee_id"] == me)]
        elif a.cmd == "check":
            out = check(norm_env(a.env), [x.strip() for x in a.apps.split(",") if x.strip()], a.ws)
        else:
            out = {"chope": cmd_chope, "release": cmd_release, "clone": cmd_clone, "attach": cmd_attach}[a.cmd](a)
    print(json.dumps(out, indent=2))


if __name__ == "__main__":
    main()
