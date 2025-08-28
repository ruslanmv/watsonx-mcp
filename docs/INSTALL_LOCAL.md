# Local install & run via Matrix CLI

These steps install and run the Watsonx MCP server locally.

## 1) Create venv & install deps

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate
source .venv/bin/activate

pip install -r requirements.txt
cp .env.example .env
# Fill Watsonx credentials in .env
```

## 2) Install with Matrix CLI

Inline manifest (works even if Hub hasn’t stored `source_url` yet):

```bash
matrix install tool:watsonx-chat@0.1.0           --alias watsonx-chat           --manifest "https://raw.githubusercontent.com/ruslanmv/watsonx-mcp/main/manifests/watsonx.manifest.json"
```

ID-only (requires Hub to have `source_url` stored for this entity):

```bash
matrix install tool:watsonx-chat@0.1.0 --alias watsonx-chat
```

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

- **422 `source_url` missing`**: pass `--manifest <URL>` to the CLI.
- **Probe hits `/messages/`**: update to latest CLI that prefers `/sse` (or pass `--manifest` so manifest points to `/sse`).
- **Auth errors to Hub**: ensure `MCP_GATEWAY_TOKEN` or `BASIC/JWT` env configured in MatrixHub.
