#!/usr/bin/env bash
set -Eeuo pipefail
ALIAS="${ALIAS:-watsonx-chat}"
[[ $# -gt 0 ]] && ALIAS="$1"
command -v matrix >/dev/null 2>&1 || { echo "✖ matrix CLI not found"; exit 1; }
set -x
matrix run "${ALIAS}"
set +x
