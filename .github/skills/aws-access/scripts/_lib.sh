# Shared helpers for aws-access scripts — source, don't execute. Bash 3.2 compatible.
# - Profile is always passed explicitly; a global AWS_PROFILE/AWS_DEFAULT_PROFILE is ignored.
# - Operations are classified read / sensitive / write before anything runs.

AWS_REGION_DEFAULT="ap-southeast-1"
SSO_START_URL="https://gccsso.awsapps.com/start/#"
unset AWS_PROFILE AWS_DEFAULT_PROFILE
export AWS_RETRY_MODE=standard AWS_MAX_ATTEMPTS=5 AWS_PAGER=""
TMPDIR="${TMPDIR:-/tmp}"

die() { echo "ERROR: $*" >&2; exit 1; }

# env → default profile; profile → env, SSO login profile
profile_for_env() {
  case "$1" in
    staging|stg|dev|qa) echo staging ;;
    prod|production) echo prod-elevated ;;
    *) die "unknown env '$1' (staging | prod)" ;;
  esac
}
env_for_profile() {
  case "$1" in
    staging) echo staging ;;
    production|prod-elevated|prod-paws-operator) echo prod ;;
    *) die "unknown profile '$1' (staging | production | prod-elevated | prod-paws-operator)" ;;
  esac
}
sso_profile_for() { [[ "$(env_for_profile "$1")" == prod ]] && echo production || echo staging; }

# classify SERVICE OPERATION [args...] → read | sensitive | write
classify() {
  local svc="$1" op="$2"; shift 2
  local args=" $* "
  case "$svc:$op" in
    secretsmanager:get-secret-value|secretsmanager:batch-get-secret-value|kms:decrypt|kms:generate-data-key*|\
    ecr:get-login-password|ecr:get-authorization-token|rds:generate-db-auth-token|sts:assume-role*|\
    sso:get-role-credentials|ecs:execute-command|ssm:start-session|sqs:receive-message|lambda:invoke|\
    s3:cp|s3:sync|s3:mv|s3:rm|s3api:get-object)
      echo sensitive; return ;;
    ssm:get-parameter|ssm:get-parameters|ssm:get-parameters-by-path)
      [[ "$args" == *" --with-decryption "* ]] && echo sensitive || echo read; return ;;
    s3:ls|rds:download-db-log-file-portion|logs:tail|logs:start-query|logs:stop-query|logs:start-live-tail|sts:get-caller-identity)
      echo read; return ;;
  esac
  case "$op" in
    describe-*|list-*|get-*|batch-get-*|filter-*|lookup-*|search-*|head-*|query|scan|wait|tail) echo read ;;
    *) echo write ;;
  esac
}

is_sso_error() { grep -qiE "SSO session|Token has expired|SSOTokenLoadError|UnauthorizedSSOToken|Error loading SSO Token|refresh failed|token included in the request is invalid" "$1"; }

# aws_call PROFILE [aws args...] — region default, timeouts, SSO hint (exit 3), clean errors
aws_call() {
  local profile="$1"; shift
  local region_args=(--region "$AWS_REGION_DEFAULT")
  local a; for a in "$@"; do [[ "$a" == "--region" ]] && region_args=(); done
  local err rc
  err=$(mktemp "$TMPDIR/aws_err_XXXXXX")
  rc=0
  aws --profile "$profile" ${region_args[@]+"${region_args[@]}"} --cli-connect-timeout 10 --cli-read-timeout 60 \
    --no-cli-pager "$@" 2>"$err" || rc=$?
  if [[ $rc -ne 0 ]]; then
    cat "$err" >&2
    if is_sso_error "$err"; then
      echo "HINT: SSO session expired — run (user approves in browser): aws sso login --profile $(sso_profile_for "$profile")" >&2
      rm -f "$err"; return 3
    fi
    grep -qi "AccessDenied\|not authorized" "$err" && echo "HINT: '$profile' lacks this permission — see aws-access 'Verified permissions'; report the gap, don't escalate" >&2
  fi
  rm -f "$err"; return $rc
}

sso_expiry() {  # prints ISO expiry (UTC) of the newest SSO token for the GCC start URL, or "none"
  python3 - "$SSO_START_URL" <<'PY'
import glob, json, os, sys
best = None
for f in glob.glob(os.path.expanduser("~/.aws/sso/cache/*.json")):
    try:
        d = json.load(open(f))
    except Exception:
        continue
    if d.get("startUrl") == sys.argv[1] and d.get("expiresAt") and (best is None or d["expiresAt"] > best):
        best = d["expiresAt"]
if not best:
    print("none")
else:
    import datetime as dt
    t = dt.datetime.fromisoformat(best.replace("Z", "+00:00"))
    left = int((t - dt.datetime.now(dt.timezone.utc)).total_seconds() // 60)
    print(f"{best} = {t.astimezone(dt.timezone(dt.timedelta(hours=8))):%Y-%m-%d %H:%M} SGT ({left} min left)")
PY
}
