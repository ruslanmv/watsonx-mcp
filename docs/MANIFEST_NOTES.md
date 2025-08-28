# Manifest Notes & Best Practices

- `server.url` ends in `/sse`.
- Omit `transport` (prevents unwanted rewrites to `/messages/`).
- Include `provenance.source_url` when POSTing to Hub. Example (raw GitHub URL):  
  `https://raw.githubusercontent.com/ruslanmv/watsonx-mcp/master/manifests/watsonx.manifest.json`
- Optional `repository` metadata is included for discoverability.
- Keep tool ids stable: here, tool is `watsonx-chat`.
- If you need local-process installs by default, include a `runner.json` at repo root:
  ```json
  {
    "type": "python",
    "entry": "bin/run_watsonx_mcp.py",
    "python": {"venv": ".venv"},
    "endpoint": "/sse",
    "sse": {"endpoint": "/sse"}
  }
  ```
