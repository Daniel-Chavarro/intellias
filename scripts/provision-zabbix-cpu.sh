#!/usr/bin/env bash
set -euo pipefail

zabbix_url="${ZABBIX_URL:-http://127.0.0.1:8080/api_jsonrpc.php}"
zabbix_user="${ZABBIX_USER:-Admin}"
zabbix_password="${ZABBIX_PASSWORD:-zabbix}"
host_name="${ZABBIX_CPU_HOST:-zabbix-cpu-simulator}"
agent_address="${ZABBIX_CPU_AGENT_ADDRESS:-zabbix-cpu-simulator}"

api() {
  curl -fsS -H 'Content-Type: application/json-rpc' --data "$1" "$zabbix_url"
}

login_response="$(api "{\"jsonrpc\":\"2.0\",\"method\":\"user.login\",\"params\":{\"username\":\"$zabbix_user\",\"password\":\"$zabbix_password\"},\"id\":1}")"
auth="$(printf '%s' "$login_response" | jq -r '.result // empty')"
if [[ -z "$auth" ]]; then
  echo "Zabbix login failed: $login_response" >&2
  exit 1
fi

request() {
  local method="$1" params="$2"
  api "{\"jsonrpc\":\"2.0\",\"method\":\"$method\",\"params\":$params,\"auth\":\"$auth\",\"id\":2}"
}

group_id="$(request hostgroup.get '{"output":["groupid"],"filter":{"name":["CPU Simulation"]}}' | jq -r '.result[0].groupid // empty')"
if [[ -z "$group_id" ]]; then
  group_id="$(request hostgroup.create '{"name":"CPU Simulation"}' | jq -r '.result.groupids[0]')"
fi

template_id="$(request template.get '{"output":["templateid"],"filter":{"host":["Linux by Zabbix agent"]}}' | jq -r '.result[0].templateid // empty')"
if [[ -z "$template_id" ]]; then
  echo 'Template "Linux by Zabbix agent" was not found' >&2
  exit 1
fi

existing_host="$(request host.get "{\"output\":[\"hostid\"],\"filter\":{\"host\":[\"$host_name\"]}}" | jq -r '.result[0].hostid // empty')"
if [[ -n "$existing_host" ]]; then
  echo "Host already provisioned: $host_name (hostid=$existing_host)"
  exit 0
fi

host_payload="$(cat <<JSON
{"host":"$host_name","name":"CPU simulation agent","groups":[{"groupid":"$group_id"}],"templates":[{"templateid":"$template_id"}],"interfaces":[{"type":1,"main":1,"useip":0,"ip":"","dns":"$agent_address","port":"10050"}]}
JSON
)
created="$(request host.create "$host_payload")"
host_id="$(printf '%s' "$created" | jq -r '.result.hostids[0] // empty')"
if [[ -z "$host_id" ]]; then
  echo "Host creation failed: $created" >&2
  exit 1
fi

echo "Provisioned $host_name (hostid=$host_id, group=CPU Simulation)"
