## Quick verify (run → probe → call)

These steps confirm the server is running and reachable via MCP/SSE.

> Works whether you installed via MatrixHub (`matrix install …`) **or** you run the server manually.

### 1) Run the server

**If you installed with an alias (recommended):**
```bash
matrix run watsonx-chat
# → prints PID/Port OR a remote URL (connector mode) and a /health link
````

**Or run manually (no alias needed):**

```bash
# Linux/macOS
export PORT=6288
python bin/run_watsonx_mcp.py

# Windows (PowerShell)
$env:PORT=6288
python bin/run_watsonx_mcp.py
```

> The server exposes SSE at **/sse** and health at **/health**.

---

### 2) Probe tools (discoverable via MCP)

**Using the alias (auto-discovers the URL):**

```bash
matrix mcp probe --alias watsonx-chat
# JSON mode (optional):
matrix mcp probe --alias watsonx-chat --json
```

**Or probe directly by URL (manual run / custom port):**

```bash
matrix mcp probe --url http://127.0.0.1:6288/sse
```

Expected: a tool list that includes **`watsonx-chat`**.

---

### 3) Call the tool

**Using the alias:**

```bash
matrix mcp call watsonx-chat --alias watsonx-chat --args '{"query":"hello"}'
```

**Or via URL:**

```bash
matrix mcp call watsonx-chat --url http://127.0.0.1:6288/sse --args '{"query":"hello"}'
```

Expected: a natural-language reply from the Watsonx model.

---

### Optional checks

* Health:

  ```bash
  matrix doctor watsonx-chat
  # or (manual)
  curl -s http://127.0.0.1:6288/health | jq .
  ```

* Logs & stop:

  ```bash
  matrix logs watsonx-chat -f
  matrix stop watsonx-chat
  ```

---

### Troubleshooting

* **Connection refused / timeout:** Ensure the server is started; if you’re using Dockerized MatrixHub/mcpgateway, `127.0.0.1` from inside the container is **not** your host. Use a reachable host/IP in the manifest/URL.
* **Tool not listed:** Wait a few seconds after startup and probe again. Check server logs (`matrix logs …`) for errors.
* **Env missing:** Copy `.env.example → .env` and fill `WATSONX_*` values before running.
