---
description: "Fetches all GitLab security vulnerabilities (all severities) from a report/MR URL or repo name, writes a single findings list, fixes each one, and syncs on re-invocation. Triggers: fix vulnerabilities, security dashboard, CVE fix, vulnerability scan, remediate findings."
tools: [read, search, edit, execute, todo]
argument-hint: "One or more inputs per line: a full GitLab vulnerability_report URL, OR just the repo name (e.g. molb-lab-web)"
---

Security remediation agent.

**Modes:**
- **First run** — prompt for ticket number, fetch vulns, write findings file, apply fixes, commit, push, create MR.
- **Re-run (same day)** — today's `vulnerabilities.md` already exists → locate the existing MR, check pipeline status, re-fetch live vulns from GitLab, diff & update findings, fix remaining items, push again.

---

## Constraints
- Absolute paths: `/usr/bin/curl`, `/usr/bin/jq`, `/usr/bin/git`
- Token: `$GITLAB_TOKEN` — verify: `echo "Token: $([ -n "$GITLAB_TOKEN" ] && echo YES || echo MISSING)"`
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

```bash
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('{project_path}', safe=''))")

# Get open MR on the fix branch
MR=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests?state=opened&source_branch=${BRANCH}" \
  | /usr/bin/jq '.[0]')

MR_IID=$(echo "${MR}" | /usr/bin/jq -r '.iid')
MR_URL=$(echo "${MR}" | /usr/bin/jq -r '.web_url')

# Get latest pipeline for the MR
PIPELINE=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/pipelines" \
  | /usr/bin/jq '.[0]')

PIPELINE_STATUS=$(echo "${PIPELINE}" | /usr/bin/jq -r '.status')
# Possible values: created, waiting_for_resource, preparing, pending, running, success, failed, canceled, skipped, manual
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

For each repo identified from the input URLs:

1. Derive the local repo folder name from the project path (last path segment, e.g. `molb-agency-portal-backend`).
2. `cd` into `${WORKSPACE}/{repo-name}`.
3. Detect default branch:
   ```bash
   DEFAULT_BRANCH=$(git -C . symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||' || echo "master")
   ```
4. Checkout and pull latest:
   ```bash
   git checkout "${DEFAULT_BRANCH}" && git pull origin "${DEFAULT_BRANCH}"
   ```
5. Check if branch already exists locally or remotely:
   ```bash
   BRANCH="GOBIZWKST2-${TICKET_NUM}-Fix-Vulnerability-${DATE}"
   git fetch origin
   if git branch -a | grep -q "${BRANCH}"; then
     git checkout "${BRANCH}"
     git pull origin "${BRANCH}" 2>/dev/null || true
   else
     git checkout -b "${BRANCH}"
   fi
   ```

---

## Step 2 — Fetch & group vulnerabilities

> **Only used on first run (no MR exists yet).** If an MR already exists for this repo, skip this step entirely and use the MR-scoped pipeline artifact endpoint in Step 6 instead.

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
- False positive → mark `SKIPPED: false positive`, no code change

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

Build a change log from all fixed items for this repo:
```
{pkg}@{old_ver} → {solution_ver}, {pkg2}@... → ...
```

```bash
git -C "${WORKSPACE}/{repo}" add -A
git -C "${WORKSPACE}/{repo}" commit -m "[GOBIZWKST2-${TICKET_NUM}] Vulnerability Fixes - {change_log}"
```

Only commit if there are staged changes (`git diff --cached --quiet` exits non-zero).

### 5b — Push

```bash
git -C "${WORKSPACE}/{repo}" push origin "${BRANCH}"
```

On **re-run**, if the branch already has commits ahead of origin, push normally (no force). If nothing was committed (no remaining unfixed items), skip push and log "No new changes to push".

### 5c — Check for existing MR

```bash
ENCODED_PATH=$(python3 -c "import urllib.parse; print(urllib.parse.quote('{project_path}', safe=''))")
EXISTING_MR=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED_PATH}/merge_requests?state=opened&source_branch=${BRANCH}" \
  | /usr/bin/jq '.[0]')
```

- If `EXISTING_MR` is not `null` → skip creation, note the existing MR URL (`EXISTING_MR.web_url`).
- If `null` → create MR:

```bash
/usr/bin/curl -s -X POST -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED_PATH}/merge_requests" \
  -d "{
    \"source_branch\": \"${BRANCH}\",
    \"target_branch\": \"${DEFAULT_BRANCH}\",
    \"title\": \"[GOBIZWKST2-${TICKET_NUM}] Vulnerability Fixes - ${DATE_DISPLAY}\",
    \"description\": \"## Summary\nAutomated vulnerability fixes.\n\n### Fixed\n{bulleted list of fixed items}\n\n### Deferred\n{bulleted list of deferred items}\",
    \"remove_source_branch\": true
  }"
```

Capture and store the created/existing MR URL for the final summary.

---

## Step 6 — Pipeline watch-and-fix loop (per repo)

After the MR exists and the branch is pushed, enter a watch loop for each repo.

> **Critical — MR-scoped vulnerability source (mandatory when MR exists):**
> The project-level `vulnerability_findings` endpoint (no `pipeline_id`) reflects only the **default branch** — it will not show new vulns introduced by the MR branch, nor confirm that MR-branch vulns are resolved. Always source findings from the MR's own pipeline scan.
>
> **Preferred approach — pipeline-scoped findings** (works reliably):
> ```bash
> # 1. Get the latest pipeline ID for the MR
> PIPELINE_ID=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
>   "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/pipelines" \
>   | /usr/bin/jq -r '.[0].id')
>
> # 2. Fetch vuln findings scoped to that pipeline
> MR_VULNS=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
>   "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/vulnerability_findings?pipeline_id=${PIPELINE_ID}&per_page=100" \
>   | /usr/bin/jq 'if type=="array" then [.[] | select(.state == "detected")] else [] end')
> MR_VULN_COUNT=$(echo "${MR_VULNS}" | /usr/bin/jq 'length')
> ```
>
> **Fallback — download pipeline job artifact** (if pipeline-scoped findings API returns empty/error):
> ```bash
> # Find the dependency-scanning job ID from the pipeline
> DS_JOB_ID=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
>   "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/pipelines/${PIPELINE_ID}/jobs?per_page=100" \
>   | /usr/bin/jq -r '[.[] | select(.name | test("dependency-scanning|gemnasium"))] | .[0].id')
>
> # Download the SBOM/report artifact and parse for detected vulns
> /usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
>   "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/jobs/${DS_JOB_ID}/artifacts/gl-dependency-scanning-report.json" \
>   -o /tmp/ds-report.json
> MR_VULNS=$(cat /tmp/ds-report.json | /usr/bin/jq '[.vulnerabilities[] | select(.state == "detected")]' 2>/dev/null || echo "[]")
> MR_VULN_COUNT=$(echo "${MR_VULNS}" | /usr/bin/jq 'length')
> ```
>
> Do **not** use `/merge_requests/{iid}/vulnerability_findings` — that endpoint returns 404 on this GitLab instance.
> Paginate if `MR_VULN_COUNT` equals 100. Group and process using the same logic as Step 2.

### 6a — Adaptive polling schedule

Use decreasing intervals — longer early (pipeline is still starting), shorter later:

```
Poll #  Wait before polling
  1     180 s   (3 min  — give CI time to initialise)
  2     120 s   (2 min)
  3      90 s   (1.5 min)
  4      60 s   (1 min)
  5+     30 s   (0.5 min — keep tight once nearly done)
```

```bash
INTERVALS=(180 120 90 60 30)
POLL=0

while true; do
  IDX=$(( POLL < ${#INTERVALS[@]} ? POLL : $(( ${#INTERVALS[@]} - 1 )) ))
  WAIT=${INTERVALS[$IDX]}
  echo "[{repo}] Poll #$(( POLL + 1 )) — waiting ${WAIT}s before checking pipeline..."
  sleep ${WAIT}
  POLL=$(( POLL + 1 ))

  # Fetch latest pipeline status
  PIPELINE=$(/usr/bin/curl -s -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    "https://sgts.gitlab-dedicated.com/api/v4/projects/${ENCODED}/merge_requests/${MR_IID}/pipelines" \
    | /usr/bin/jq '.[0]')
  PIPELINE_STATUS=$(echo "${PIPELINE}" | /usr/bin/jq -r '.status')
  PIPELINE_URL=$(echo "${PIPELINE}" | /usr/bin/jq -r '.web_url')
  echo "[{repo}] Pipeline status: ${PIPELINE_STATUS}  (${PIPELINE_URL})"

  case "${PIPELINE_STATUS}" in
    success)
      echo "[{repo}] Pipeline passed. Fetching MR vuln findings to confirm all resolved..."
      # Fetch MR-scoped vuln findings (see endpoint note above)
      # If MR_VULN_COUNT == 0 → break loop (fully done)
      # If MR_VULN_COUNT > 0 → vulns still detected by scanner; diff against findings file,
      #   fix remaining via Step 4, commit (Step 5a), push (Step 5b), reset POLL=0, continue
      ;;
    failed|canceled)
      echo "[{repo}] Pipeline ${PIPELINE_STATUS}. Fetching MR vuln findings and applying fixes..."
      # Fetch MR-scoped vuln findings (see endpoint note above)
      # Diff against findings file (Step 3 re-run logic)
      # Fix remaining items via Step 4 → commit (Step 5a) → push (Step 5b) → reset POLL=0
      ;;
    running|pending|created|waiting_for_resource|preparing)
      echo "[{repo}] Pipeline still ${PIPELINE_STATUS}. Waiting for next poll..."
      # Do NOT fetch vulns yet — pipeline scan is not complete; just continue loop
      ;;
    skipped|manual)
      echo "[{repo}] Pipeline ${PIPELINE_STATUS}. Fetching MR vuln findings to check state..."
      # Fetch MR-scoped vuln findings; if MR_VULN_COUNT == 0 → break; else fix and push
      ;;
    *)
      echo "[{repo}] Unknown pipeline status '${PIPELINE_STATUS}'. Continuing to poll."
      ;;
  esac
done
```

### 6b — Exit conditions

Stop the loop for a repo when **any** of these are true:
- Pipeline status is `success` **and** MR vuln count = 0 (MR-scoped endpoint returns empty `detected` list)
- All remaining items are marked `DEFERRED` or `SKIPPED` (nothing left to fix)
- Pipeline has failed **and** every fix attempt was reverted (log `BLOCKED: cannot fix remaining vulns`)
- 20 poll iterations reached without resolution — log `TIMEOUT: exceeded 20 polls` and stop

### 6c — Post-fix push within the loop

When fixes are applied mid-loop:
```bash
git -C "${WORKSPACE}/{repo}" add -A
git -C "${WORKSPACE}/{repo}" commit -m "[GOBIZWKST2-${TICKET_NUM}] Vulnerability Fixes (retry) - {change_log}"
git -C "${WORKSPACE}/{repo}" push origin "${BRANCH}"
echo "[{repo}] Pushed fix. Resetting poll counter for new pipeline run."
POLL=0   # reset so intervals start long again for the new pipeline
```

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
