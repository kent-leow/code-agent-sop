#!/usr/bin/env bash
# session_start.sh — Claude Code SessionStart hook: offline integration readiness (booleans only, no network, <1s).
# Plain stdout becomes session context. Silent when the integration-health skill isn't installed.
set -uo pipefail
ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
HEALTH="$ROOT/.claude/skills/integration-health/scripts/health.py"
[[ -f "$HEALTH" ]] || exit 0

if command -v zsh >/dev/null 2>&1 && [[ -f "$HOME/.zshenv" ]]; then
  out=$(zsh -c 'source "$HOME/.zshenv" >/dev/null 2>&1; python3 "$1"' _ "$HEALTH" 2>/dev/null)
else
  out=$(python3 "$HEALTH" 2>/dev/null)
fi
[[ -n "$out" ]] || exit 0
echo "Integration readiness (offline config check by .claude/hooks/session_start.sh — run integration-health --net before gathering live evidence):"
echo "$out" | grep -v '^(offline'
exit 0
