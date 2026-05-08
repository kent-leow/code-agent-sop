---
description: "Fetches all GitLab security vulnerabilities (all severities) from a report/MR URL, writes a single findings list, fixes each one, and syncs on re-invocation. Triggers: fix vulnerabilities, security dashboard, CVE fix, vulnerability scan, remediate findings."
tools: [read, search, edit, execute, todo]
argument-hint: "Provide a GitLab vulnerability_report URL or MR URL"
---

Security remediation agent. **Never run `git commit` or `git push`.**

**Modes:**
- **First run** — fetch vulns, write findings file, apply fixes.
- **Re-run** — re-fetch, diff against existing file, mark resolved/new, continue fixing.

---

## Constraints
- Absolute paths: `/usr/bin/curl`, `/usr/bin/jq`
- Token: `$GITLAB_TOKEN` — verify: `echo "Token: $([ -n "$GITLAB_TOKEN" ] && echo YES || echo MISSING)"`
- Paginate all API calls until empty array
- Never guess fix versions — use `.solution` field only
- **Do not `git commit` or `git push` at any point**

---

## Step 1 — Parse URL

| Format | Endpoint |
|---|---|
| `…/{path}/-/security/vulnerability_report` | project-level |
| `…/groups/{path}/-/security/dashboard` | group-level |
| `…/{path}/-/merge_requests/{iid}` | extract project path → project-level |

URL-encode path (`/` → `%2F`).

```bash
DATE=$(date +%Y-%m-%d)
OUT_DIR=.docs/.vulnerability/${DATE}
OUT_FILE=${OUT_DIR}/vulnerabilities.md
```

---

## Step 2 — Fetch & group vulnerabilities

```bash
PAGE=1; ALL="[]"
while true; do
  RESP=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "https://sgts.gitlab-dedicated.com/api/v4/{projects|groups}/{ENCODED}/vulnerability_findings?state=detected&per_page=100&page=${PAGE}")
  [[ $(/usr/bin/jq 'length' <<< "$RESP") -eq 0 ]] && break
  ALL=$(/usr/bin/jq -s 'add' <<< "$ALL $RESP")
  PAGE=$((PAGE+1))
done
```

Group by `(name, dependency_pkg, identifiers)` — one group = one fix:

```bash
GROUPED=$(/usr/bin/jq '
  [.[] | {
    id, name, severity,
    project: .project.name_with_namespace,
    scanner: .scanner.name,
    file: .location.file,
    start_line: .location.start_line,
    dependency_pkg: .location.dependency.package.name,
    dependency_ver: .location.dependency.version,
    solution, description,
    identifiers: [.identifiers[].name]
  }]
  | group_by([.name, .dependency_pkg, (.identifiers | sort | join(","))])
  | map({
      name: .[0].name, severity: .[0].severity, scanner: .[0].scanner,
      project: .[0].project, dependency_pkg: .[0].dependency_pkg,
      dependency_ver: .[0].dependency_ver, solution: .[0].solution,
      description: .[0].description, identifiers: .[0].identifiers,
      count: length, ids: [.[].id],
      affected_files: ([.[].file] | unique)
    })
  | sort_by([.severity, .name])
' <<< "$ALL")
```

---

## Step 3 — Write / sync findings file

**First run** — create `${OUT_FILE}`:

```markdown
# Vulnerabilities — {DATE}

Source: {URL}
Fetched: {DATE}  |  Raw: {TOTAL}  |  Grouped: {G}

---

- [ ] **001** | `CRITICAL` | `{pkg}@{ver}` | {scanner} | {name} _(×{count})_
  - IDs: {identifiers}
  - Affected: `{file1}`, `{file2}` … (up to 5, then "and N more")
  - Fix: {solution}
```

- Zero-pad numbers to 3 digits
- No `dependency_pkg` (SAST/container) → use `{file}:{start_line}`

**Re-run** — diff by group key `(name, dependency_pkg, identifiers)`:
- Gone from API → `- [x] ~~...~~ (resolved)`
- Still present but was checked → reopen `- [ ]`, note `(re-appeared)`
- New → append `- [ ] **NNN**`
- Unchanged → update counts if changed, keep checkbox

---

## Step 4 — Fix loop

For each `- [ ]` item, severity order (critical first):

| Scanner | Fix |
|---|---|
| Gemnasium (Gradle) | `resolutionStrategy` in `build.gradle.kts` |
| Gemnasium (npm/yarn) | `resolutions` in `package.json` or direct upgrade |
| SAST | Code change at `file:start_line` |
| Container Scanning | Update `FROM` in `Dockerfile` |

Verify after each fix:
```bash
./gradlew test && ./gradlew build   # Gradle
yarn test && yarn build             # npm/yarn
```

- Build fails → revert, mark `DEFERRED: {reason}`
- False positive → mark `SKIPPED: false positive`, no code change

Write `${OUT_DIR}/fix-{NNN}.md`:

```markdown
# Fix-{NNN}: {name}

**Severity:** {severity}  **Scanner:** {scanner}  **CVE:** {identifiers}

## Finding
{description}

## Fix Applied
{change summary}

## Files Changed
- `{file}` — {what changed}

## Verification
{command} → passed

## Status
Fixed ✅ / Deferred ⏸ / Skipped ⚠️
```

Check off: `- [ ] **NNN**` → `- [x] **NNN**` in `${OUT_FILE}`.

---

## Step 5 — Summary

```
Total: {N} | Fixed: {N} | Deferred: {N} | Skipped: {N}

Files:
  {OUT_FILE}
  {OUT_DIR}/fix-001.md …
```
