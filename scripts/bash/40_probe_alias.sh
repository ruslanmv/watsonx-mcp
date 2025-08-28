#!/usr/bin/env bash
set -Eeuo pipefail
ALIAS="${ALIAS:-watsonx-chat}"
JSON="${JSON:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --alias) ALIAS="$2"; shift 2 ;;
    --json) JSON=1; shift ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

command -v matrix >/dev/null 2>&1 || { echo "✖ matrix CLI not found"; exit 1; }

if [[ "${JSON}" == "1" ]]; then
  matrix mcp probe --alias "${ALIAS}" --json
else
  matrix mcp probe --alias "${ALIAS}"
fi
