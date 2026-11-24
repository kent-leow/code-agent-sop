#!/usr/bin/env python3
"""Publish qa-evidence-testing results to a Jira issue: attach every screenshot/recording, then post ONE
comment (REST v2 wiki markup) that embeds each screenshot as a thumbnail and links each recording, each
with a plain-language caption explaining what it proves.

  preview --manifest M --art DIR                 read-only: validate files, check issue, print the comment
  publish --manifest M --art DIR --confirmed     upload missing attachments, post the comment, write journal

Manifest (JSON):
{
  "issue_key": "CMS-1530",
  "run_id": "CMS-1530-dev-20261124T1445",           # unique per test run; used as duplicate guard
  "title": "QA test evidence — DEV — MR !1251",
  "header": [["MR", "[!1251|https://...]"], ["Env", "DEV @ 472d0a25"]],
  "verdict": "PASS",                                 # PASS | FAIL | BLOCKED
  "verdict_note": "All in-scope ACs pass.",
  "cases": [{
     "tc": "TC-02", "ac": "AC1 — renamed on Corppass → stored name updated", "result": "PASS",   # PASS|FAIL|NA
     "summary": "Logged in as the NEW-name user; company-profile wrote the new name once.",
     "evidence": [{"file": "TC-02-ac1-rename-new-name.mp4", "caption": "Recording: login → dashboard → profile → logout"},
                  {"file": "TC-02-step1-dashboard.png",     "caption": "Dashboard header shows the NEW name"}]
  }],
  "observations": ["Minor: sync fires on every /userInfo/basic call"],
  "footer": "Full report: TEST-REPORT.md"
}

Env: JIRA_BASE_URL, JIRA_EMAIL, JIRA_TOKEN (source ~/.zshenv). Credentials never printed. POST is never
retried (no duplicate attachments/comments); 429 and idempotent GET 5xx are retried with backoff.
"""
from __future__ import annotations

import argparse, base64, json, mimetypes, os, re, sys, time, urllib.error, urllib.request, uuid

TIMEOUT_S, MAX_RETRIES, WARN_BYTES = 120, 3, 10 * 1024 * 1024
ICON = {"PASS": "(/) PASS", "FAIL": "(x) FAIL", "NA": "(i) N/A", "BLOCKED": "(!) BLOCKED"}
IMG = (".png", ".jpg", ".jpeg", ".gif", ".webp")


def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def env(name: str) -> str:
    v = os.environ.get(name, "").strip()
    if not v:
        die(f"{name} is not set — source ~/.zshenv")
    return v


BASE = AUTH = ""


def api(method: str, path: str, body=None, raw: bytes | None = None, headers: dict | None = None):
    hdrs = {"Authorization": AUTH, "Accept": "application/json"}
    data = None
    if body is not None:
        data, hdrs["Content-Type"] = json.dumps(body).encode(), "application/json"
    if raw is not None:
        data = raw
    hdrs.update(headers or {})
    for attempt in range(MAX_RETRIES + 1):
        req = urllib.request.Request(BASE + path, data=data, method=method, headers=hdrs)
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT_S) as resp:
                txt = resp.read().decode()
                return json.loads(txt) if txt else None
        except urllib.error.HTTPError as e:
            retryable = e.code == 429 or (method == "GET" and e.code in (502, 503, 504))
            if not retryable or attempt == MAX_RETRIES:
                die(f"{method} {path} -> HTTP {e.code}: {e.read().decode()[:500]}")
            ra = e.headers.get("Retry-After") or ""
            time.sleep(min(int(ra) if ra.isdigit() else 2 ** attempt, 30))
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            if method != "GET" or attempt == MAX_RETRIES:
                die(f"{method} {path} -> network error: {e} (VPN/network?; a write may or may not have applied "
                    f"— run preview to check)")
            time.sleep(2 ** attempt)


def esc(text: str) -> str:
    """Escape free text so it can't start wiki markup (images !x!, macros {x}, table cells |, links [x])."""
    for ch in ("\\", "|", "{", "}", "!", "[", "]"):
        text = text.replace(ch, "\\" + ch)
    return text.replace("\n", " ")


def load(manifest: str, art: str) -> dict:
    m = json.load(open(manifest))
    for k in ("issue_key", "run_id", "title", "verdict", "cases"):
        if not m.get(k):
            die(f"manifest missing '{k}'")
    if not re.fullmatch(r"[A-Z][A-Z0-9_]+-\d+", m["issue_key"]):
        die(f"invalid issue_key {m['issue_key']}")
    files, seen = [], set()
    for c in m["cases"]:
        if c.get("result", "").upper() not in ICON:
            die(f"{c.get('tc')}: result must be PASS|FAIL|NA|BLOCKED")
        for ev in c.get("evidence", []):
            if not ev.get("caption"):
                die(f"{c['tc']}: evidence {ev.get('file')} has no caption — every file needs an explanation")
            p = os.path.join(art, ev["file"])
            if not os.path.isfile(p):
                die(f"evidence file not found: {p}")
            if ev["file"] not in seen:
                seen.add(ev["file"])
                files.append((ev["file"], p, os.path.getsize(p)))
    m["_files"] = files
    return m


def render(m: dict) -> str:
    # Layout rule: images (!f|width=N!) and links ([t|url]) contain "|" and break wiki TABLE cells,
    # so tables only hold plain text; media goes in numbered evidence items below each TC heading.
    out = [f"h3. {esc(m['title'])}"]
    for k, v in m.get("header", []):
        out.append(f"* *{esc(k)}:* {v}")  # v may contain a [text|url] link — kept raw, bullets are pipe-safe
    out.append(f"\n*Verdict:* {ICON[m['verdict'].upper()]} — {esc(m.get('verdict_note', ''))}\n")
    out.append("||TC||Acceptance criterion||Result||")
    for c in m["cases"]:
        out.append(f"|{esc(c['tc'])}|{esc(c.get('ac', ''))}|{ICON[c['result'].upper()]}|")
    for c in m["cases"]:
        out.append(f"\n----\nh4. {esc(c['tc'])} · {esc(c.get('ac', ''))} — {ICON[c['result'].upper()]}")
        if c.get("summary"):
            out.append(esc(c["summary"]))
        for i, ev in enumerate(c.get("evidence", []), 1):
            f = ev["file"]
            if f.lower().endswith(IMG):
                out.append(f"\n*{i}. Screenshot* — {esc(ev['caption'])}\n!{f}|width=720!")
            else:
                out.append(f"\n*{i}. Recording* (open the attachment to play) — {esc(ev['caption'])}\n[^{f}]")
    if m.get("observations"):
        out.append("\n----\nh4. Observations")
        out += [f"* {esc(o)}" for o in m["observations"]]
    if m.get("footer"):
        out.append(f"\n{esc(m['footer'])}")
    out.append(f"\n{{color:#999999}}qa-evidence-testing run {m['run_id']}{{color}}")
    return "\n".join(out)


def issue_state(key: str, run_id: str) -> tuple[dict, bool]:
    f = api("GET", f"/rest/api/2/issue/{key}?fields=attachment,summary")["fields"]
    attached = {a["filename"]: a for a in f.get("attachment", [])}
    marker = False
    start = 0
    while True:
        page = api("GET", f"/rest/api/2/issue/{key}/comment?startAt={start}&maxResults=100")
        for cm in page.get("comments", []):
            if f"qa-evidence-testing run {run_id}" in (cm.get("body") or ""):
                marker = True
        start += len(page.get("comments", []))
        if start >= page.get("total", 0) or not page.get("comments"):
            break
    return {"summary": f.get("summary"), "attached": attached}, marker


def plan(m: dict, attached: dict) -> tuple[list, list]:
    upload, conflicts = [], []
    for name, path, size in m["_files"]:
        a = attached.get(name)
        if a is None:
            upload.append((name, path, size))
        elif int(a.get("size", -1)) != size:
            conflicts.append(f"{name}: already attached with a different size ({a.get('size')} vs {size}) — rename locally")
    return upload, conflicts


def upload_file(key: str, name: str, path: str) -> dict:
    boundary = uuid.uuid4().hex
    ctype = mimetypes.guess_type(name)[0] or "application/octet-stream"
    with open(path, "rb") as fh:
        content = fh.read()
    payload = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{name}\"\r\n"
               f"Content-Type: {ctype}\r\n\r\n").encode() + content + f"\r\n--{boundary}--\r\n".encode()
    res = api("POST", f"/rest/api/2/issue/{key}/attachments", raw=payload,
              headers={"Content-Type": f"multipart/form-data; boundary={boundary}", "X-Atlassian-Token": "no-check"})
    return res[0] if isinstance(res, list) and res else {}


def main() -> None:
    global BASE, AUTH
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("cmd", choices=["preview", "publish"])
    p.add_argument("--manifest", required=True)
    p.add_argument("--art", required=True, help="artifact directory the manifest's file names are relative to")
    p.add_argument("--confirmed", action="store_true", help="required for publish (user approved the preview)")
    a = p.parse_args()

    BASE = env("JIRA_BASE_URL").rstrip("/")
    AUTH = "Basic " + base64.b64encode(f"{env('JIRA_EMAIL')}:{env('JIRA_TOKEN')}".encode()).decode()
    m = load(a.manifest, a.art)
    key = m["issue_key"]
    journal = a.manifest + ".published.json"

    state, already = issue_state(key, m["run_id"])
    upload, conflicts = plan(m, state["attached"])
    total = sum(s for _, _, s in m["_files"])
    report = {
        "issue": key, "summary": state["summary"], "run_id": m["run_id"],
        "files": len(m["_files"]), "total_mb": round(total / 1048576, 2),
        "to_upload": [n for n, _, _ in upload],
        "already_attached": [n for n, _, _ in m["_files"] if n in state["attached"]],
        "large_files_over_10mb": [n for n, _, s in m["_files"] if s > WARN_BYTES],
        "conflicts": conflicts, "comment_already_posted": already or os.path.exists(journal),
    }

    if a.cmd == "preview":
        print(json.dumps(report, indent=2, ensure_ascii=False))
        print("\n----- comment (Jira wiki markup) -----\n" + render(m))
        return

    if not a.confirmed:
        die("publish requires --confirmed (show the preview to the user and get approval first)")
    if conflicts:
        die("; ".join(conflicts))
    if report["comment_already_posted"]:
        die(f"evidence comment for run {m['run_id']} already exists on {key} (or journal {journal}) — not posting twice")

    done = {"issue": key, "run_id": m["run_id"], "attachments": [], "comment_id": None}
    for name, path, _ in upload:  # sequential; stop on first failure and report what was uploaded
        try:
            att = upload_file(key, name, path)
        except SystemExit:
            print(json.dumps({"partial": done}, indent=2), file=sys.stderr)
            raise
        done["attachments"].append({"filename": name, "id": att.get("id")})
        print(f"attached {name}", file=sys.stderr)
    cm = api("POST", f"/rest/api/2/issue/{key}/comment", body={"body": render(m)})
    done["comment_id"] = cm.get("id")
    done["comment_url"] = f"{BASE}/browse/{key}?focusedCommentId={cm.get('id')}"
    json.dump(done, open(journal, "w"), indent=2)
    print(json.dumps(done, indent=2))


if __name__ == "__main__":
    main()
