---
name: fix-vulnerabilities
description: "Fetch and report GitLab security vulnerabilities (critical/high/medium/low) for GOBIZ repos. Requires GITLAB_TOKEN with read_api scope."
argument-hint: '<gitlab-mr-url | repo-name>'
---

# fix-vulnerabilities

Fetch all vulnerability findings (critical-low) from GitLab. No git ops — structured report only.

## Sandbox Note

All `curl`/`jq` commands run with `dangerouslyDisableSandbox: true`.
Use absolute paths: `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/mktemp`, `/bin/rm`.

---

## Prerequisite

- DO: Check token
```bash
echo "Token: $([ -n "$GITLAB_TOKEN" ] && echo YES || echo MISSING)"
```
Scope needed: `read_api`. Create at `sgts.gitlab-dedicated.com → User Settings → Access Tokens`.

---

## Repo Map

| Short name | Local path | GitLab project path (URL-encoded) |
|---|---|---|
| `molb-agency-portal-web` | `molb-agency-portal-web/` | `wog%2Fgvt%2Fgobiz%2Fmolb-gobusiness%2Fmolb-agency-portal%2Fmolb-agency-portal-web` |
| `molb-agency-portal-backend` | `molb-agency-portal-backend/` | `wog%2Fgvt%2Fgobiz%2Fmolb-gobusiness%2Fmolb-agency-portal%2Fmolb-agency-portal-backend` |
| `molb-formbuilder-backend` | `molb-formbuilder-backend/` | `wog%2Fgvt%2Fgobiz%2Fmolb-gobusiness%2Fmolb-l1t%2Fmolb-formbuilder-backend` |
| `molb-lab-web` | `molb-lab-web/` | `wog%2Fgvt%2Fgobiz%2Fmolb-gobusiness%2Fmolb-l1t%2Fmolb-lab-web` |

---

## Steps

- DO: Resolve project path
  - IF: GitLab MR URL provided → extract project path from URL, URL-encode it
    ```
    https://sgts.gitlab-dedicated.com/<namespace>/<repo>/-/merge_requests/<id>
    → PROJECT_PATH = URL-encode("<namespace>/<repo>")
    ```
  - IF: No URL → ask user to select repo from table (one question only)
  - STOP: Do not ask about severity, Jira tickets, or branch names

- DO: Fetch all severities in one pass (paginate until empty)
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
API note: `state[]=detected` and `scope=detected` return 0 in this GitLab version. Fetch all, filter with jq.

- DO: Extract details and output report
```bash
/usr/bin/jq '[.[] | select(.state == "detected") | {
  id,
  name,
  severity,
  state,
  scanner: .scanner.name,
  file: .location.file,
  start_line: .location.start_line,
  dependency_pkg: .location.dependency.package.name,
  dependency_ver: .location.dependency.version,
  fixed_version: (.identifiers[] | select(.type == "semver") | .value) // null,
  solution,
  description,
  identifiers: [.identifiers[].name],
  links: [.links[].url]
}] | group_by(.severity) | map({
  severity: .[0].severity,
  count: length,
  findings: .
})' "$tmpfile"

/bin/rm -f "$tmpfile"
```

- EMIT: Print summary
```
Vulnerability report — <repo> — <YYYY-MM-DD>

CRITICAL: <N>
HIGH:     <N>
MEDIUM:   <N>
LOW:      <N>
TOTAL:    <N> detected

<Full JSON output>
```

- STOP: Do not apply fixes, run tests, run builds, or execute any git commands.

---

## Errors

| Symptom | Fix |
|---|---|
| All counts = 0 | Remove `state[]=detected` filter; use jq select instead |
| 403 on API | Token needs `read_api` scope |
| Pagination loop hangs | Cap at page 10 as safety limit |
