#!/usr/bin/env bash
set -Eeuo pipefail

# Defaults (override via env or flags):
HUB="${HUB:-http://127.0.0.1:443}"
TOKEN="${MCP_GATEWAY_TOKEN:-}"
ID="${ID:-mcp_server:watsonx-agent@0.1.0}"
TARGET="${TARGET:-watsonx-chat/0.1.0}"
MANIFEST_FILE="${MANIFEST_FILE:-manifests/watsonx.manifest.json}"
SOURCE_URL="${SOURCE_URL:-https://raw.githubusercontent.com/ruslanmv/watsonx-mcp/master/manifests/watsonx.manifest.json}"
SSE_URL="${SSE_URL:-http://127.0.0.1:6288/sse}"

step(){ printf "▶ %s\n" "$*"; }
info(){ printf "ℹ %s\n" "$*"; }
warn(){ printf "⚠ %s\n" "$*\n" >&2; }
die(){ printf "✖ %s\n" "$*\n" >&2; exit 1; }

usage(){
cat <<EOF
Usage: $0 [--hub URL] [--token TOKEN] [--id FQID] [--target LABEL] [--manifest-file FILE] [--source-url URL] [--sse-url URL]

Defaults:
  --hub           ${HUB}
  --token         (from MCP_GATEWAY_TOKEN)
  --id            ${ID}
  --target        ${TARGET}
  --manifest-file ${MANIFEST_FILE}
  --source-url    ${SOURCE_URL}
  --sse-url       ${SSE_URL}
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hub) HUB="$2"; shift 2 ;;
    --token) TOKEN="$2"; shift 2 ;;
    --id) ID="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --manifest-file) MANIFEST_FILE="$2"; shift 2 ;;
    --source-url) SOURCE_URL="$2"; shift 2 ;;
    --sse-url) SSE_URL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "jq not found"
command -v curl >/dev/null 2>&1 || die "curl not found"
[[ -f "${MANIFEST_FILE}" ]] || die "Manifest file not found: ${MANIFEST_FILE}"

step "Reading manifest from ${MANIFEST_FILE} and forcing SSE URL → ${SSE_URL}"
# Force server.url to SSE; ensure request_type=SSE; drop any legacy transport field.
PATCHED="$(jq \
  --arg sse "${SSE_URL}" '
    . as $m
    | $m
    | .mcp_registration.server.url = $sse
    | .mcp_registration.tool.request_type = "SSE"
    | if .mcp_registration.server.transport then del(.mcp_registration.server.transport) else . end
  ' "${MANIFEST_FILE}")"

# Build payload
PAYLOAD="$(jq -n \
  --arg id "${ID}" \
  --arg target "${TARGET}" \
  --arg src "${SOURCE_URL}" \
  --argjson manifest "${PATCHED}" '
  {
    id: $id,
    target: $target,
    manifest: $manifest,
    provenance: { source_url: $src }
  }')"

step "POST ${HUB}/catalog/install"
hdr=(-H "Content-Type: application/json")
[[ -n "${TOKEN}" ]] && hdr+=(-H "Authorization: Bearer ${TOKEN}")

curl -sS -X POST "${HUB}/catalog/install" "${hdr[@]}" --data "${PAYLOAD}" | jq .
echo "✅ Inline install complete."
