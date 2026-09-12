#!/usr/bin/env bash
set -euo pipefail

container_name="${ZABBIX_CPU_CONTAINER:-zabbix-cpu-simulator}"
workers="${1:-2}"
load="${2:-90}"
duration="${3:-0}"

case "$workers" in
  ''|*[!0-9]*) echo "workers must be a non-negative integer" >&2; exit 2 ;;
esac
case "$load" in
  ''|*[!0-9]*) echo "load must be an integer from 0 to 100" >&2; exit 2 ;;
esac
case "$duration" in
  ''|*[!0-9]*) echo "duration must be a non-negative integer in seconds" >&2; exit 2 ;;
esac
if (( load > 100 )); then
  echo "load must be an integer from 0 to 100" >&2
  exit 2
fi

docker exec "$container_name" sh -c 'pkill -f "stress-ng --cpu" || true'
docker exec -d "$container_name" stress-ng --cpu "$workers" --cpu-load "$load" --timeout "$duration"
printf 'CPU load started: workers=%s load=%s%% duration=%ss\n' "$workers" "$load" "$duration"
