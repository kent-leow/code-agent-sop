# Shared HTTP helpers for Figma scripts — source, don't execute.
# - Token is passed via a curl config on a file descriptor, never on argv (hidden from `ps`).
# - Reads retry 429/5xx/timeouts with exponential backoff (honours Retry-After); writes never retry.

: "${FIGMA_TOKEN:?FIGMA_TOKEN is required — export it in ~/.zshenv, then: source ~/.zshenv}"
FIGMA_API="https://api.figma.com/v1"
TMPDIR="${TMPDIR:-/tmp}"

_figma_auth() { printf 'header = "X-Figma-Token: %s"\n' "$FIGMA_TOKEN"; }

figma_curl() {
  curl --silent --show-error --connect-timeout 10 --max-time 120 \
    --retry 4 --retry-max-time 120 -K <(_figma_auth) "$@"
}

figma_curl_once() {
  curl --silent --show-error --connect-timeout 10 --max-time 60 -K <(_figma_auth) "$@"
}

# Pre-signed asset URLs (S3) — never send the Figma token off api.figma.com.
fetch_url() {
  curl --silent --show-error --fail --location --connect-timeout 10 --max-time 300 --retry 3 "$@"
}
