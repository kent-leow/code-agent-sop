#!/usr/bin/env bash
# health.sh — read-only snapshot: ECS clusters + services off desired, RDS status, non-empty DLQs (+ oldest age),
# CloudWatch alarms in ALARM. One call per resource type (paged), so it is cheap enough for PROD.
#
#   bash health.sh --env staging|prod [--prefix staging] [--profile P]
#   --prefix filters ECS clusters, services and DLQs by name (staging account also holds dev-/qa- resources).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

ENV="" PREFIX="" PROFILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV="$2"; shift 2 ;;
    --prefix) PREFIX="$2"; shift 2 ;;
    --profile) PROFILE="$2"; shift 2 ;;
    *) die "unknown argument '$1'" ;;
  esac
done
[[ -n "$PROFILE" ]] || { [[ -n "$ENV" ]] || die "--env staging|prod is required"; PROFILE=$(profile_for_env "$ENV"); }
A() { aws_call "$PROFILE" "$@"; }
A sts get-caller-identity --query Arn --output text >/dev/null || exit $?
match() { [[ -z "$PREFIX" || "$1" == *"$PREFIX"* ]]; }

echo "# Health — $(env_for_profile "$PROFILE") via $PROFILE${PREFIX:+ (filter: $PREFIX)} — $(date '+%Y-%m-%d %H:%M %Z')"

echo -e "\n## ECS clusters\ncluster\tstatus\tservices\trunning\tpending"
CLUSTERS=()
for c in $(A ecs list-clusters --query 'clusterArns' --output text); do match "${c##*/}" && CLUSTERS+=("$c"); done
[[ ${#CLUSTERS[@]} -gt 0 ]] && A ecs describe-clusters --clusters "${CLUSTERS[@]}" \
  --query 'clusters[].[clusterName,status,activeServicesCount,runningTasksCount,pendingTasksCount]' --output text

echo -e "\n## ECS services not steady (desired≠running, pending>0, or rollout not COMPLETED)\ncluster\tservice\tdesired\trunning\tpending\trollout"
total=0
for c in ${CLUSTERS[@]+"${CLUSTERS[@]}"}; do
  set -- $(A ecs list-services --cluster "$c" --query 'serviceArns' --output text)
  while [[ $# -gt 0 ]]; do
    batch=("${@:1:10}"); shift $(( $# < 10 ? $# : 10 ))
    while IFS=$'\t' read -r name desired running pending rollout; do
      total=$((total + 1))
      match "$name" || [[ -n "$PREFIX" && "${c##*/}" == *"$PREFIX"* ]] || continue
      if [[ "$desired" != "$running" || "$pending" != 0 || ( "$rollout" != COMPLETED && "$rollout" != None ) ]]; then
        echo -e "${c##*/}\t$name\t$desired\t$running\t$pending\t$rollout"
      fi
    done < <(A ecs describe-services --cluster "$c" --services "${batch[@]}" \
      --query 'services[].[serviceName,desiredCount,runningCount,pendingCount,deployments[0].rolloutState]' --output text)
  done
done
echo "(services scanned: $total)"

echo -e "\n## RDS (instances + clusters)\nid\tengine\tversion\tstatus\tclass\tmultiAZ"
A rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,Engine,EngineVersion,DBInstanceStatus,DBInstanceClass,MultiAZ]' --output text
A rds describe-db-clusters --query 'DBClusters[].[DBClusterIdentifier,Engine,EngineVersion,Status]' --output text

echo -e "\n## DLQs with messages\nqueue\tvisible\tin_flight\toldest_hours"
START=$(python3 -c 'import datetime as d; print((d.datetime.now(d.timezone.utc)-d.timedelta(hours=2)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
END=$(python3 -c 'import datetime as d; print(d.datetime.now(d.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')
empty=0
for q in $(A sqs list-queues --query 'QueueUrls' --output text | tr '\t' '\n' | grep -iE 'dlq|dead' || true); do
  name="${q##*/}"; match "$name" || continue
  read -r vis inflight < <(A sqs get-queue-attributes --queue-url "$q" \
    --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible \
    --query 'Attributes.[ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible]' --output text)
  if [[ "$vis" == 0 && "$inflight" == 0 ]]; then empty=$((empty + 1)); continue; fi
  age=$(A cloudwatch get-metric-statistics --namespace AWS/SQS --metric-name ApproximateAgeOfOldestMessage \
    --dimensions Name=QueueName,Value="$name" --start-time "$START" --end-time "$END" --period 3600 \
    --statistics Maximum --query 'max(Datapoints[].Maximum)' --output text | awk '{ if ($1=="None") print "n/a"; else printf "%.1f", $1/3600 }')
  echo -e "$name\t$vis\t$inflight\t$age"
done
echo "(empty DLQs: $empty)"

echo -e "\n## CloudWatch alarms in ALARM (autoscaling TargetTracking *AlarmLow* scale-in alarms hidden — always in ALARM)\nalarm\tmetric\tsince"
hidden=0
while IFS=$'\t' read -r n m t; do
  [[ -z "$n" ]] && continue; match "$n" || continue
  if [[ "$n" == TargetTracking-*AlarmLow* ]]; then hidden=$((hidden + 1)); else echo -e "$n\t$m\t$t"; fi
done < <(A cloudwatch describe-alarms --state-value ALARM --query 'MetricAlarms[].[AlarmName,MetricName,StateUpdatedTimestamp]' --output text)
echo "(scale-in alarms hidden: $hidden)"
