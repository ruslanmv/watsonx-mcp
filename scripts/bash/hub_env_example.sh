#!/usr/bin/env bash
# Usage:
#   source scripts/bash/hub_env_example.sh
#
# Exports:
#   HUB                 (default http://127.0.0.1:443)
#   MCP_GATEWAY_TOKEN   (no default)

: "${HUB:=http://127.0.0.1:443}"
: "${MCP_GATEWAY_TOKEN:=}"

export HUB MCP_GATEWAY_TOKEN

_mask() {
  local s="${1:-}"
  [[ -z "$s" ]] && { echo "(empty)"; return; }
  local n=${#s}
  if (( n <= 6 )); then
    printf "%s\n" "******"
  else
    printf "%s\n" "${s:0:3}***${s:n-3:3}"
  fi
}

echo "✅ HUB                = ${HUB}"
echo "✅ MCP_GATEWAY_TOKEN  = $(_mask "${MCP_GATEWAY_TOKEN}")"
echo "Tip: put these in your shell profile, or source this file before running the install scripts."
