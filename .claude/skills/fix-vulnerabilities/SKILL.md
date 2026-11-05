---
name: fix-vulnerabilities
description: "Fetch and report GitLab security vulnerabilities (critical/high/medium/low) for GOBIZ repos. Requires GITLAB_TOKEN with read_api scope."
argument-hint: '<gitlab-mr-url | repo-name>'
---

# fix-vulnerabilities

Fetch every vulnerability finding (critical → low) from GitLab and emit a structured report. Read-only; no git ops.

## Config

| Item | Value |
|---|---|
| Instance | `https://sgts.gitlab-dedicated.com/api/v4` |
| Token | `$GITLAB_TOKEN` (`read_api`); network escalation required |
| Binaries | `/usr/bin/curl`, `/usr/bin/jq` |

| Short name | Project path (URL-encoded) |
|---|---|
| `molb-agency-portal-web` | `wog%2Fgvt%2Fgobiz%2Fmolb-gobusiness%2Fmolb-agency-portal%2Fmolb-agency-portal-web` |
| `molb-agency-portal-backend` | `wog%2Fgvt%2Fgobiz%2Fmolb-gobusiness%2Fmolb-agency-portal%2Fmolb-agency-portal-backend` |
| `molb-formbuilder-backend` | `wog%2Fgvt%2Fgobiz%2Fmolb-gobusiness%2Fmolb-l1t%2Fmolb-formbuilder-backend` |
| `molb-lab-web` | `wog%2Fgvt%2Fgobiz%2Fmolb-gobusiness%2Fmolb-l1t%2Fmolb-lab-web` |

## Steps

1. **Resolve `PROJECT_PATH`** — MR URL → URL-encode the path before `/-/`; else ask user to pick from the map. Don't ask about severity, tickets, or branches.

2. **Fetch + report** (single invocation; fails loudly on any non-200, caps at 10 pages/severity):
```bash
source ~/.zshenv; : "${GITLAB_TOKEN:?GITLAB_TOKEN not set}"
API="https://sgts.gitlab-dedicated.com/api/v4/projects/${PROJECT_PATH}/vulnerability_findings"
OUT=$(/usr/bin/mktemp -d); trap '/bin/rm -rf "$OUT"' EXIT; echo '[]' > "$OUT/all.json"
for SEV in critical high medium low; do
  for page in $(seq 1 10); do
    code=$(/usr/bin/curl --silent --show-error --connect-timeout 10 --max-time 60 --retry 3 \
      -K <(printf 'header = "PRIVATE-TOKEN: %s"\n' "$GITLAB_TOKEN") -o "$OUT/p.json" -w '%{http_code}' \
      "$API?severity[]=${SEV}&per_page=100&page=${page}") || true
    [ "$code" = 200 ] || { echo "ERROR: $SEV page $page -> HTTP $code: $(head -c 300 "$OUT/p.json")" >&2; exit 1; }
    [ "$(/usr/bin/jq length "$OUT/p.json")" -eq 0 ] && break
    /usr/bin/jq -s '.[0] + .[1]' "$OUT/all.json" "$OUT/p.json" > "$OUT/t.json" && mv "$OUT/t.json" "$OUT/all.json"
  done
done
/usr/bin/jq '[.[] | select(.state == "detected") | {id, name, severity, scanner: .scanner.name,
  file: .location.file, start_line: .location.start_line,
  dependency_pkg: .location.dependency.package.name, dependency_ver: .location.dependency.version,
  solution, identifiers: [.identifiers[].name]}]
  | group_by(.severity) | map({severity: .[0].severity, count: length, findings: .})' "$OUT/all.json"
```
`state[]=detected` returns 0 on this GitLab version → fetch all, filter with jq (as above).

3. **EMIT** — repo, date, counts per severity, full JSON. **STOP**: no fixes, tests, or git commands.

## Errors

| Symptom | Fix |
|---|---|
| HTTP 401 / 403 | token invalid / lacks `read_api` |
| HTTP 404 | wrong/unencoded `PROJECT_PATH` or no access |
| `Could not resolve host` | sandbox — rerun with network escalation |
| All counts 0 | confirm security scanning runs on the default branch |
