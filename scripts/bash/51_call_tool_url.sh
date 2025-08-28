#!/usr/bin/env bash
set -Eeuo pipefail
TOOL="${TOOL:-watsonx-chat}"
URL="${URL:-http://127.0.0.1:6288/sse}"
ARGS_JSON="${ARGS_JSON:-{\"query\":\"hello\"}}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tool) TOOL="$2"; shift 2 ;;
    --url) URL="$2"; shift 2 ;;
    --args) ARGS_JSON="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

command -v matrix >/dev/null 2>&1 || { echo "✖ matrix CLI not found"; exit 1; }

matrix mcp call "${TOOL}" --url "${URL}" --args "${ARGS_JSON}"
