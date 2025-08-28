#!/usr/bin/env bash
set -Eeuo pipefail

GW_BASE="${GW_BASE:-http://127.0.0.1:4444}"
FILTER="${FILTER:-}"   # optional substring to grep gateway name/url

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gw|--gateway-base) GW_BASE="$2"; shift 2 ;;
    --filter) FILTER="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || { echo "jq not found"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl not found"; exit 1; }

echo "▶ Gateways @ ${GW_BASE}"
if [[ -n "${FILTER}" ]]; then
  curl -s "${GW_BASE}/gateways" \
    | jq -r --arg f "${FILTER}" '[.[] | select((.name//"")|test($f;"i") or (.url//"")|test($f;"i"))] | .[] | {name,url,reachable}'
else
  curl -s "${GW_BASE}/gateways" | jq -r '.[] | {name,url,reachable}'
fi

echo
echo "▶ Tools @ ${GW_BASE}"
curl -s "${GW_BASE}/tools" | jq -r '.[] | {id,name,integrationType,requestType}'
