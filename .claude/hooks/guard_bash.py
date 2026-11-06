#!/usr/bin/env python3
"""guard_bash.py — Claude Code PreToolUse hook (matcher: Bash). Denies commands that would leak secrets or
bypass the read-only guards of the integration skills. Silent (exit 0, no output) = no decision.

Rules (each deny explains the sanctioned alternative):
  token-argv     curl -H/--header or -u/--user built from a $…TOKEN/PASSWORD/SECRET/API_KEY var (visible in ps)
  token-echo     echo of a secret var (prints it into the transcript); `[ -n "$X" ]` presence checks are fine
  aws-prod-raw   raw `aws` against a prod profile instead of aws-access/scripts/aws_ro.sh
  psql-prod-raw  raw psql using DB_*_PROD_* vars instead of postgres-query/scripts/pg_query.py
  pg-prod-write  pg_query.py --env prod with --write
  os-prod-write  PUT/DELETE/PATCH/POST (non-search) against the prod OpenSearch cluster
"""
from __future__ import annotations

import json
import re
import sys

SECRET_VAR = r"\$\{?[A-Z0-9_]*(?:TOKEN|PASSWORD|SECRET|API_KEY)[A-Z0-9_]*\}?"
RULES = [
    ("token-argv",
     re.compile(r"(?:\s-H|\s--header)\s*=?\s*[\"']?[^\"'\n]*" + SECRET_VAR),
     "Token would appear on curl argv (visible in `ps`). Use a curl config on an fd: "
     "-K <(printf 'header = \"PRIVATE-TOKEN: %s\"\\n' \"$GITLAB_TOKEN\") — see git-apis Auth."),
    ("token-argv",
     re.compile(r"(?:\s-u|\s--user)\s*=?\s*[\"']?[^\"'\s]*" + SECRET_VAR),
     "Credentials would appear on curl argv. Use -K <(printf 'user = \"%s:%s\"\\n' \"$JIRA_EMAIL\" \"$JIRA_TOKEN\") "
     "or the jira-ticket scripts."),
    ("aws-prod-raw",
     re.compile(r"(?:^|[;&|(]\s*|\s)aws\s+(?!sso\s+login)[^\n]*--profile[\s=]+(?:prod-elevated|production|prod-paws-operator)\b"),
     "Raw AWS CLI against production. Use bash .claude/skills/aws-access/scripts/aws_ro.sh --env prod -- <service> <op> "
     "(read-only guard; prod writes need the user to confirm twice)."),
    ("aws-prod-raw",
     re.compile(r"\bAWS_PROFILE=(?:prod-elevated|production|prod-paws-operator)\b"),
     "Never set AWS_PROFILE for production — use aws_ro.sh --env prod (aws-access skill)."),
    ("psql-prod-raw",
     re.compile(r"\bpsql\b[^\n]*\$\{?DB_[A-Z_]+_PROD_"),
     "Raw psql against PROD. Use python3 .claude/skills/postgres-query/scripts/pg_query.py query --env prod "
     "(enforces BEGIN READ ONLY)."),
    ("pg-prod-write",
     re.compile(r"pg_query\.py\b(?=[^\n]*--env[\s=]+prod\b)(?=[^\n]*--write\b)"),
     "PROD is strictly read-only (postgres-query skill). Writes are only allowed on DEV/QA/STG after explicit approval."),
    ("os-prod-write",
     re.compile(r"\bcurl\b(?=[^\n]*(?:opensearch\.molbproject\.io|\$\{?OPENSEARCH_URL_PROD))"
                r"(?=[^\n]*(?:-X\s*|--request\s+)(?:PUT|DELETE|PATCH|POST)\b)"
                r"(?![^\n]*/_(?:search|count|msearch|plugins/_sql)\b)"),
     "Write request to PROD OpenSearch. Logs are read-only — use opensearch-logs/scripts/os_query.py."),
]
ECHO_SEGMENT = re.compile(r"\becho\b[^\n|;&]*")
PRESENCE_TEST = re.compile(r"-[nz]\s+[\"']?" + SECRET_VAR)


def echo_leaks(cmd: str) -> bool:
    return any(re.search(SECRET_VAR, PRESENCE_TEST.sub("", seg)) for seg in ECHO_SEGMENT.findall(cmd))


def decide(cmd: str) -> tuple[str, str] | None:
    for rule, rx, reason in RULES:
        if rx.search(cmd):
            return rule, reason
    if echo_leaks(cmd):
        return "token-echo", "Never print secret values. Check presence only: [ -n \"$GITLAB_TOKEN\" ] && echo set."
    return None


def deny(reason: str) -> None:
    json.dump({"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny",
                                      "permissionDecisionReason": reason}}, sys.stdout)


def main() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)
    try:
        cmd = (payload.get("tool_input") or {}).get("command") or ""
        hit = decide(cmd)
    except Exception as e:  # noqa: BLE001 — fail closed: a broken guard must not silently allow everything
        deny(f"[guard:error] guard_bash.py failed ({type(e).__name__}: {e}); fix the hook or ask the user")
        return
    if hit:
        rule, reason = hit
        deny(f"[guard:{rule}] {reason}")


if __name__ == "__main__":
    main()
