#!/usr/bin/env bash
set -Eeuo pipefail

SSE_URL="${SSE_URL:-http://127.0.0.1:6288/sse}"
MAX_TIME="${MAX_TIME:-3}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url) SSE_URL="$2"; shift 2 ;;
    --max-time) MAX_TIME="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

echo "▶ Probing SSE: ${SSE_URL} (timeout ${MAX_TIME}s)"
# -i to show headers; --max-time to bail quickly; -N to disable buffering
curl -i -N --max-time "${MAX_TIME}" "${SSE_URL}" | sed -n '1,40p'
echo
echo "ℹ SSE probes often time out without body — headers/status are what you want to check."
