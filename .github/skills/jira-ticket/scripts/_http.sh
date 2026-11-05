# Shared HTTP helpers for Jira/Confluence scripts — source, don't execute.
# - Credentials go through a curl config on a file descriptor, never argv (hidden from `ps`).
# - GET/PUT retry 429/5xx/timeouts with backoff (honours Retry-After); POST never retries (no duplicates).

: "${JIRA_BASE_URL:?JIRA_BASE_URL is required (e.g. https://your-org.atlassian.net) — source ~/.zshenv}"
: "${JIRA_EMAIL:?JIRA_EMAIL is required — source ~/.zshenv}"
: "${JIRA_TOKEN:?JIRA_TOKEN is required — source ~/.zshenv}"
JIRA_BASE_URL="${JIRA_BASE_URL%/}"
TMPDIR="${TMPDIR:-/tmp}"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_jira_auth() { printf 'user = "%s:%s"\n' "$JIRA_EMAIL" "$JIRA_TOKEN"; }

# jira_request METHOD EXPECTED_STATUS PATH [curl args...]
# Body → stdout on EXPECTED_STATUS; otherwise "Error: METHOD PATH -> HTTP n" + body excerpt → stderr, return 1.
jira_request() {
  local method="$1" expect="$2" path="$3"; shift 3
  local retry=(--retry 3 --retry-max-time 60)
  [[ "$method" == "POST" ]] && retry=()
  local tmp code
  tmp=$(mktemp "$TMPDIR/jira_XXXXXX")
  code=$(curl --silent --show-error --connect-timeout 10 --max-time 60 ${retry[@]+"${retry[@]}"} \
    -K <(_jira_auth) -X "$method" -H "Accept: application/json" \
    -o "$tmp" -w '%{http_code}' "$@" "$JIRA_BASE_URL$path") || true
  if [[ "$code" != "$expect" ]]; then
    echo "Error: $method $path -> HTTP ${code:-000}" >&2
    head -c 2000 "$tmp" >&2; echo >&2
    rm -f "$tmp"; return 1
  fi
  cat "$tmp"; rm -f "$tmp"
}

# Authenticated download (curl keeps credentials on the Jira host across redirects).
jira_download() {  # jira_download URL DEST
  curl --silent --show-error --fail --location --connect-timeout 10 --max-time 120 --retry 3 \
    -K <(_jira_auth) -o "$2" "$1"
}

require_issue_key() {
  [[ "${1:-}" =~ ^[A-Z][A-Z0-9_]+-[0-9]+$ ]] || { echo "Error: invalid issue key '${1:-}' (expected e.g. PROJ-123)" >&2; exit 1; }
}
