#!/usr/bin/env bash
set -euo pipefail

export AWS_DEFAULT_REGION=us-east-1
export AWS_PAGER=""

[[ "${LAB6_BUILDER_ID:-}" == i-* ]]
bash "$LAB6_WAIT_SSM" "$LAB6_BUILDER_ID"

parameters=$(jq -cn --rawfile html "$LAB6_INDEX_HTML" '{
  commands: [
    "set -eu",
    "cloud-init status --wait",
    "dnf install -y nginx",
    ("printf %s " + ($html | @sh) + " > /usr/share/nginx/html/index.html"),
    "chmod 0644 /usr/share/nginx/html/index.html",
    "systemctl enable --now nginx",
    "curl -fsS http://127.0.0.1/ | cmp - /usr/share/nginx/html/index.html",
    "echo Nginx page verified"
  ],
  executionTimeout: ["300"]
}')

command_id=$(aws ssm send-command \
  --instance-ids "$LAB6_BUILDER_ID" \
  --document-name AWS-RunShellScript \
  --parameters "$parameters" \
  --query 'Command.CommandId' --output text)

deadline=$((SECONDS + 330))
status=""
while (( SECONDS < deadline )); do
  status=$(aws ssm list-command-invocations \
    --command-id "$command_id" \
    --instance-id "$LAB6_BUILDER_ID" \
    --query 'CommandInvocations[0].Status' --output text)

  case "$status" in
    Success|Failed|Cancelled|TimedOut) break ;;
  esac
  sleep 5
done

aws ssm get-command-invocation \
  --command-id "$command_id" \
  --instance-id "$LAB6_BUILDER_ID" \
  --query '{Status:Status,Output:StandardOutputContent,Error:StandardErrorContent}' \
  --output json

[[ "$status" == Success ]]
