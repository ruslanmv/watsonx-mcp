# ====================================================================================
#
#   Watsonx MCP Starter ::: Control Program
#   Access programs with:   make help
#
# ====================================================================================

# ----- System & Environment -----
BRIGHT_GREEN  := $(shell tput -T screen setaf 10 2>/dev/null || printf '')
DIM_GREEN     := $(shell tput -T screen setaf 2 2>/dev/null || printf '')
RESET         := $(shell tput -T screen sgr0 2>/dev/null || printf '')

# Load variables from .env if it exists, making them available to make
ifneq (,$(wildcard .env))
    include .env
    export
endif

# ----- Configurable constants -----
SYS_PYTHON ?= python3
VENV_DIR   ?= .venv

PYTHON     := $(VENV_DIR)/bin/python
PIP        := $(PYTHON) -m pip

# Project layout (package + launcher + manifest)
PKG        ?= watsonx_mcp
ENTRY      ?= bin/run_watsonx_mcp.py
CLIENT     ?= bin/client.py
RUNNER     ?= runner.json
MANIFEST   ?= manifests/watsonx.manifest.json
DIST_DIR   ?= dist

# --- Host/Port/SSE ---
HOST        ?= 127.0.0.1
PORT        ?= 6288
# Use the port from .env if available, otherwise fall back to the default PORT
AGENT_PORT  := $(or $(WATSONX_AGENT_PORT),$(PORT))
SSE_PATH    ?= /sse
HEALTH_PATH ?= /healthz

ZIP_NAME   ?= watsonx-mcp-starter.zip

# Sentinels
VENV_CREATED   := $(VENV_DIR)/.created
REQS_SENTINEL  := $(VENV_DIR)/.reqs_installed

# Dev tools to optionally install
DEV_TOOLS ?= black ruff mypy pytest build twine mkdocs

# Targets to scan/format/type-check
PY_TARGETS := $(PKG) $(ENTRY) $(CLIENT)

# Optional: allow passing a host flag to the sample client if it supports it.
# Leave empty if your client has no --host option.
CLIENT_HOST_FLAG ?=
CLIENT_HOST      ?= $(HOST)

.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
help:
	@echo
	@echo "$(BRIGHT_GREEN)W A T S O N X   M C P   S T A R T E R ::: C O N T R O L   P R O G R A M$(RESET)"
	@echo
	@printf "$(BRIGHT_GREEN)  %-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "PROGRAM" "DESCRIPTION"
	@printf "$(BRIGHT_GREEN)  %-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "------------------" "----------------------------------------------"
	@echo
	@echo "$(BRIGHT_GREEN)Core$(RESET)"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "install" "Create venv & install package (editable)"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "dev" "Install developer tools ($(DEV_TOOLS))"
	@echo
	@echo "$(BRIGHT_GREEN)Dev & Quality$(RESET)"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "lint" "ruff check on $(PKG), $(ENTRY), $(CLIENT)"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "fmt" "black format + ruff --fix"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "typecheck" "mypy ($(PKG))"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "json-lint" "Validate manifest JSON files"
	@echo
	@echo "$(BRIGHT_GREEN)Run & Inspect$(RESET)"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "run" "Start local SSE server (reads .env for config)"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "health" "curl GET $(HEALTH_PATH) on port $(AGENT_PORT)"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "client" "Call tool once (use Q='your question')"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "client-repl" "Interactive client loop (blank line to exit)"
	@echo
	@echo "$(BRIGHT_GREEN)Packaging$(RESET)"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "zip-all" "Zip repo → $(DIST_DIR)/$(ZIP_NAME)"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "zip-min" "Minimal runtime zip (pkg+runner+pyproject+LICENSE)"
	@echo
	@echo "$(BRIGHT_GREEN)Matrix CLI (optional)$(RESET)"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "matrix-probe" "matrix mcp probe --alias watsonx-chat"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "matrix-call" "matrix mcp call chat --alias watsonx-chat --args '{\"query\":\"hello\"}'"
	@echo
	@echo "$(BRIGHT_GREEN)Maintenance$(RESET)"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "clean" "Remove build artifacts and caches"
	@printf "  $(BRIGHT_GREEN)%-18s$(RESET) $(DIM_GREEN)%s$(RESET)\n" "deepclean" "Also remove virtualenv"
	@echo

# ---------------------------------------------------------------------------
# Environment construction
# ---------------------------------------------------------------------------
$(VENV_CREATED):
	@echo "$(DIM_GREEN)-> Initializing virtual environment in $(VENV_DIR)...$(RESET)"
	@test -f $(PYTHON) || $(SYS_PYTHON) -m venv $(VENV_DIR)
	@echo "$(DIM_GREEN)-> Upgrading core tools (pip, setuptools, wheel)...$(RESET)"
	@$(PIP) install -U pip setuptools wheel > /dev/null
	@touch $@

$(REQS_SENTINEL): pyproject.toml | $(VENV_CREATED)
	@echo "$(DIM_GREEN)-> Installing project (editable) per pyproject.toml...(RESET)"
	@$(PIP) install -e .
	@touch $@

install: $(REQS_SENTINEL)
	@echo "$(BRIGHT_GREEN)Environment ready.$(RESET)"

dev: install
	@echo "$(DIM_GREEN)-> Installing developer tools...$(RESET)"
	@$(PIP) install -U $(DEV_TOOLS)
	@echo "$(BRIGHT_GREEN)Dev toolchain ready.$(RESET)"

# ---------------------------------------------------------------------------
# Quality
# ---------------------------------------------------------------------------
lint: $(REQS_SENTINEL)
	@$(PYTHON) -m ruff check $(PY_TARGETS) || { echo "Install dev tools: make dev"; exit 1; }

fmt: $(REQS_SENTINEL)
	@$(PYTHON) -m black $(PY_TARGETS) || { echo "Install dev tools: make dev"; exit 1; }
	@$(PYTHON) -m ruff check --fix $(PY_TARGETS) || true

typecheck: $(REQS_SENTINEL)
	@$(PYTHON) -m mypy --ignore-missing-imports $(PKG) || { echo "Install dev tools: make dev"; exit 1; }

json-lint:
	@echo "$(DIM_GREEN)-> Validating JSON files...$(RESET)"
	@$(SYS_PYTHON) - <<-'PY'
	import json, sys
	for p in ["runner.json","manifests/watsonx.manifest.json"]:
		try:
			json.load(open(p))
			print(f"✓ {p}")
		except Exception as e:
			print(f"✗ {p}: {e}", file=sys.stderr)
			raise
	PY

# ---------------------------------------------------------------------------
# Run & Inspect
# ---------------------------------------------------------------------------
run: install
	@echo "$(DIM_GREEN)-> Starting SSE server... (port is configured by .env or app defaults)$(RESET)"
	@PYTHONPATH=. $(PYTHON) $(ENTRY)

health:
	@echo "$(DIM_GREEN)-> GET $(HEALTH_PATH) (HOST=$(HOST) PORT=$(AGENT_PORT))...$(RESET)"
	@curl -fsS http://$(HOST):$(AGENT_PORT)$(HEALTH_PATH) || (echo "Health check failed"; exit 1)

# One-shot client call (set Q='your prompt' to override)
client: install
	@echo "$(DIM_GREEN)-> Calling client against http://$(HOST):$(AGENT_PORT)$(SSE_PATH) ...$(RESET)"
	@PYTHONPATH=. $(PYTHON) $(CLIENT) $(if $(CLIENT_HOST_FLAG),$(CLIENT_HOST_FLAG) $(CLIENT_HOST),) --port $(AGENT_PORT) --path $(SSE_PATH) $(if $(Q),--query "$(Q)",)

# Tiny interactive loop using the same client
client-repl: install
	@echo "$(DIM_GREEN)-> Interactive client. Press ENTER on an empty line to exit.$(RESET)"
	@while :; do \
		printf "$(BRIGHT_GREEN)you> $(RESET)"; \
		read -r Q; \
		[ -z "$$Q" ] && break; \
		PYTHONPATH=. $(PYTHON) $(CLIENT) $(if $(CLIENT_HOST_FLAG),$(CLIENT_HOST_FLAG) $(CLIENT_HOST),) --port $(AGENT_PORT) --path $(SSE_PATH) --query "$$Q"; \
	done

# ---------------------------------------------------------------------------
# Packaging
# ---------------------------------------------------------------------------
$(DIST_DIR):
	@mkdir -p $(DIST_DIR)

zip-all: $(DIST_DIR)
	@echo "$(DIM_GREEN)-> Creating full distribution zip...$(RESET)"
	@cd . && zip -qr "$(DIST_DIR)/$(ZIP_NAME)" \
		README.md LICENSE Makefile pyproject.toml \
		$(RUNNER) $(MANIFEST) bin $(PKG)
	@echo "$(BRIGHT_GREEN)Created $(DIST_DIR)/$(ZIP_NAME)$(RESET)"

zip-min: $(DIST_DIR)
	@echo "$(DIM_GREEN)-> Creating minimal runtime zip...$(RESET)"
	@cd . && zip -qr "$(DIST_DIR)/minimal-$(ZIP_NAME)" \
		LICENSE pyproject.toml $(RUNNER) $(ENTRY) $(PKG)
	@echo "$(BRIGHT_GREEN)Created $(DIST_DIR)/minimal-$(ZIP_NAME)$(RESET)"

# ---------------------------------------------------------------------------
# Matrix CLI (optional)
# ---------------------------------------------------------------------------
matrix-probe:
	@command -v matrix >/dev/null 2>&1 || { echo "Matrix CLI not found on PATH"; exit 1; }
	@matrix mcp probe --alias watsonx-chat

matrix-call:
	@command -v matrix >/dev/null 2>&1 || { echo "Matrix CLI not found on PATH"; exit 1; }
	@matrix mcp call chat --alias watsonx-chat --args '{"query":"hello"}'

# ---------------------------------------------------------------------------
# Maintenance
# ---------------------------------------------------------------------------
clean:
	@echo "$(DIM_GREEN)-> Cleaning build artifacts...(RESET)"
	@rm -rf $(DIST_DIR) *.egg-info
	@find . -type f -name "*.pyc" -delete
	@find . -type d -name "__pycache__" -exec rm -rf {} +

deepclean: clean
	@echo "$(DIM_GREEN)-> Removing virtual environment...$(RESET)"
	@rm -rf $(VENV_DIR)

# ---------------------------------------------------------------------------
# Phony
# ---------------------------------------------------------------------------
.PHONY: help install dev lint fmt typecheck json-lint run health client client-repl zip-all zip-min matrix-probe matrix-call clean deepclean