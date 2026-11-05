#!/usr/bin/env python3
"""Render Jira/Confluence JSON to plain text. Used by the jira-ticket scripts.

  _render.py issue    FILE   issue JSON (fields incl. description, comment) → header + description + comments
  _render.py comments FILE   /comment response → numbered comments
  _render.py media    FILE ATTACH_FILE   → "<safe-name>\t<url>" for inline images present in attachments
  _render.py page     FILE   Confluence content (expand=body.storage,version,space) → header + text
"""
from __future__ import annotations

import html
import json
import re
import sys
from html.parser import HTMLParser

BLOCKS = {"paragraph", "heading", "bulletList", "orderedList", "codeBlock", "blockquote",
          "mediaSingle", "panel", "rule", "table", "expand", "nestedExpand"}


def adf(node, list_prefix: str = "") -> str:
    if not isinstance(node, dict):
        return str(node or "")
    t, attrs, kids = node.get("type", ""), node.get("attrs") or {}, node.get("content") or []
    if t == "text":
        return node.get("text", "")
    if t == "hardBreak":
        return "\n"
    if t in ("mention", "emoji", "status", "date"):
        return attrs.get("text") or attrs.get("shortName") or str(attrs.get("timestamp", ""))
    if t in ("inlineCard", "blockCard", "embedCard"):
        return attrs.get("url", "")
    if t in ("media", "mediaInline"):
        return f"[image: {attrs.get('alt') or attrs.get('id', 'file')}]"
    if t == "heading":
        return "#" * int(attrs.get("level", 1)) + " " + "".join(adf(k) for k in kids) + "\n"
    if t in ("bulletList", "orderedList"):
        out = []
        for i, item in enumerate(kids, 1):
            mark = f"{i}." if t == "orderedList" else "-"
            body = "".join(adf(k) for k in item.get("content") or []).strip()
            out.append(f"{list_prefix}{mark} " + body.replace("\n", "\n" + list_prefix + "  "))
        return "\n".join(out) + "\n"
    if t == "codeBlock":
        return "```\n" + "".join(adf(k) for k in kids) + "\n```\n"
    if t == "table":
        rows = []
        for r in kids:
            cells = ["".join(adf(c) for c in cell.get("content") or []).strip().replace("\n", " ") for cell in r.get("content") or []]
            rows.append("| " + " | ".join(cells) + " |")
        return "\n".join(rows) + "\n"
    if t == "rule":
        return "---\n"
    text = "".join(adf(k) for k in kids)
    if t == "blockquote":
        text = "\n".join("> " + line for line in text.strip().splitlines())
    return text + ("\n" if t in BLOCKS else "")


def load(path: str):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def print_comments(comments: list, total: int | None = None) -> None:
    total = len(comments) if total is None else total
    print(f"=== Comments ({total} total, showing {len(comments)}) ===\n")
    for i, c in enumerate(comments, 1):
        created, updated = (c.get("created") or "")[:10], (c.get("updated") or "")[:10]
        edited = " (edited)" if created != updated else ""
        print(f"[{i}] {(c.get('author') or {}).get('displayName', 'Unknown')} — {created}{edited}  (id: {c.get('id', '')})")
        print("-" * 60)
        print(adf(c.get("body")).strip())
        print()


def cmd_issue(path: str) -> None:
    d = load(path)
    f = d.get("fields") or {}
    name = lambda o: (o or {}).get("name") or (o or {}).get("displayName") or ""
    print(f"{d.get('key')} — {f.get('summary', '')}")
    print(f"Type: {name(f.get('issuetype'))} · Status: {name(f.get('status'))} · Assignee: {name(f.get('assignee')) or 'Unassigned'}")
    if f.get("labels"):
        print("Labels: " + ", ".join(f["labels"]))
    if f.get("parent"):
        print(f"Parent: {f['parent'].get('key')} — {(f['parent'].get('fields') or {}).get('summary', '')}")
    for link in f.get("issuelinks") or []:
        other = link.get("outwardIssue") or link.get("inwardIssue") or {}
        rel = (link.get("type") or {}).get("outward" if "outwardIssue" in link else "inward", "")
        print(f"Link: {rel} {other.get('key')} — {(other.get('fields') or {}).get('summary', '')}")
    for sub in f.get("subtasks") or []:
        print(f"Subtask: {sub.get('key')} — {(sub.get('fields') or {}).get('summary', '')}")
    if f.get("attachment"):
        print("Attachments: " + ", ".join(a.get("filename", "") for a in f["attachment"]))
    print("\n=== Description ===\n")
    print(adf(f.get("description")).strip() or "(empty)")
    comment = f.get("comment")
    if comment and comment.get("comments"):
        print()
        print_comments(comment["comments"], comment.get("total"))


def cmd_comments(path: str) -> None:
    d = load(path)
    print_comments(d.get("comments") or [], d.get("total"))


def cmd_media(path: str, attach_path: str) -> None:
    urls = {a["filename"]: a["content"] for a in (load(attach_path).get("fields") or {}).get("attachment") or []
            if (a.get("mimeType") or "").startswith("image/")}
    seen = set()

    def walk(n):
        if isinstance(n, dict):
            attrs = n.get("attrs") or {}
            if n.get("type") in ("media", "mediaInline") and attrs.get("type") == "file":
                alt = attrs.get("alt", "")
                if alt in urls and alt not in seen:
                    seen.add(alt)
                    print(re.sub(r"[^\w.\- ]", "_", alt) + "\t" + urls[alt])
            for v in n.values():
                walk(v)
        elif isinstance(n, list):
            for v in n:
                walk(v)

    walk(load(path))


class StorageText(HTMLParser):
    """Confluence storage format → readable text (headings, lists, tables, code kept)."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out, self.row, self.cell, self.in_cell, self.lists = [], [], [], False, []

    def emit(self, s):
        (self.cell if self.in_cell else self.out).append(s)

    def handle_starttag(self, tag, attrs):
        if re.fullmatch(r"h[1-6]", tag):
            self.emit("\n\n" + "#" * int(tag[1]) + " ")
        elif tag in ("p", "div", "br"):
            self.emit("\n")
        elif tag in ("ul", "ol"):
            self.lists.append(tag)
        elif tag == "li":
            self.emit("\n" + "  " * (len(self.lists) - 1) + ("1. " if self.lists and self.lists[-1] == "ol" else "- "))
        elif tag == "tr":
            self.row = []
        elif tag in ("td", "th"):
            self.in_cell, self.cell = True, []
        elif tag == "ac:plain-text-body":
            self.emit("\n```\n")
        elif tag == "ri:page":
            self.emit("[page: " + dict(attrs).get("ri:content-title", "") + "]")
        elif tag == "a":
            self.href = dict(attrs).get("href")

    def handle_endtag(self, tag):
        if tag in ("ul", "ol") and self.lists:
            self.lists.pop()
        elif tag in ("td", "th"):
            self.in_cell = False
            self.row.append(" ".join("".join(self.cell).split()))
        elif tag == "tr":
            self.out.append("\n| " + " | ".join(self.row) + " |")
        elif tag == "table":
            self.out.append("\n")
        elif tag == "ac:plain-text-body":
            self.emit("\n```\n")
        elif tag == "a" and getattr(self, "href", None):
            self.emit(f" ({self.href})")
            self.href = None

    def handle_data(self, data):
        self.emit(data)

    def unknown_decl(self, data):  # CDATA inside ac:plain-text-body
        self.emit(data[6:] if data.startswith("CDATA[") else data)

    def text(self):
        return re.sub(r"\n{3,}", "\n\n", html.unescape("".join(self.out))).strip()


def cmd_page(path: str) -> None:
    d = load(path)
    v = d.get("version") or {}
    base = ((d.get("_links") or {}).get("base") or "")
    print(f"{d.get('title')} · page {d.get('id')} · space {(d.get('space') or {}).get('key', '?')}")
    print(f"Version {v.get('number')} · {v.get('when')} · {(v.get('by') or {}).get('displayName', '')}")
    print(f"URL: {base}{(d.get('_links') or {}).get('webui', '')}\n")
    p = StorageText()
    p.feed(((d.get("body") or {}).get("storage") or {}).get("value", ""))
    print(p.text())


if __name__ == "__main__":
    cmd, args = (sys.argv[1], sys.argv[2:]) if len(sys.argv) > 2 else (None, [])
    handlers = {"issue": cmd_issue, "comments": cmd_comments, "media": cmd_media, "page": cmd_page}
    if cmd not in handlers:
        sys.exit(__doc__)
    handlers[cmd](*args)
