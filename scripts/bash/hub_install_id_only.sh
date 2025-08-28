#!/usr/bin/env bash
set -Eeuo pipefail

HUB="${HUB:-http://127.0.0.1:443}"
TOKEN="${MCP_GATEWAY_TOKEN:-}"
ID="${ID:-mcp_server:watsonx-agent@0.1.0}"
TARGET="${TARGET:-watsonx-chat/0.1.0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hub) HUB="$2"; shift 2 ;;
    --token) TOKEN="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

BODY="$(jq -n --arg id "${ID}" --arg target "${TARGET}" '{id:$id, target:$target}')"

hdr=(-H "Content-Type: application/json")
[[ -n "${TOKEN}" ]] && hdr+=(-H "Authorization: Bearer ${TOKEN}")

set -x
curl -sS -X POST "${HUB}/catalog/install" "${hdr[@]}" --data "${BODY}" | jq .
set +x
