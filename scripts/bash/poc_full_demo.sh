#!/usr/bin/env bash
# scripts/bash/poc_full_demo.sh
# End-to-end PoC:
#   - Inline install to MatrixHub (ingest/registration)
#   - Local install via Matrix CLI
#   - Run & verify (probe + mcpgateway checks)
#   - Uninstall & cleanup
#
# Requirements:
#   - bash, curl, jq
#   - matrix CLI in PATH
#   - MatrixHub reachable (HUB), and token if required (MCP_GATEWAY_TOKEN)
#
# Optional:
#   - If you want the Watsonx MCP server running for "reachable=true" in mcpgateway,
#     start it separately or pass --start-local to auto-run bin/run_watsonx_mcp.py.
#
# Usage (defaults shown):
#   scripts/bash/poc_full_demo.sh \
#     --hub http://127.0.0.1:443 \
#     --gw http://127.0.0.1:4444 \
#     --alias watsonx-chat \
#     --fqid mcp_server:watsonx-agent@0.1.0 \
#     --target watsonx-chat/0.1.0 \
#     --manifest manifests/watsonx.manifest.json \
#     --sse-url http://127.0.0.1:6288/sse \
#     [--start-local] [--purge]

set -Eeuo pipefail

# ---------- Defaults (override via flags or env) ----------
HUB="${HUB:-http://127.0.0.1:443}"
GW_BASE="${GW_BASE:-http://127.0.0.1:4444}"
TOKEN="${MCP_GATEWAY_TOKEN:-}"

ALIAS="${ALIAS:-watsonx-chat}"
FQID="${FQID:-mcp_server:watsonx-agent@0.1.0}"
TARGET="${TARGET:-${ALIAS}/0.1.0}"

MANIFEST_PATH="${MANIFEST_PATH:-manifests/watsonx.manifest.json}"
SOURCE_URL="${SOURCE_URL:-https://raw.githubusercontent.com/ruslanmv/watsonx-mcp/master/manifests/watsonx.manifest.json}"
SSE_URL="${SSE_URL:-http://127.0.0.1:6288/sse}"

START_LOCAL=0
PURGE=0

# ---------- Helpers ----------
step()  { printf "\n\033[1;36m▶ %s\033[0m\n" "$*"; }
info()  { printf "ℹ %s\n" "$*"; }
ok()    { printf "✅ %s\n" "$*"; }
warn()  { printf "⚠ %s\n" "$*\n" >&2; }
die()   { printf "✖ %s\n" "$*\n" >&2; exit 1; }

usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --hub URL            MatrixHub base (default: ${HUB})
  --gw URL             mcpgateway base (default: ${GW_BASE})
  --token TOKEN        Hub auth token (default: \$MCP_GATEWAY_TOKEN)
  --alias NAME         Local alias (default: ${ALIAS})
  --fqid ID            Entity id to install locally (default: ${FQID})
  --target LABEL       Hub plan label (default: ${TARGET})
  --manifest FILE      Manifest JSON file (default: ${MANIFEST_PATH})
  --source-url URL     Manifest provenance URL (default: ${SOURCE_URL})
  --sse-url URL        Expected SSE URL (default: ${SSE_URL})
  --start-local        Start bin/run_watsonx_mcp.py in background (optional)
  --purge              Purge files on uninstall (dangerous; off by default)
  -h, --help           Show this help
EOF
}

# ---------- Parse flags ----------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --hub) HUB="$2"; shift 2 ;;
    --gw|--gw-base) GW_BASE="$2"; shift 2 ;;
    --token) TOKEN="$2"; shift 2 ;;
    --alias) ALIAS="$2"; shift 2 ;;
    --fqid) FQID="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --manifest|--manifest-file) MANIFEST_PATH="$2"; shift 2 ;;
    --source-url) SOURCE_URL="$2"; shift 2 ;;
    --sse-url) SSE_URL="$2"; shift 2 ;;
    --start-local) START_LOCAL=1; shift 1 ;;
    --purge) PURGE=1; shift 1 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

# ---------- Preflight ----------
command -v jq >/dev/null 2>&1 || die "jq not found"
command -v curl >/dev/null 2>&1 || die "curl not found"
command -v matrix >/dev/null 2>&1 || die "matrix CLI not found in PATH"

MASK() {
  local s="${1:-}"
  [[ -z "$s" ]] && { echo "(empty)"; return; }
  local n=${#s}
  (( n <= 6 )) && { echo "******"; return; }
  printf "%s\n" "${s:0:3}***${s:n-3:3}"
}

step "Parameters"
info "Hub:        ${HUB}"
info "Gateway:    ${GW_BASE}"
info "Alias:      ${ALIAS}"
info "FQID:       ${FQID}"
info "Target:     ${TARGET}"
info "Manifest:   ${MANIFEST_PATH}"
info "SSE URL:    ${SSE_URL}"
info "Token:      $(MASK "${TOKEN}")"
[[ -f "${MANIFEST_PATH}" ]] || die "Manifest not found: ${MANIFEST_PATH}"

# ---------- Optional: start local Watsonx MCP for the demo ----------
LOCAL_PID=0
LOG_FILE="/tmp/watsonx-mcp-demo.log"
if (( START_LOCAL == 1 )); then
  step "Starting local Watsonx MCP (bin/run_watsonx_mcp.py)"
  if [[ ! -f "bin/run_watsonx_mcp.py" ]]; then
    die "bin/run_watsonx_mcp.py not found. Run without --start-local or add the starter."
  fi
  # Require a port match with SSE URL if possible
  PORT_FROM_SSE="$(echo "${SSE_URL}" | sed -E 's#^https?://[^:]+:([0-9]+).*$#\1#')"
  if [[ "${PORT_FROM_SSE}" =~ ^[0-9]+$ ]]; then
    export PORT="${PORT_FROM_SSE}"
  fi
  # Start
  set +e
  nohup python bin/run_watsonx_mcp.py > "${LOG_FILE}" 2>&1 &
  LOCAL_PID=$!
  set -e
  info "Local server PID: ${LOCAL_PID}; logs → ${LOG_FILE}"

  # Wait a moment for readiness (tolerant)
  sleep 2
  info "Attempting quick probe (3s) of ${SSE_URL}..."
  curl -s -i -N --max-time 3 "${SSE_URL}" | sed -n '1,25p' || true
fi

cleanup_local() {
  if (( START_LOCAL == 1 )); then
    if (( LOCAL_PID > 0 )); then
      info "Stopping local Watsonx MCP (pid=${LOCAL_PID})"
      kill "${LOCAL_PID}" 2>/dev/null || true
      sleep 1
    fi
  fi
}
trap cleanup_local EXIT

# ---------- A) Inline install to MatrixHub ----------
step "Inline install to MatrixHub (POST /catalog/install)"
PATCHED="$(jq \
  --arg sse "${SSE_URL}" '
    . as $m
    | $m
    | .mcp_registration.server.url = $sse
    | .mcp_registration.tool.request_type = "SSE"
    | if .mcp_registration.server.transport then del(.mcp_registration.server.transport) else . end
  ' "${MANIFEST_PATH}")"

PAYLOAD="$(jq -n \
  --arg id "${FQID}" \
  --arg target "${TARGET}" \
  --arg src "${SOURCE_URL}" \
  --argjson manifest "${PATCHED}" '
  { id: $id, target: $target, manifest: $manifest, provenance: { source_url: $src } }')"

HDR=(-H "Content-Type: application/json")
[[ -n "${TOKEN}" ]] && HDR+=(-H "Authorization: Bearer ${TOKEN}")

curl -sS -X POST "${HUB}/catalog/install" "${HDR[@]}" --data "${PAYLOAD}" | jq -r '. | .request_id? as $id | if $id then "request_id=\($id)" else . end' || true
ok "Inline install request sent."

# ---------- B) Local install via matrix CLI ----------
step "Local install via matrix CLI"
# You can pass --hub "${HUB}" to force hub (or export MATRIX_HUB_BASE).
set +e
matrix install "${FQID}" --alias "${ALIAS}" --hub "${HUB}" --force --no-prompt
RC=$?
set -e
if (( RC != 0 )); then
  warn "matrix install exited with ${RC}. If Hub requires auth, ensure MATRIX_HUB_TOKEN is set."
  exit ${RC}
fi
ok "Installed locally as alias '${ALIAS}'."

# ---------- C) Run & verify ----------
step "Run alias '${ALIAS}'"
set +e
RUN_OUT="$(matrix run "${ALIAS}" 2>&1)"
RC=$?
set -e
if (( RC != 0 )); then
  echo "${RUN_OUT}"
  die "Run failed."
fi
echo "${RUN_OUT}" | sed -n '1,80p' | sed 's/^/   /'

# Get URL/port from ps --plain (format: alias pid port uptime_seconds url target)
step "Discover runtime details (matrix ps --plain)"
PS_LINE="$(matrix ps --plain | awk -v a="${ALIAS}" 'BEGIN{IGNORECASE=1} $1==a{print; exit}')"
if [[ -z "${PS_LINE}" ]]; then
  warn "ps did not show alias; sleeping 2s and retrying…"
  sleep 2
  PS_LINE="$(matrix ps --plain | awk -v a="${ALIAS}" 'BEGIN{IGNORECASE=1} $1==a{print; exit}')"
fi
echo "   ${PS_LINE:-<none>}"

PORT="$(echo "${PS_LINE}" | awk '{print $3}')"
URL="$(echo "${PS_LINE}" | awk '{print $5}')"
[[ -n "${URL}" ]] || URL="http://127.0.0.1:${PORT}/sse"

step "Quick probe of ${URL} (3s)"
curl -s -i -N --max-time 3 "${URL}" | sed -n '1,25p' || true
ok "Probe done (SSE often holds connection; headers/status are the signal)."

# mcpgateway verify
step "Verify in mcpgateway (${GW_BASE})"
echo "   Gateways:"
curl -s "${GW_BASE}/gateways" | jq -r \
  --arg f "${ALIAS}" \
  '[.[] | select((.name//"")|test($f;"i") or (.url//"")|test($f;"i"))] | .[] | {name,url,reachable}' || true

echo "   Tools:"
curl -s "${GW_BASE}/tools" | jq -r '.[] | {id,name,integrationType,requestType}' || true

# Optional: MCP probe via CLI if extra is present
if matrix mcp --help >/dev/null 2>&1; then
  step "MCP probe via matrix CLI"
  set +e
  matrix mcp probe --alias "${ALIAS}" --json | jq . || true
  set -e
else
  info "matrix mcp not installed (extra). Skipping CLI probe."
fi

# ---------- D) Cleanup ----------
step "Cleanup: stop & uninstall"
set +e
matrix stop "${ALIAS}" >/dev/null 2>&1 || true
if (( PURGE == 1 )); then
  matrix uninstall "${ALIAS}" --purge -y || true
else
  matrix uninstall "${ALIAS}" -y || true
fi
set -e
ok "Stopped & uninstalled alias '${ALIAS}'."

# Local server (if started) will be cleaned up by trap
ok "🎉 PoC complete!"
echo "   - Inline installed to Hub"
echo "   - Installed locally, ran, probed"
echo "   - Verified mcpgateway"
echo "   - Cleaned up (stop/uninstall)"
