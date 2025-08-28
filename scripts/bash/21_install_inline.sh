#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ID="${ID:-mcp_server:watsonx-agent@0.1.0}"
TARGET="${TARGET:-watsonx-chat/0.1.0}"
MANIFEST_FILE="${MANIFEST_FILE:-${ROOT_DIR}/manifests/watsonx.manifest.json}"
SOURCE_URL="${SOURCE_URL:-https://raw.githubusercontent.com/ruslanmv/watsonx-mcp/main/manifests/watsonx.manifest.json}"
SSE_URL="${SSE_URL:-http://127.0.0.1:6288/sse}"

HUB="${HUB:-${MATRIX_HUB_BASE:-http://127.0.0.1:443}}"
AUTH="${AUTH:-${MATRIX_HUB_TOKEN:-}}"

step(){ printf "▶ %s\n" "$*"; }
info(){ printf "ℹ %s\n" "$*"; }
warn(){ printf "⚠ %s\n" "$*\n" >&2; }
die(){ printf "✖ %s\n" "$*\n" >&2; exit 1; }

usage(){
cat <<EOF
Usage: $0 [--id FQID] [--target LABEL] [--manifest-file FILE] [--source-url URL] [--sse-url URL] [--hub URL] [--auth TOKEN]
Defaults:
  id:            ${ID}
  target:        ${TARGET}
  manifest-file: ${MANIFEST_FILE}
  source-url:    ${SOURCE_URL}
  sse-url:       ${SSE_URL}
  hub:           ${HUB}
  auth:          (from MATRIX_HUB_TOKEN, optional)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --manifest-file) MANIFEST_FILE="$2"; shift 2 ;;
    --source-url) SOURCE_URL="$2"; shift 2 ;;
    --sse-url) SSE_URL="$2"; shift 2 ;;
    --hub) HUB="$2"; shift 2 ;;
    --auth) AUTH="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

command -v jq >/dev/null 2>&1 || die "jq not found (required)."
command -v curl >/dev/null 2>&1 || die "curl not found (required)."
[[ -f "${MANIFEST_FILE}" ]] || die "Manifest file not found: ${MANIFEST_FILE}"

step "Preparing inline payload (forcing SSE URL & request_type=SSE)"
PAYLOAD="$(jq -n \
  --arg id "${ID}" \
  --arg target "${TARGET}" \
  --arg src "${SOURCE_URL}" \
  --arg sse "${SSE_URL}" \
  --slurpfile m "${MANIFEST_FILE}" '
  def force_sse(x):
    (x[0])
    | .mcp_registration.tool.request_type = "SSE"
    | .mcp_registration.server.url = $sse
  ;
  {
    id: $id,
    target: $target,
    manifest: (force_sse($m)),
    provenance: { source_url: $src }
  }')"

step "POST → ${HUB}/catalog/install"
hdr=(-H "Content-Type: application/json")
[[ -n "${AUTH}" ]] && hdr+=(-H "Authorization: Bearer ${AUTH}")

curl -sS -X POST "${HUB}/catalog/install" "${hdr[@]}" --data "${PAYLOAD}" | jq .
echo "✅ Inline install done."
