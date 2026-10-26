#!/usr/bin/env python3
"""Analyse a GitLab MR for env-chope: touched apps, Flyway migrations (per env), Jira keys.

Usage: python3 mr_impact.py --mr <gitlab MR URL> [--env DEV|QA|STAGING]

Monorepo MRs: changed paths are mapped to services via service-graph.json at the MR head SHA.
Standalone repos: the project's last path segment is the app.
Prints JSON. Requires GITLAB_TOKEN.
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

ENVS = {"DEV": "dev", "QA": "qa", "STAGING": "staging", "STG": "staging"}
JIRA_KEY_RE = re.compile(r"\b[A-Z][A-Z0-9]+-\d+\b")
MR_URL_RE = re.compile(r"^https://([^/]+)/(.+?)/-/merge_requests/(\d+)")
DIFF_TEXT_LIMIT = 20000


def die(msg: str):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


class GitLab:
    def __init__(self, host: str, project: str):
        token = os.environ.get("GITLAB_TOKEN", "").strip()
        if not token:
            die("GITLAB_TOKEN is not set (source ~/.zshenv)")
        self.base = f"https://{host}/api/v4/projects/{urllib.parse.quote(project, safe='')}"
        self.headers = {"PRIVATE-TOKEN": token}

    def get(self, path: str, raw: bool = False, allow_404: bool = False):
        req = urllib.request.Request(self.base + path, headers=self.headers)
        try:
            with urllib.request.urlopen(req) as resp:
                body = resp.read().decode()
                return (body if raw else json.loads(body)), resp.headers
        except urllib.error.HTTPError as e:
            if allow_404 and e.code == 404:
                return None, None
            die(f"GET {path} -> HTTP {e.code}: {e.read().decode()[:300]}")

    def file(self, path: str, ref: str) -> str | None:
        enc = urllib.parse.quote(path, safe="")
        body, _ = self.get(f"/repository/files/{enc}/raw?ref={urllib.parse.quote(ref)}", raw=True, allow_404=True)
        return body

    def diffs(self, iid: str) -> list[dict]:
        out, page = [], "1"
        while page:
            data, hdrs = self.get(f"/merge_requests/{iid}/diffs?per_page=100&page={page}")
            out.extend(data)
            page = hdrs.get("x-next-page") if hdrs else None
        return out


def is_migration(rel: str) -> bool:
    if "/src/test/" in f"/{rel}" or "/src/apiTest/" in f"/{rel}":
        return False
    if rel.startswith("src/main/") and "/db/migration/" in rel and rel.endswith((".sql", ".kt", ".java")):
        return True
    # Django migrations (onboarding-portal-service) — DB schema change, reported as Flyway= Yes.
    return "/migrations/" in f"/{rel}" and rel.endswith(".py") and not rel.endswith("__init__.py")


UNRESOLVED = object()


def parse_flyway_locations(text: str):
    """Locations under a `flyway:` block (or flat `*flyway.locations`).

    Returns list of classpath folders, None if not present, or UNRESOLVED when present
    but not statically resolvable (placeholders, wildcards, non-classpath schemes).
    """
    lines = text.splitlines()
    values: list[str] | None = None
    fly_indent = None
    for i, line in enumerate(lines):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        flat = re.match(r"^\s*(?:spring\.)?flyway\.locations:\s*(.*)$", line)
        if fly_indent is not None and indent <= fly_indent:
            fly_indent = None
        if re.match(r"^\s*flyway:\s*(#.*)?$", line):
            fly_indent = indent
            continue
        nested = fly_indent is not None and re.match(r"^\s*locations:\s*(.*)$", line)
        m = flat or nested
        if not m:
            continue
        raw = m.group(1).split(" #")[0].strip()
        if raw:
            values = raw.strip("[]").split(",")
        else:
            values = []
            for nxt in lines[i + 1:]:
                item = re.match(r"^\s*-\s*(.+)$", nxt)
                if not item:
                    break
                values.append(item.group(1))
    if values is None:
        return None
    locs = []
    for v in values:
        v = v.strip().strip("'\"")
        if not v:
            continue
        if "${" in v or "*" in v or "{" in v:
            return UNRESOLVED
        if ":" in v and not v.startswith("classpath:"):
            return UNRESOLVED
        locs.append(v.removeprefix("classpath:").strip("/"))
    return locs or UNRESOLVED


def flyway_locations(gl: GitLab, svc_path: str, env: str, ref: str) -> list[str] | None:
    """Literal flyway locations for env (most specific config first), or None when unresolvable."""
    prefix = f"{svc_path}/" if svc_path else ""
    for cfg in (f"src/main/resources/application-{env}.yml", f"src/main/resources/application-{env}.yaml",
                "config/application-deploy.yml", "src/main/resources/application.yml",
                "src/main/resources/application.yaml"):
        text = gl.file(prefix + cfg, ref)
        if not text:
            continue
        locs = parse_flyway_locations(text)
        if locs is UNRESOLVED:
            return None
        if locs:
            return locs
    return None


def migration_applies(rel: str, locs: list[str] | None) -> bool | None:
    if locs is None or not rel.startswith("src/main/resources/"):
        return None
    folder = rel.removeprefix("src/main/resources/").rsplit("/", 1)[0]
    return any(folder == l or folder.startswith(l + "/") for l in locs)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--mr", required=True)
    p.add_argument("--env", help="DEV|QA|STAGING; default = all three")
    a = p.parse_args()

    m = MR_URL_RE.match(a.mr.strip())
    if not m:
        die("not a GitLab MR URL (https://<host>/<group>/<project>/-/merge_requests/<iid>)")
    host, project, iid = m.groups()
    envs = [a.env.upper()] if a.env else ["DEV", "QA", "STAGING"]
    for e in envs:
        if e not in ENVS:
            die(f"unknown env {e}")
    envs = list(dict.fromkeys("STAGING" if e == "STG" else e for e in envs))

    gl = GitLab(host, project)
    mr, _ = gl.get(f"/merge_requests/{iid}")
    ref = mr["sha"]
    diffs = gl.diffs(iid)
    paths = sorted({d["new_path"] for d in diffs} | {d["old_path"] for d in diffs})
    diff_by_path = {d["new_path"]: d for d in diffs}

    graph_txt = gl.file("service-graph.json", ref)
    services, packages, unmapped = {}, {}, []
    if graph_txt:
        graph = json.loads(graph_txt)
        svc_list = sorted(graph["services"], key=lambda s: -len(s["path"]))
        pkg_list = graph.get("packages", [])
        for path in paths:
            svc = next((s for s in svc_list if path.startswith(s["path"] + "/")), None)
            if svc:
                services.setdefault(svc["name"], {"svc": svc, "files": []})["files"].append(path)
                continue
            pkg = next((pk for pk in pkg_list if pk.get("path") and path.startswith(pk["path"] + "/")), None)
            if pkg:
                packages.setdefault(pkg["name"], set()).add(path)
            else:
                unmapped.append(path)
        consumers = {pk: sorted(s["name"] for s in graph["services"] if pk in s.get("consumes_packages", []))
                     for pk in packages}
    else:
        name = project.rsplit("/", 1)[-1]
        services[name] = {"svc": {"name": name, "path": "", "runtime_service_name": None}, "files": paths}
        consumers = {}

    apps = []
    for name, info in sorted(services.items()):
        svc_path = info["svc"]["path"]
        rels = [(f, f.removeprefix(svc_path + "/") if svc_path else f) for f in info["files"]]
        migs = [(f, r) for f, r in rels if is_migration(r)]
        flyway = {}
        for env in envs:
            if not migs:
                flyway[env] = {"value": "No", "reason": "no migration files changed"}
                continue
            locs = flyway_locations(gl, svc_path, ENVS[env], ref)
            verdicts = [migration_applies(r, locs) for _, r in migs]
            if None in verdicts:
                flyway[env] = {"value": "Yes", "locations": locs,
                               "reason": "migration changed; env applicability unresolved → conservative Yes"}
            elif True in verdicts:
                flyway[env] = {"value": "Yes", "reason": "migration in env flyway locations", "locations": locs}
            else:
                flyway[env] = {"value": "No", "reason": "migrations only outside env flyway locations",
                               "locations": locs}
        apps.append({
            "name": name,
            "runtime_service_name": info["svc"].get("runtime_service_name"),
            "path": svc_path,
            "changed_files": len(info["files"]),
            "flyway": flyway,
            "migration_files": [{
                "path": f,
                "new_file": diff_by_path.get(f, {}).get("new_file"),
                "deleted_file": diff_by_path.get(f, {}).get("deleted_file"),
                "diff": (diff_by_path.get(f, {}).get("diff") or "")[:DIFF_TEXT_LIMIT],
            } for f, _ in migs],
        })

    text = " ".join([mr.get("source_branch") or "", mr.get("title") or "", mr.get("description") or ""])
    print(json.dumps({
        "mr": {k: mr.get(k) for k in ("web_url", "title", "state", "source_branch", "target_branch", "sha")},
        "jira_keys": list(dict.fromkeys(JIRA_KEY_RE.findall(text))),
        "apps": apps,
        "packages": [{"name": k, "files": sorted(v), "consumers": consumers.get(k, [])} for k, v in packages.items()],
        "unmapped_paths": unmapped,
    }, indent=2))


if __name__ == "__main__":
    main()
