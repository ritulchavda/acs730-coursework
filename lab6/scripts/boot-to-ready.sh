#!/usr/bin/env bash
set -euo pipefail

golden_ami=${1:?Usage: bash lab6/scripts/boot-to-ready.sh AMI_ID}
lab_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tf_dir="$lab_dir/terraform"

base_ami=$(terraform -chdir="$tf_dir" output -raw base_ami)
subnet=$(terraform -chdir="$tf_dir" output -raw subnet_id)
sg=$(terraform -chdir="$tf_dir" output -raw security_group_id)
instance_type=$(terraform -chdir="$tf_dir" output -raw instance_type)

user_data=$(mktemp)
instances=()

cleanup() {
  local result=$?
  trap - EXIT
  if ((${#instances[@]})); then
    if aws ec2 terminate-instances --instance-ids "${instances[@]}" \
      --query 'TerminatingInstances[].InstanceId' --output text &&
      aws ec2 wait instance-terminated --instance-ids "${instances[@]}"; then
      printf 'Benchmark instances terminated: %s\n' "${instances[*]}"
    else
      printf 'Check termination for: %s\n' "${instances[*]}" >&2
      result=1
    fi
  fi
  rm -f -- "$user_data"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for mode in stock golden; do
  image=$base_ami
  if [[ "$mode" == golden ]]; then image=$golden_ami; fi

  {
    printf '#!/bin/bash\nset -euo pipefail\n'
    printf "cat > /var/tmp/lab6-expected.html <<'LAB6_HTML'\n"
    cat "$lab_dir/packer/files/index.html"
    printf 'LAB6_HTML\n'
    if [[ "$mode" == stock ]]; then
      cat <<'USER_DATA'
dnf install -y nginx
install -m 0644 /var/tmp/lab6-expected.html /usr/share/nginx/html/index.html
systemctl enable --now nginx
USER_DATA
    fi
    cat <<'USER_DATA'
for attempt in {1..60}; do
  if curl -fsS --max-time 2 http://127.0.0.1/ | cmp -s - /var/tmp/lab6-expected.html; then
    read -r uptime_seconds _ < /proc/uptime
    printf '%s\n' "$uptime_seconds" > /var/tmp/lab6-ready
    exit 0
  fi
  sleep 1
done
exit 1
USER_DATA
  } > "$user_data"

  instance_id=$(aws ec2 run-instances --image-id "$image" \
    --instance-type "$instance_type" --subnet-id "$subnet" \
    --security-group-ids "$sg" --associate-public-ip-address \
    --iam-instance-profile Name=LabInstanceProfile --metadata-options HttpTokens=required \
    --user-data "file://$user_data" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=acs730-lab6-benchmark-$mode},{Key=Lab,Value=lab6}]" \
    --query 'Instances[0].InstanceId' --output text)
  instances+=("$instance_id")
  printf '%s: launched %s from %s\n' "$mode" "$instance_id" "$image"
  bash "$lab_dir/scripts/wait-ssm.sh" "$instance_id"

  command_id=$(aws ssm send-command --instance-ids "$instance_id" \
    --document-name AWS-RunShellScript \
    --parameters '{"commands":["timeout 480 cloud-init status --wait >/dev/null && cat /var/tmp/lab6-ready"]}' \
    --query 'Command.CommandId' --output text)

  deadline=$((SECONDS + 510))
  status=""
  while (( SECONDS < deadline )); do
    status=$(aws ssm list-command-invocations --command-id "$command_id" \
      --instance-id "$instance_id" --query 'CommandInvocations[0].Status' --output text)
    case "$status" in
      Success|Failed|Cancelled|TimedOut) break ;;
    esac
    sleep 5
  done

  if [[ "$status" != Success ]]; then
    aws ssm get-command-invocation --command-id "$command_id" \
      --instance-id "$instance_id" --output json
    exit 1
  fi

  ready_seconds=$(aws ssm get-command-invocation --command-id "$command_id" \
    --instance-id "$instance_id" --query StandardOutputContent --output text)
  printf '%s boot-to-ready: %s seconds\n' "$mode" "$ready_seconds"
done
