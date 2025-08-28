#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Tunables (override via env or flags)
HUB="${HUB:-http://127.0.0.1:443}"
TOKEN="${MCP_GATEWAY_TOKEN:-}"
GW_BASE="${GW_BASE:-http://127.0.0.1:4444}"
SSE_URL="${SSE_URL:-http://127.0.0.1:6288/sse}"
ID="${ID:-mcp_server:watsonx-agent@0.1.0}"
TARGET="${TARGET:-watsonx-chat/0.1.0}"
MANIFEST_FILE="${MANIFEST_FILE:-manifests/watsonx.manifest.json}"

usage(){
cat <<EOF
Usage: $0 [--hub URL] [--token TOKEN] [--gw-base URL] [--sse-url URL] [--id FQID] [--target LABEL] [--manifest-file FILE]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hub) HUB="$2"; shift 2 ;;
    --token) TOKEN="$2"; shift 2 ;;
    --gw-base) GW_BASE="$2"; shift 2 ;;
    --sse-url) SSE_URL="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --manifest-file) MANIFEST_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

echo "▶ Inline install to Hub"
HUB="${HUB}" MCP_GATEWAY_TOKEN="${TOKEN}" \
  ID="${ID}" TARGET="${TARGET}" MANIFEST_FILE="${MANIFEST_FILE}" SSE_URL="${SSE_URL}" \
  "${SCRIPT_DIR}/hub_install_inline.sh"

echo
echo "▶ Verify in mcpgateway"
GW_BASE="${GW_BASE}" "${SCRIPT_DIR}/hub_verify_gateway.sh"

echo
echo "▶ Optional SSE probe"
SSE_URL="${SSE_URL}" "${SCRIPT_DIR}/hub_probe_sse.sh" || true

echo
echo "✅ Done."
echo "Reminder: make sure your Watsonx MCP server is running and serving ${SSE_URL}"
