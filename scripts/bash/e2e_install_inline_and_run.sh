#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ALIAS="${ALIAS:-watsonx-chat}"
FQID="${FQID:-mcp_server:watsonx-agent@0.1.0}"
TARGET="${TARGET:-watsonx-chat/0.1.0}"
SSE_URL="${SSE_URL:-http://127.0.0.1:6288/sse}"

echo "▶ Step 1: venv/deps"
"${SCRIPT_DIR}/10_venv_setup.sh"

echo "▶ Step 2: inline install to Hub"
ID="${FQID}" TARGET="${TARGET}" SSE_URL="${SSE_URL}" "${SCRIPT_DIR}/21_install_inline.sh"

echo "▶ Step 3: run alias"
ALIAS="${ALIAS}" "${SCRIPT_DIR}/30_run_alias.sh"

# give it a moment to bind and register
sleep 2

echo "▶ Step 4: probe (alias)"
ALIAS="${ALIAS}" "${SCRIPT_DIR}/40_probe_alias.sh" || true

echo "✅ E2E done. Try:"
echo "   ${SCRIPT_DIR}/50_call_tool_alias.sh --args '{\"query\":\"hello\"}'"
