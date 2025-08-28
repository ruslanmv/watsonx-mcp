#!/usr/bin/env bash
set -Eeuo pipefail

ALIAS="${ALIAS:-watsonx-chat}"
FQID="${FQID:-mcp_server:watsonx-agent@0.1.0}"
HUB_OPT="${HUB_OPT:-${MATRIX_HUB_BASE:-}}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --alias) ALIAS="$2"; shift 2 ;;
    --id|--fqid) FQID="$2"; shift 2 ;;
    --hub) HUB_OPT="$2"; shift 2 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

command -v matrix >/dev/null 2>&1 || { echo "✖ matrix CLI not found"; exit 1; }

set -x
if [[ -n "${HUB_OPT}" ]]; then
  matrix install "${FQID}" --alias "${ALIAS}" --hub "${HUB_OPT}"
else
  matrix install "${FQID}" --alias "${ALIAS}"
fi
set +x

