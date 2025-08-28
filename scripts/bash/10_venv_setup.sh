#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

cd "${ROOT_DIR}"

PY_BOOT="${PY_BOOT:-$(command -v python3.11 || command -v python3 || command -v python)}"
VENV_DIR="${VENV_DIR:-.venv}"

step(){ printf "▶ %s\n" "$*"; }
info(){ printf "ℹ %s\n" "$*"; }
warn(){ printf "⚠ %s\n" "$*\n" >&2; }
die(){ printf "✖ %s\n" "$*\n" >&2; exit 1; }

[[ -x "${PY_BOOT}" ]] || die "Python not found. Install Python 3.11+."

if [[ ! -d "${VENV_DIR}" ]]; then
  step "Creating virtual environment → ${VENV_DIR}"
  "${PY_BOOT}" -m venv "${VENV_DIR}"
else
  info "Venv exists → ${VENV_DIR}"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

step "Upgrading pip & installing requirements"
python -m pip install -U pip wheel setuptools
if [[ -f requirements.txt ]]; then
  python -m pip install -r requirements.txt
else
  warn "requirements.txt not found; skipping deps install."
fi

# Copy .env.example → .env (non-destructive)
if [[ -f .env ]]; then
  info ".env already exists; not overwriting."
elif [[ -f .env.example ]]; then
  step "Creating .env from .env.example"
  cp .env.example .env
  info "Remember to fill WATSONX_* values in .env"
else
  warn ".env.example not found; create .env manually."
fi

echo "✅ Done."
