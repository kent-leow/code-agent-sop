#!/usr/bin/env python3
"""validate_docs.py — lint a .docs/ tree against the docs-folder naming convention. Read-only.

  python3 validate_docs.py [--root .docs] [--profile gobiz|general] [--folder <name>] [--json]

Profile defaults to the `**PROFILE: x**` line in this skill's SKILL.md (broadcast-sync rewrites it per variant).
--folder limits the check to one ticket folder (agents run this on their own DOCS_DIR before finishing).
Exit: 0 clean · 1 violations found · 2 bad input.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

SKILL_MD = Path(__file__).resolve().parents[1] / "SKILL.md"
GOBIZ_DIR = re.compile(r"^[A-Z][A-Z0-9]+-[0-9]+-[a-z0-9]+(-[a-z0-9]+)*$")
GENERAL_DIR = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
INVESTIGATION = re.compile(r"^investigation-([a-z0-9]+(?:-[a-z0-9]+)*)$")
HEX_ID = re.compile(r"^(?=[0-9a-f]*[a-f])(?=[0-9a-f]*[0-9])[0-9a-f]{6,}$")
WORD = re.compile(r"^[a-z]{3,}$")
FIX_FILE = re.compile(r"^fix-\d{8}(-\d{6})?-[a-z0-9]+(-[a-z0-9]+)*\.md$")
ALLOWED_ROOT_DIRS = {"archive"}
ALLOWED_ROOT_FILES = {"KNOWN-ISSUES.md"}
MAX_TOPIC_LEN = 60


def default_profile() -> str:
    m = re.search(r"\*\*PROFILE: (\w+)\*\*", SKILL_MD.read_text()) if SKILL_MD.exists() else None
    return m.group(1) if m else "gobiz"


def topic_problem(topic: str) -> str | None:
    words = topic.split("-")
    if len(topic) > MAX_TOPIC_LEN:
        return f"topic longer than {MAX_TOPIC_LEN} chars"
    if any(HEX_ID.match(w) for w in words):
        return "topic contains a hash/ID segment — name the symptom/component; put IDs inside the report"
    if not any(WORD.match(w) for w in words):
        return "topic has no descriptive word (≥3 letters) — e.g. investigation-apex-526-errors"
    if len(words) < 2:
        return "topic needs ≥2 words (symptom + component)"
    return None


def check_folder(folder: Path, issues: list) -> None:
    for child in sorted(folder.iterdir()):
        if child.is_dir() and child.name.startswith("investigation"):
            m = INVESTIGATION.match(child.name)
            problem = topic_problem(m.group(1)) if m else "must match investigation-<kebab-topic>"
            if problem:
                issues.append({"path": str(child), "rule": "investigation-name", "detail": problem})
        if child.is_dir() and child.name == "fixes":
            for f in sorted(child.iterdir()):
                if f.is_file() and f.suffix == ".md" and not FIX_FILE.match(f.name):
                    issues.append({"path": str(f), "rule": "fix-name",
                                   "detail": "must match fix-{YYYYMMDD-HHMMSS}-{kebab-name}.md"})


def validate(root: Path, profile: str, only: str | None) -> list:
    issues: list = []
    dir_re = GOBIZ_DIR if profile == "gobiz" else GENERAL_DIR
    for entry in sorted(root.iterdir()):
        if only and entry.name != only:
            continue
        if entry.name.startswith("."):
            continue
        if entry.is_file():
            if entry.name not in ALLOWED_ROOT_FILES:
                issues.append({"path": str(entry), "rule": "root-file",
                               "detail": "no loose files in .docs/ — move into a ticket folder"})
            continue
        if entry.name in ALLOWED_ROOT_DIRS:
            continue
        if entry.name.startswith(("investigation", "fix-", ".vulnerability")):
            issues.append({"path": str(entry), "rule": "root-artefact",
                           "detail": "artefact folder at .docs/ root — move under its ticket folder"})
        elif not dir_re.match(entry.name):
            want = "<JIRA-KEY>-<kebab-title>" if profile == "gobiz" else "<kebab-title>"
            issues.append({"path": str(entry), "rule": "folder-name", "detail": f"must match {want}"})
        check_folder(entry, issues)
    return issues


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--root", default=".docs")
    p.add_argument("--profile", choices=["gobiz", "general"])
    p.add_argument("--folder", help="only this top-level folder name")
    p.add_argument("--json", action="store_true")
    a = p.parse_args()
    root = Path(a.root)
    if not root.is_dir():
        print(f"ERROR: {root} is not a directory", file=sys.stderr)
        sys.exit(2)
    profile = a.profile or default_profile()
    issues = validate(root, profile, a.folder)
    if a.json:
        print(json.dumps({"profile": profile, "violations": issues}, indent=2))
    elif not issues:
        print(f"OK — {root} follows docs-folder convention (profile {profile})")
    else:
        print(f"{len(issues)} violation(s) in {root} (profile {profile}):")
        for i in issues:
            print(f"- [{i['rule']}] {i['path']} — {i['detail']}")
    sys.exit(1 if issues else 0)


if __name__ == "__main__":
    main()
