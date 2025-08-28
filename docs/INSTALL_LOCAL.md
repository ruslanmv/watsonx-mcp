# Local install & run via Matrix CLI

These steps install and run the Watsonx MCP server locally **using MatrixHub** for planning.
> Note: `matrix install` talks to your Hub; it is not an offline operation.

## 0) Prerequisites

Export your local/dev Hub details so the CLI can reach it:

```bash
export MATRIX_HUB_BASE="http://127.0.0.1:443"   # or your Hub URL
export MATRIX_HUB_TOKEN="YOUR_HUB_TOKEN"        # if your Hub requires auth
````

(Alternatively, you can pass `--hub http://127.0.0.1:443` to `matrix install`.)

## 1) Create venv & install deps

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate
source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env
# Fill Watsonx credentials in .env
```

## 2) Install with Matrix CLI (via your Hub)

### Option A — ID-only (Hub already knows source\_url)

If your Hub has already stored the manifest’s `provenance.source_url` (from a prior inline install/ingest):

```bash
matrix install mcp_server:watsonx-agent@0.1.0 --alias watsonx-chat
```

### Option B — Inline (when Hub does *not* know source\_url yet)

Current `matrix-cli` does **not** accept `--manifest`. Use a one-shot inline install to the Hub:

```bash
HUB="${MATRIX_HUB_BASE:-http://127.0.0.1:443}"
AUTH="${MATRIX_HUB_TOKEN:-}"

curl -sS -X POST "$HUB/catalog/install" \
  -H "Authorization: Bearer $AUTH" \
  -H "Content-Type: application/json" \
  -d @- <<'JSON'
{
  "id": "mcp_server:watsonx-agent@0.1.0",
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
        "integration_type": "MCP",
        "request_type": "SSE"
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
    "source_url": "https://raw.githubusercontent.com/ruslanmv/watsonx-mcp/master/manifests/watsonx.manifest.json"
  },
  "target": "watsonx-chat/0.1.0"
}
JSON
```

After this, you can also run the `matrix install mcp_server:watsonx-agent@0.1.0` form later.

## 3) Run

```bash
matrix run watsonx-chat
# Output shows PID/Port and a probe URL (SSE at /sse)
```

If you prefer manual run:

```bash
export PORT=6288
python bin/run_watsonx_mcp.py
# http://127.0.0.1:6288/sse
```

## 4) Troubleshooting

* **422 `source_url` missing**: do the **inline install** via `curl` (Option B) once.
* **Probe hits `/messages/`**: update to the latest CLI. Our runner already sets `endpoint: "/sse"`. You can also probe directly:

  ```bash
  matrix mcp probe --url http://127.0.0.1:6288/sse
  ```
* **Auth errors to Hub**: ensure `MATRIX_HUB_TOKEN` is set (and your Hub accepts it).
* **Hub/Docker reachability**: if your Hub/mcpgateway runs in Docker or on another host, `127.0.0.1:6288` won’t be reachable from the Hub. Use a reachable host/IP in the manifest (or port-forward).

