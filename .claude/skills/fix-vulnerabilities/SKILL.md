---
name: fix-vulnerabilities
description: Use when fixing GitLab security vulnerabilities in GOBIZ repos
metadata:
  category: security
  tier: advanced
  status: active
  invocation: user-initiated
---

# Fix Vulnerabilities — Fetch All Vulnerability Details

Pull all vulnerability findings (critical, high, medium, low) from a GitLab project via MR URL or repo selection. No git operations, no commits — output is a structured vulnerability report only.

---

## Sandbox Note

All `curl`/`jq` commands **must** run with `dangerouslyDisableSandbox: true`.
Use absolute paths: `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/mktemp`, `/bin/rm`.

---

## Prerequisite: `$GITLAB_TOKEN`

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

## Step 1: Resolve project path

**If a GitLab MR URL is provided**, auto-extract the project path from the URL:

```
https://sgts.gitlab-dedicated.com/<namespace>/<repo>/-/merge_requests/<id>
→ PROJECT_PATH = URL-encode("<namespace>/<repo>")
```

Example:
```
https://sgts.gitlab-dedicated.com/wog/gvt/gobiz/molb-gobusiness/molb-agency-portal/molb-agency-portal-web/-/merge_requests/42
→ PROJECT_PATH = wog%2Fgvt%2Fgobiz%2Fmolb-gobusiness%2Fmolb-agency-portal%2Fmolb-agency-portal-web
```

**If no URL is provided**, ask the user to select a repo from the table above (one question only).

Do **not** ask about severity, Jira tickets, or branch names.

---

## Step 2: Fetch all severities in one pass

Fetch critical, high, medium, low together. Paginate each severity until the response array is empty.

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

> **API note:** `state[]=detected` and `scope=detected` params return 0 in this GitLab version. Fetch all, filter with jq.

---

## Step 3: Extract full details and output report

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

---

## Step 4: Print summary then stop

Print:

```
Vulnerability report — <repo> — <YYYY-MM-DD>

CRITICAL: <N>
HIGH:     <N>
MEDIUM:   <N>
LOW:      <N>
TOTAL:    <N> detected

<Full JSON output from Step 3>
```

**Stop here.** Do not apply fixes, run tests, run builds, or execute any git commands.

---

## Common Issues

| Symptom | Fix |
|---|---|
| All counts = 0 | Remove `state[]=detected` filter; use jq select instead |
| 403 on API | Token needs `read_api` scope |
| Pagination loop hangs | Cap at page 10 as safety limit |
