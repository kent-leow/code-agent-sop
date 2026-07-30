---
name: fix-vulnerabilities
description: "Fetch and report GitLab security vulnerabilities (critical/high/medium/low) for GOBIZ repos. Requires GITLAB_TOKEN with read_api scope."
argument-hint: '<gitlab-mr-url | repo-name>'
---

# fix-vulnerabilities

Fetch all vulnerability findings (critical-low) from GitLab. No git ops — structured report only.

## Config

- Binaries: `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/mktemp`, `/bin/rm`
- Token: `$GITLAB_TOKEN` (scope: `read_api`)
- Instance: `sgts.gitlab-dedicated.com`

## Repo Map

| Short name | GitLab path (URL-encoded) |
|---|---|
| `molb-agency-portal-web` | `wog%2Fgvt%2Fgobiz%2Fmolb-gobusiness%2Fmolb-agency-portal%2Fmolb-agency-portal-web` |
| `molb-agency-portal-backend` | `wog%2Fgvt%2Fgobiz%2Fmolb-gobusiness%2Fmolb-agency-portal%2Fmolb-agency-portal-backend` |
| `molb-formbuilder-backend` | `wog%2Fgvt%2Fgobiz%2Fmolb-gobusiness%2Fmolb-l1t%2Fmolb-formbuilder-backend` |
| `molb-lab-web` | `wog%2Fgvt%2Fgobiz%2Fmolb-gobusiness%2Fmolb-l1t%2Fmolb-lab-web` |

---

## Steps

1. **Resolve project path**
   - IF: GitLab MR URL → extract + URL-encode project path
   - IF: no URL → ask user to select from repo map
   - STOP: Do not ask about severity, tickets, or branches

2. **Fetch all severities** (paginate until empty)
```bash
tmpfile=$(/usr/bin/mktemp)
all_results="[]"
for SEV in critical high medium low; do
  page=1
  while true; do
    chunk=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
      "https://sgts.gitlab-dedicated.com/api/v4/projects/${PROJECT_PATH}/vulnerability_findings?severity[]=${SEV}&per_page=100&page=${page}")
    count=$(echo "$chunk" | /usr/bin/jq 'length')
    [ "$count" -eq 0 ] && break
    all_results=$(echo "$all_results $chunk" | /usr/bin/jq -s '.[0] + .[1]')
    page=$((page + 1))
  done
done
echo "$all_results" > "$tmpfile"
```
   API note: `state[]=detected` returns 0 on this version; fetch all, filter with jq.

3. **Extract + report**
```bash
/usr/bin/jq '[.[] | select(.state == "detected") | {
  id, name, severity, scanner: .scanner.name,
  file: .location.file, start_line: .location.start_line,
  dependency_pkg: .location.dependency.package.name,
  dependency_ver: .location.dependency.version,
  solution, identifiers: [.identifiers[].name]
}] | group_by(.severity) | map({severity: .[0].severity, count: length, findings: .})' "$tmpfile"
/bin/rm -f "$tmpfile"
```

4. **EMIT summary** — repo, date, counts per severity, full JSON
5. **STOP** — do not apply fixes, run tests, or execute git commands

## Errors

| Symptom | Fix |
|---|---|
| All counts = 0 | Remove `state[]=detected` filter; use jq select |
| 403 | Token needs `read_api` scope |
| Pagination hangs | Cap at page 10 |
