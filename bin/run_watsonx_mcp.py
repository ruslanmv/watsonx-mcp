#!/usr/bin/env python3
"""
Tiny launcher for the Watsonx MCP server.

Compatibility notes (Matrix runtime):
- Matrix runtime sets PORT=<assigned_port> in the environment.
- Our app prefers WATSONX_AGENT_PORT over PORT. To avoid surprises,
  we mirror PORT → WATSONX_AGENT_PORT if the latter is not already set.
- We delegate everything else to watsonx_mcp.app:main().
"""
import os
import sys
from pathlib import Path

# Ensure the repo root is importable (so `watsonx_mcp` resolves), even if launched from elsewhere.
_THIS = Path(__file__).resolve()
_REPO_ROOT = _THIS.parent.parent
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

# Ensure the agent uses the exact port chosen by matrix runtime.
if "PORT" in os.environ and "WATSONX_AGENT_PORT" not in os.environ:
    os.environ["WATSONX_AGENT_PORT"] = os.environ["PORT"]

try:
    from watsonx_mcp.app import main
except Exception as e:  # pragma: no cover
    sys.stderr.write(f"[watsonx-mcp] failed to import app.main: {e}\n")
    sys.exit(1)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
    except Exception as e:  # pragma: no cover
        sys.stderr.write(f"[watsonx-mcp] crashed: {e}\n")
        sys.exit(1)
