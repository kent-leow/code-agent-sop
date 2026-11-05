#!/usr/bin/env bash
# aws_ro.sh — guarded AWS CLI for staging/prod investigation (read-only by default).
#
#   bash aws_ro.sh preflight --env staging|prod
#   bash aws_ro.sh --env staging|prod -- <service> <operation> [args...]
#   bash aws_ro.sh --env staging --write -- <service> <operation> ...                  # after user approval
#   bash aws_ro.sh --env prod --write --confirm-prod "<service> <operation>" -- ...    # after user confirmed TWICE
#
# Exit: 0 ok · 1 error/refused · 3 SSO expired (run the printed `aws sso login`).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

ENV="" WRITE=false CONFIRM_PROD="" MODE="call"
[[ "${1:-}" == "preflight" ]] && { MODE=preflight; shift; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2 ;;
    --write) WRITE=true; shift ;;
    --confirm-prod) CONFIRM_PROD="$2"; shift 2 ;;
    --) shift; break ;;
    *) die "unknown argument '$1' (put the aws command after --)" ;;
  esac
done
[[ -n "$ENV" ]] || die "--env staging|prod is required"
PROFILE=$(profile_for_env "$ENV")
TARGET_ENV=$(env_for_profile "$PROFILE")

if [[ "$MODE" == preflight ]]; then
  exp=$(sso_expiry)
  echo "SSO token expires: $exp"
  profiles=("$PROFILE")
  rc=0
  for p in "${profiles[@]}"; do
    printf '%-20s ' "$p"
    if out=$(aws_call "$p" sts get-caller-identity --query Arn --output text 2>&1); then echo "OK  $out"
    else echo "FAIL"; echo "$out" | tail -2 | sed 's/^/    /'; [[ "$out" == *"aws sso login"* ]] && rc=3; [[ $rc -eq 0 ]] && rc=1; fi
  done
  exit $rc
fi

[[ $# -ge 2 ]] || die "missing aws command after -- (e.g. -- ecs list-clusters)"
CLASS=$(classify "$@")
if [[ "$CLASS" != read ]]; then
  $WRITE || die "'$1 $2' is $CLASS on $TARGET_ENV ($PROFILE) — refused. Ask the user first; rerun with --write only after explicit approval of this exact command."
  if [[ "$TARGET_ENV" == prod ]]; then
    [[ "$CONFIRM_PROD" == "$1 $2" ]] || die "PRODUCTION $CLASS '$1 $2' needs the user to confirm twice, then --confirm-prod \"$1 $2\" — refused."
  fi
  echo "WARN: running $CLASS '$1 $2' on $TARGET_ENV as $PROFILE (user-approved)" >&2
fi
aws_call "$PROFILE" "$@"
