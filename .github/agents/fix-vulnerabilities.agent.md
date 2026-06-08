---
description: "Fetches all GitLab security vulnerabilities (all severities) from a report/MR URL or repo name, writes a single findings list, fixes each one, and syncs on re-invocation. Triggers: fix vulnerabilities, security dashboard, CVE fix, vulnerability scan, remediate findings."
tools: [read, search, edit, execute, todo]
argument-hint: "One or more inputs per line: a full GitLab vulnerability_report URL, OR just the repo name (e.g. molb-lab-web)"
---

Security remediation agent.  
Load **git-workflow skill** for all branch/commit/push/MR/pipeline/thread operations.

**Modes:**
- **First run** — prompt for ticket number, fetch vulns, write findings file, apply fixes, commit, push, create MR.
- **Re-run (same day)** — today's `vulnerabilities.md` already exists → locate the existing MR, check pipeline status, re-fetch live vulns from GitLab, diff & update findings, fix remaining items, push again.

---

## Constraints
- Absolute paths: `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/git`
- Token: `$GITLAB_TOKEN` — verify via **git-workflow skill** token pre-flight
- Paginate all API calls until empty array
- Never guess fix versions — use `.solution` field only
- Output files always go to workspace-root `.docs/.vulnerability/` — never inside a repo subfolder
- GitLab instance: `sgts.gitlab-dedicated.com`
- GitLab group base path: `wog/gvt/gobiz/molb-gobusiness/molb-l1t`
- Repos are under `/Users/a2456813/Development/IdeaProjects/`
- Always fetch all 4 severities: `CRITICAL,HIGH,MEDIUM,LOW` regardless of what the URL query string says
- **Once an MR exists for a repo, ALL vulnerability fetching MUST use the MR-scoped pipeline artifact endpoint — NEVER the project-level `vulnerability_findings` endpoint.** The project-level endpoint only reflects the default branch and will miss new vulns introduced or resolved by the MR branch.

---

## Step 0 — Normalise inputs → project paths

Accept one or more inputs separated by line breaks. For each line:

| Input type | How to detect | Action |
|---|---|---|
| Full `…/-/security/vulnerability_report` URL | starts with `https://` and contains `vulnerability_report` | Extract project path from URL (strip host + leading `/`, strip `/-/security/…` suffix) |
| Full `…/groups/…/-/security/dashboard` URL | starts with `https://` and contains `groups/` | Group-level; URL-encode group path |
| Full `…/-/merge_requests/{iid}` URL | starts with `https://` and contains `merge_requests` | Extract project path from URL |
| Bare repo name (e.g. `molb-lab-web`) | does **not** start with `https://` | Construct project path: `wog/gvt/gobiz/molb-gobusiness/molb-l1t/{repo-name}` |

After normalisation every input resolves to a **project path** (e.g. `wog/gvt/gobiz/molb-gobusiness/molb-l1t/molb-lab-web`). The local repo folder name is always the **last segment** of that path.

URL-encode path for API calls (`/` → `%2F`):
```bash
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('{project_path}', safe=''))")
```

```bash
DATE=$(date +%Y%m%d)           # YYYYMMDD for branch name
DATE_DISPLAY=$(date +%Y-%m-%d) # YYYY-MM-DD for display
WORKSPACE=/Users/a2456813/Development/IdeaProjects
OUT_DIR=${WORKSPACE}/.docs/.vulnerability/${DATE_DISPLAY}
OUT_FILE=${OUT_DIR}/vulnerabilities.md
mkdir -p "${OUT_DIR}"
```

Process each resolved project path independently through Steps 1–4, then produce a combined summary in Step 5.

---

## Step 0b — Detect run mode

Check whether today's findings file already exists:

```bash
[ -f "${OUT_FILE}" ] && RUN_MODE="rerun" || RUN_MODE="first"
```

**If `RUN_MODE=rerun`** → skip Steps 0c and 1 branch-creation; instead go to **Step 0d** to locate the existing MR and check pipeline status, then fetch vuln findings using the **MR-scoped pipeline artifact endpoint** (see Step 6 endpoint) — never the project-level endpoint → Step 3 (diff) → Step 4 (fix remaining) → Step 5 (push only, no new MR).

**If `RUN_MODE=first`** → continue to Step 0c.

---

## Step 0c — Prompt for ticket number (first run only)

Ask the user:

> **What is the GOBIZWKST2 ticket number (XXX)?**
> Used for branch `GOBIZWKST2-XXX-Fix-Vulnerability-{DATE}` and commit message.

Store as `TICKET_NUM`. Branch name pattern: `GOBIZWKST2-${TICKET_NUM}-Fix-Vulnerability-${DATE}`.

---

## Step 0d — Re-run: locate MR & check pipeline (re-run mode only)

For each repo, derive `BRANCH` from the existing findings file header or by scanning git branches:

```bash
# Find the fix branch for today
BRANCH=$(git -C "${WORKSPACE}/{repo}" branch -a \
  | grep -o 'GOBIZWKST2-[0-9]*-Fix-Vulnerability-${DATE}' | head -1)
TICKET_NUM=$(echo "${BRANCH}" | sed 's/GOBIZWKST2-\([0-9]*\)-.*/\1/')
```

**Check pipeline status of the existing MR:**

→ **skill: ENSURE_MR** (`ENCODED`, `BRANCH`) — find mode (read `MR_IID`, `MR_URL`, `PIPELINE_STATUS`).

Derive `MR_IID` from the returned existing MR. Then fetch latest pipeline status:

```bash
PIPELINE=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/pipelines" \
  | /usr/bin/jq '.[0]')
PIPELINE_STATUS=$(echo "${PIPELINE}" | /usr/bin/jq -r '.status')
```

| Pipeline status | Action |
|---|---|
| `success` | Fetch **MR-scoped** vuln findings (Step 6 endpoint); if count = 0 → done; else diff & fix |
| `failed` / `canceled` | Fetch **MR-scoped** vuln findings; diff & fix remaining |
| `running` / `pending` / `created` | Do NOT fetch vulns yet; wait for next poll |
| MR not found | Log warning; treat as first-run for this repo |

> **Critical:** Once an MR is found, always source vulnerability data from the MR's pipeline scan artifacts — never the project-level `vulnerability_findings` endpoint. The project endpoint reflects only the default branch; it will not show new vulns introduced by the MR branch nor confirm that MR-branch vulns are actually resolved. Use the job artifact download approach (Step 6).

---

## Step 1 — Per-repo: checkout, pull, create branch

→ **skill: BRANCH_SETUP** (`REPO_DIR = ${WORKSPACE}/{repo-name}`, `BRANCH = GOBIZWKST2-${TICKET_NUM}-Fix-Vulnerability-${DATE}`)  
Outputs: `DEFAULT_BRANCH`, active branch set to `BRANCH`.

---

## Step 2 — Fetch & group vulnerabilities

> **Only used on first run (no MR exists yet).** If an MR already exists for this repo, skip this step entirely and use the MR-scoped pipeline artifact endpoint in Step 6 instead.

```bash
PAGE=1; ALL="[]"
while true; do
  RESP=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "https://sgts.gitlab-dedicated.com/api/v4/{projects|groups}/{ENCODED}/vulnerability_findings?state=detected&severity=CRITICAL,HIGH,MEDIUM,LOW&per_page=100&page=${PAGE}")
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

Severity order for processing: `critical` → `high` → `medium` → `low`.

---

## Step 3 — Write / sync findings file

`OUT_FILE` is always `${WORKSPACE}/.docs/.vulnerability/${DATE_DISPLAY}/vulnerabilities.md`.

**First run** — create `${OUT_FILE}`:

```markdown
# Vulnerabilities — {DATE_DISPLAY}

Sources:
- {URL_1}
- {URL_2} …

Fetched: {DATE_DISPLAY}  |  Raw: {TOTAL}  |  Grouped: {G}

---

## {repo-name}

- [ ] **001** | `CRITICAL` | `{pkg}@{ver}` | {scanner} | {name} _(×{count})_
  - IDs: {identifiers}
  - Affected: `{file1}`, `{file2}` … (up to 5, then "and N more")
  - Fix: {solution}
```

- Zero-pad numbers to 3 digits; numbering is global across all repos
- No `dependency_pkg` (SAST/container) → use `{file}:{start_line}`
- Group findings under a `## {repo-name}` heading per repo

**Re-run** — diff by group key `(name, dependency_pkg, identifiers)`:
- Gone from API → `- [x] ~~...~~ (resolved)`
- Still present but was checked → reopen `- [ ]`, note `(re-appeared)`
- New → append `- [ ] **NNN**`
- Unchanged → update counts if changed, keep checkbox

---

## Step 4 — Fix loop

For each `- [ ]` item, severity order (critical → high → medium → low):

| Scanner | Fix |
|---|---|
| Gemnasium (Gradle) | `resolutionStrategy` in `build.gradle.kts` |
| Gemnasium (npm/yarn) | `resolutions` in `package.json` or direct upgrade |
| SAST | Code change at `file:start_line` |
| Container Scanning | Update `FROM` in `Dockerfile` |

Verify after each fix (run from the repo directory):
```bash
./gradlew test && ./gradlew build   # Gradle
yarn test && yarn build             # npm/yarn
```

- Build fails → revert, mark `DEFERRED: {reason}`
- False positive / withdrawn advisory → mark `SKIPPED: false positive` (or `SKIPPED: withdrawn advisory`), no code change, **and dismiss the finding in GitLab** via GraphQL `vulnerabilitiesDismiss`:

```bash
# 1. Get vulnerability GID via GraphQL (finding UUID → vulnerability GID)
VULN_GID=$(/usr/bin/curl -s -X POST -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://sgts.gitlab-dedicated.com/api/graphql" \
  -d "{\"query\": \"{ project(fullPath: \\\"${PROJECT_PATH}\\\") { vulnerabilities(state: DETECTED, first: 50) { nodes { id title } } } }\"}" \
  | /usr/bin/jq -r --arg TITLE "${VULN_TITLE}" \
    '.data.project.vulnerabilities.nodes[] | select(.title == $TITLE) | .id')

# 2. Dismiss via GraphQL mutation (build payload via python3 to avoid shell escaping issues)
# dismissalReason: FALSE_POSITIVE | NOT_APPLICABLE | ACCEPTABLE_RISK | VENDOR_ACKNOWLEDGED | USED_IN_TESTS | MITIGATING_CONTROL
PAYLOAD=$(python3 -c "
import json
gid = '${VULN_GID}'
reason = '${REASON}'   # e.g. FALSE_POSITIVE, NOT_APPLICABLE
comment = '''${COMMENT}'''
query = 'mutation { vulnerabilitiesDismiss(input: { vulnerabilityIds: [' + json.dumps(gid) + '], comment: ' + json.dumps(comment) + ', dismissalReason: ' + reason + ' }) { vulnerabilities { id state } errors } }'
print(json.dumps({'query': query}))
")
/usr/bin/curl -s -X POST -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://sgts.gitlab-dedicated.com/api/graphql" \
  -d "${PAYLOAD}" \
  | /usr/bin/jq -r '.data.vulnerabilitiesDismiss.vulnerabilities[]? | "\(.id): \(.state)"'
```

- SAST false positive → `FALSE_POSITIVE`
- Withdrawn CVE advisory → `NOT_APPLICABLE`

Write `${OUT_DIR}/fix-{NNN}.md`:

```markdown
# Fix-{NNN}: {name}

**Severity:** {severity}  **Scanner:** {scanner}  **CVE:** {identifiers}
**Repo:** {repo-name}

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

## Step 5 — Commit, push, create MR (per repo)

After all fixes are applied for a repo:

### 5a — Commit

Build change log from all fixed items: `{pkg}@{old_ver} → {solution_ver}, ...`

→ **skill: COMMIT** (`REPO_DIR`, `COMMIT_MSG = "[GOBIZWKST2-${TICKET_NUM}] Vulnerability Fixes - {change_log}"`)  
Store `COMMITTED`. If `COMMITTED=false` → log "No new changes to push" and skip 5b.

### 5b — Push

→ **skill: PUSH** (`REPO_DIR`, `BRANCH`)

### 5c — Find or create MR

MR title: `[GOBIZWKST2-${TICKET_NUM}] Vulnerability Fixes - ${DATE_DISPLAY}`  
MR body: `## Summary\nAutomated vulnerability fixes.\n\n### Fixed\n{list}\n\n### Deferred\n{list}`

→ **skill: ENSURE_MR** (`ENCODED`, `BRANCH`, `DEFAULT_BRANCH`, `MR_TITLE`, `MR_BODY`)  
Outputs: `MR_IID`, `MR_URL`, `MR_ACTION`.

---

## Step 6 — Pipeline watch-and-fix loop (per repo)

After the MR exists and the branch is pushed, enter a watch loop for each repo.

> **MR-scoped vulnerability source** (mandatory once MR exists) — see **git-workflow skill → MR-scoped vulnerability source** section for preferred (pipeline-scoped findings) and fallback (job artifact download) approaches.  
> Do **not** use `/merge_requests/{iid}/vulnerability_findings` — returns 404 on this instance.

→ **skill: POLL_PIPELINE** (`ENCODED`, `MR_IID`, `COMMITTED`)

**ON_SUCCESS hook:**  
Fetch MR-scoped vulns (see skill note). If `MR_VULN_COUNT == 0` → done (break). Else diff against findings file → fix remaining (Step 4) → skill: COMMIT → skill: PUSH → reset `POLL=0`.

**ON_FAILURE hook:**  
Same as ON_SUCCESS — fetch MR-scoped vulns → diff → fix → skill: COMMIT → skill: PUSH → reset `POLL=0`.

**Exit conditions (from skill):**
- `success` AND `MR_VULN_COUNT == 0` → ✅ done
- All remaining items `DEFERRED` / `SKIPPED` → ✅ done (nothing to fix)
- 3 consecutive failures → 🚫 `BLOCKED`
- 20 polls → ⏱ `TIMEOUT`

---

## Step 7 — Final summary

```
=== Vulnerability Fix Summary ===

Mode:    first-run | re-run
Ticket:  GOBIZWKST2-{TICKET_NUM}
Branch:  {BRANCH}
Date:    {DATE_DISPLAY}

Repos processed: {N}

Per-repo results:
  {repo-name}
    Total: {N} | Fixed: {N} | Deferred: {N} | Skipped: {N}
    Pipeline: {success|failed|running|timeout|blocked}
    Polls:    {N} iterations
    MR: {MR_URL}  [created|existing]

Output files:
  {OUT_FILE}
  {OUT_DIR}/fix-001.md …
```
