#!/usr/bin/env bash
# Usage:
#   source scripts/bash/00_set_env_example.sh
#
# Note: running (not sourcing) will export only for the child process.

# Defaults – override before sourcing if you like:
: "${MATRIX_HUB_BASE:=http://127.0.0.1:443}"
: "${MATRIX_HUB_TOKEN:=}"   # optional

export MATRIX_HUB_BASE MATRIX_HUB_TOKEN

mask() {
  local s="${1:-}"
  [[ -z "$s" ]] && { echo "(empty)"; return; }
  local n=${#s}
  if (( n <= 6 )); then
    printf "%s\n" "******"
  else
    printf "%s\n" "${s:0:3}***${s:n-3:3}"
  fi
}

echo "✅ MATRIX_HUB_BASE  = ${MATRIX_HUB_BASE}"
echo "✅ MATRIX_HUB_TOKEN = $(mask "${MATRIX_HUB_TOKEN}")"
echo "Tip: export these in your profile or source this file before installs."
