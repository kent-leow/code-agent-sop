---
name: aws-access
description: "Read-only AWS investigation for MOLB / GoBusiness staging (account 934558626247, holds dev/qa/staging) and production (150825224711) via GCC SSO profiles: ECS services/tasks, RDS, SQS DLQs, CloudWatch logs/metrics/alarms, ALB targets, Lambda, schedules, CloudTrail, ECR, ACM, OpenSearch, S3, DynamoDB, Secrets/SSM metadata. Guarded wrapper refuses writes; PRODUCTION writes need the user to confirm twice. Use when: check aws, ecs status, rds status, dlq, cloudwatch, alarm, task stopped, who changed, deployment, infra health, staging/prod aws."
argument-hint: "env (staging|prod) + resource/service + what to verify (e.g. 'prod ECS licence-service stopped tasks last 2h')"
metadata:
  category: operations
  tier: advanced
  status: active
  invocation: explicit
---

# AWS Access

**Input**: env + resource + question → **Output**: read-only AWS evidence (tables) cited in reports. App log lines → **opensearch-logs** first; DB rows → **postgres-query**; this skill covers infrastructure state.

## Profiles (`~/.aws/config`, GCC SSO)

| `--env` | Profile | Identity | Use |
|---|---|---|---|
| `staging` | `staging` | SSO `agency_developer` @ 934558626247 | everything non-prod — account also holds `dev-*`, `qa-*` (filter by name prefix) |
| `prod` | `prod-elevated` (default) | assume `Prod-Dev-Elevated-Role` via `production` | ECS, RDS, SQS, CloudWatch, Lambda, most reads |
| — | `prod-paws-operator` | assume `Prod-Bedrock-Agent-Operator-Role` via `production` | Paws data only (S3 / DynamoDB / AgentCore memory) — `--profile prod-paws-operator` |
| — | `production` | SSO `agency_assume_local` @ 150825224711 | login/source only; never query with it |

- Missing profiles → copy the snippet from inspector-paws `docs/testing/PAWS-HOSTED-ENVIRONMENTS.md` § Local AWS CLI setup (append, don't overwrite; `role_session_name` = `<sso-local-part>-prod-cli` / `-prod-paws`). Never invent account IDs/ARNs; never copy a colleague's config.
- Never set `AWS_PROFILE`/`AWS_DEFAULT_PROFILE` (the scripts ignore them and pass `--profile` per call). `[default]` holds stale static keys — never use it.

## Login

One SSO token (same start URL) covers all four profiles, ~8 h.

1. `bash $S/aws_ro.sh preflight --env <env>` → expiry (SGT, minutes left) + `sts` identity per profile
2. Exit 3 / `HINT: SSO session expired` → run `aws sso login --profile staging` **async**, read its output, give the user the URL + code (browser approval is theirs; never attempt it), wait for completion, re-run preflight
3. AccessDenied on assume-role after login → IAM trust gap, not config: report, don't work around

Needs **unsandboxed** execution (reads `~/.aws`, writes SSO cache, network).

## Verified permissions (2026-11-05)

| API | `staging` | `prod-elevated` | `prod-paws-operator` |
|---|---|---|---|
| ECS, RDS (+events/logs), SQS, CloudWatch metrics/alarms, CloudWatch Logs, EventBridge, Scheduler | ✅ | ✅ | ❌ |
| CloudTrail `lookup-events`, ACM, OpenSearch domain API (`es:*`) | ✅ | ❌ | ❌ |
| S3 / DynamoDB / AgentCore (Paws) | ✅ | per resource | ✅ |

Prod ❌ → report as a permission gap (don't hunt for another role); use evidence substitutes: deploy history → ECS `deployments`/`events`; cert expiry → APEX/`investigate-apex` or staging; OpenSearch health → `opensearch-logs ping`.

## Safety (mandatory)

| Class | Examples | Staging | **Production** |
|---|---|---|---|
| read | `describe-*` `list-*` `get-*` `filter-*` `lookup-*` `search-*` `head-*` `query` `scan` `logs tail/start-query` `s3 ls` | run | run (budgeted, see below) |
| sensitive | `secretsmanager get-secret-value`, `ssm get-parameter --with-decryption`, `kms decrypt`, `sqs receive-message` (hides messages), `lambda invoke`, `ecs execute-command`, `s3 cp`/`get-object`, credential/token minting | ask user → `--write` | **double confirm** → `--write --confirm-prod "<svc> <op>"` |
| write | `update-*` `create-*` `delete-*` `put-*` `start-*`/`stop-*` `run-task` `purge-queue` `redrive`, scaling, reboot | ask user → `--write` | **double confirm** → `--write --confirm-prod "<svc> <op>"` |

- **Production double confirmation**: (1) show exact command, target, expected effect, rollback → ask "Proceed?"; (2) after yes, ask again "Confirm PRODUCTION <op> on <resource>?" → only after the second yes add `--confirm-prod`. Any hesitation = stop. Never batch prod writes under one confirmation.
- `aws_ro.sh` enforces the classes; never call raw `aws` to bypass it (`health.sh` is read-only by construction).
- Never print secret values, tokens, or full message bodies; mask PII (NRIC, names, emails, phones) in reports.
- PROD budget: `health.sh` once, then targeted reads with `--max-items`/`--query`; no loops over hundreds of resources; reuse output instead of re-querying.

## Scripts

`S=.github/skills/aws-access/scripts` — AWS CLI v2; region default `ap-southeast-1`; 10 s connect / 60 s read timeout; standard retry mode (5 attempts); `ERROR:`/`HINT:` on stderr; exit 0 ok · 1 error/refused · 3 SSO expired.

| Command | Purpose |
|---|---|
| `bash $S/aws_ro.sh preflight --env E` | SSO expiry + identity per profile |
| `bash $S/aws_ro.sh --env E [--profile P] -- <svc> <op> [args]` | guarded AWS CLI call |
| `bash $S/health.sh --env E [--prefix staging]` | snapshot: ECS clusters + unsteady services, RDS, non-empty DLQs (+ oldest age), CloudWatch alarms in ALARM (scale-in alarms hidden). ~20 s |

`R="bash $S/aws_ro.sh --env <env> --"` in the recipes below.

## Investigation recipes

| Question | Command(s) |
|---|---|
| Service health + recent events | `$R ecs describe-services --cluster <env>-ecs --services <svc> --query 'services[0].{d:desiredCount,r:runningCount,p:pendingCount,dep:deployments[].[status,rolloutState,taskDefinition,updatedAt],ev:events[:10].[createdAt,message]}'` |
| Why tasks died | `$R ecs list-tasks --cluster C --service-name S --desired-status STOPPED` → `$R ecs describe-tasks --cluster C --tasks <arns> --query 'tasks[].[stoppedAt,stopCode,stoppedReason,containers[].[name,exitCode,reason]]'` (STOPPED kept ~1 h) |
| Which image is deployed | `$R ecs describe-task-definition --task-definition <family:rev> --query 'taskDefinition.containerDefinitions[].[name,image,memory,cpu]'` |
| Scheduled jobs | `$R events list-rules --name-prefix <env>` · `$R scheduler list-schedules --name-prefix <env>` · `$R events list-targets-by-rule --rule R` |
| Container logs (CloudWatch) | log group = service name (`staging-licence-service`, `prod-licence-service`; confirm via task definition `logConfiguration.options."awslogs-group"`) → `$R logs tail <group> --since 30m --filter-pattern ERROR --format short` (JSON lines carry UEN/NRIC baggage — excerpt + mask) |
| Logs Insights | `$R logs start-query --log-group-name G --start-time <epoch> --end-time <epoch> --query-string 'fields @timestamp,@message \| filter @message like /ERROR/ \| sort @timestamp desc \| limit 50'` → `$R logs get-query-results --query-id Q` |
| Metrics | `$R cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization --dimensions Name=ClusterName,Value=C Name=ServiceName,Value=S --start-time T0 --end-time T1 --period 300 --statistics Average Maximum` (RDS: `AWS/RDS` `DBInstanceIdentifier` — `CPUUtilization` `DatabaseConnections` `FreeStorageSpace` `FreeableMemory` `ReadLatency`; ALB: `AWS/ApplicationELB` `LoadBalancer` — `HTTPCode_Target_5XX_Count` `TargetResponseTime`; SQS: `ApproximateAgeOfOldestMessage`) |
| Alarms | `$R cloudwatch describe-alarms --state-value ALARM` · history: `$R cloudwatch describe-alarm-history --alarm-name A --history-item-type StateUpdate --max-items 10` |
| RDS state / events | `$R rds describe-db-instances --db-instance-identifier I` · `$R rds describe-events --source-type db-instance --source-identifier I --duration 1440` · `$R rds describe-pending-maintenance-actions` |
| RDS logs | `$R rds describe-db-log-files --db-instance-identifier I` → `$R rds download-db-log-file-portion --db-instance-identifier I --log-file-name F --starting-token 0 --output text` (may hold SQL with PII — excerpt + mask) |
| DLQ depth / source | `$R sqs get-queue-attributes --queue-url U --attribute-names All` (`RedrivePolicy` on source queue) · `$R sqs list-dead-letter-source-queues --queue-url <dlq>` — never `receive-message` without approval |
| Load balancer targets | `$R elbv2 describe-target-groups --names <tg>` → `$R elbv2 describe-target-health --target-group-arn ARN` |
| Lambda | `$R lambda get-function-configuration --function-name F` · errors: `AWS/Lambda` `Errors`/`Throttles` · logs `/aws/lambda/F` |
| Who changed what (staging only) | `$R cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=<name> --start-time T0 --max-items 20 --query 'Events[].[EventTime,EventName,Username]'` (or `AttributeKey=EventName,AttributeValue=UpdateService`) |
| Image vulnerabilities | `$R ecr describe-image-scan-findings --repository-name R --image-id imageTag=T --query 'imageScanFindings.findingSeverityCounts'` |
| Cert expiry (staging only) | `$R acm list-certificates --query 'CertificateSummaryList[].[DomainName,NotAfter,Status]'` |
| OpenSearch domain (staging only) | `$R opensearch describe-domain --domain-name staging` (prod: CloudWatch `AWS/ES` `ClusterStatus.red`, `FreeStorageSpace` via prod-elevated) |
| S3 / DynamoDB / AgentCore | `$R s3 ls s3://B/prefix/` · `$R s3api head-object --bucket B --key K` · `$R dynamodb describe-table --table-name T` · `$R bedrock-agentcore-control get-agent-runtime --agent-runtime-id ID` (prod: `--profile prod-paws-operator`) |
| Secrets / config (metadata only) | `$R secretsmanager describe-secret --secret-id S` (rotation, last changed) · `$R ssm get-parameter --name N` (no decryption) |

Naming: ECS cluster `<env>-ecs` (+ `common-ecs`); services, log groups, DLQs, schedules prefixed `<env>-` (`dev-`/`qa-`/`staging-`/`prod-`). `--max-items` + `--output text` prints a trailing `None` (pagination token) — ignore it.
Times: CLI wants UTC ISO (`2026-11-05T01:00:00Z`) or epoch seconds; report in SGT (UTC+8).

## Procedure

1. Preflight (handles login) → `health.sh --env E [--prefix <env>]` for broad questions
2. Narrow with the recipes; correlate with opensearch-logs (same time window) and code
3. Cite each finding: `aws:<env>/<profile> · <svc> <op> <key args> · <result excerpt>`

## Errors

| Symptom | Fix |
|---|---|
| exit 3 / `SSO session … expired` | Login step 2 |
| `config profile could not be found` | profile names ≠ table → add snippet (Profiles) |
| `AccessDenied` on assume-role | IAM trust gap → report |
| `AccessDenied` on an API (prod) | check Verified permissions → report the gap; Paws data → `--profile prod-paws-operator` |
| `Could not connect to the endpoint URL` / DNS | sandbox → rerun unsandboxed |
| `refused` from `aws_ro.sh` | intended guard → ask user per Safety |
