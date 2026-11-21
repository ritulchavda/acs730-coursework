#!/usr/bin/env bash
set -euo pipefail

for instance_id in "$@"; do
  deadline=$((SECONDS + 600))
  while true; do
    status=$(aws ssm describe-instance-information \
      --filters "Key=InstanceIds,Values=$instance_id" \
      --query 'InstanceInformationList[0].PingStatus' --output text)

    if [[ "$status" == Online ]]; then
      printf '%s PingStatus: Online\n' "$instance_id"
      break
    fi

    if (( SECONDS >= deadline )); then
      printf '%s did not come online in SSM. Last status: %s\n' \
        "$instance_id" "$status" >&2
      exit 1
    fi

    sleep 5
  done
done
