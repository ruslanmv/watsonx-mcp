# Install & Ingest into MatrixHub

This guide shows how to bring **Watsonx MCP** into **MatrixHub** and register the federated gateway in **mcpgateway**.

> **SSE endpoint:** the server uses **`/sse`** (already in the manifest). No `transport` field is included to avoid `/messages/` rewrites.

## Prerequisites

* **MatrixHub** running (default: `http://127.0.0.1:443`)
* **mcpgateway** reachable by MatrixHub (default: `http://127.0.0.1:4444`)
* A Hub auth token (JWT/BASIC → MatrixHub turns it into `Authorization: Bearer …` for Gateway). Export it as `MCP_GATEWAY_TOKEN`.

```bash
export MCP_GATEWAY_TOKEN="your-hub-api-token"
```

---

## Option A — Inline install (recommended for dev)

Post the **manifest JSON** directly to your MatrixHub. Replace the base URL and token as needed.

```bash
HUB="http://127.0.0.1:443"
TOKEN="$MCP_GATEWAY_TOKEN"

curl -sS -X POST "$HUB/catalog/install"           -H "Authorization: Bearer $TOKEN"           -H "Content-Type: application/json"           -d @- <<'JSON'
{
  "id": "tool:watsonx-chat@0.1.0",
  "manifest": {
    "type": "mcp_server",
    "id": "watsonx-agent",
    "name": "Watsonx Chat Agent",
    "version": "0.1.0",
    "description": "An MCP server that chats via IBM watsonx.ai.",
    "mcp_registration": {
      "tool": {
        "id": "watsonx-chat",
        "name": "watsonx-chat",
        "description": "Chat with IBM watsonx.ai",
        "integration_type": "MCP"
      },
      "resources": [],
      "prompts": [],
      "server": {
        "name": "watsonx-mcp",
        "description": "Watsonx SSE server",
        "url": "http://127.0.0.1:6288/sse",
        "associated_tools": ["watsonx-chat"],
        "associated_resources": [],
        "associated_prompts": []
      }
    }
  },
  "provenance": {
    "source_url": "https://raw.githubusercontent.com/ruslanmv/watsonx-mcp/main/manifests/watsonx.manifest.json"
  }
}
JSON
```

**What this does**

* MatrixHub reads the manifest, registers the **tool/resources/prompts**, and creates a **Federated Gateway** in mcpgateway pointing to `http://127.0.0.1:6288/sse`.

> Make sure your local Watsonx MCP process is running and logs show `http://127.0.0.1:<port>/sse`. (You can run it with `matrix run <alias>` or `python bin/run_watsonx_mcp.py` from the starter repo.)

---

## Option B — ID-only install (after Hub stores `source_url`)

If your Hub persists `provenance.source_url` during install/ingest, you can later install **by ID** without resending the manifest:

```bash
HUB="http://127.0.0.1:443"
TOKEN="$MCP_GATEWAY_TOKEN"

curl -sS -X POST "$HUB/catalog/install"           -H "Authorization: Bearer $TOKEN"           -H "Content-Type: application/json"           -d '{"id":"tool:watsonx-chat@0.1.0","target":"watsonx-chat/0.1.0"}'
```

> The `target` value is a *label* used by the Hub’s planner (e.g., `<alias>/<version>`). It does **not** leak a local path.

---

## Verify in mcpgateway

```bash
# Gateways (should show your SSE URL and reachable=true when the server is up)
curl -s http://127.0.0.1:4444/gateways | jq '.[] | {name, url, reachable}'

# Tools (global + discovered)
curl -s http://127.0.0.1:4444/tools | jq '.[] | {id, name, integrationType}'
```

* If `reachable=false`, ensure your server is running and that the manifest URL ends with `/sse`.
* You can also probe the SSE endpoint directly (expect headers/hold, not a full body):

  ```bash
  curl -i http://127.0.0.1:6288/sse
  ```

---

## Common issues

* **422 `source_url` missing**: Use the **Inline install** (Option A). That bypasses a Hub fetch and also stores `provenance.source_url` for future ID-only installs.
* **`/messages/` vs `/sse`**: Manifests here **use `/sse`** and drop `transport`. Keep that to avoid rewrites. If you hand-edit manifests, ensure `server.url` ends in `/sse`.
