# Ingestion & Install Troubleshooting

## 422: `source_url` missing

**Symptom**: `POST /catalog/install` returns 422 with `source_url` missing or fetch failed.

**Fixes**:
- Use inline manifest (`--manifest` in Matrix CLI) so Hub doesn’t need to fetch.
- Ensure your Hub persists `provenance.source_url` when you install/ingest so future ID-only installs work.

---

## Wrong endpoint (`/messages/`)

**Symptom**: 400/502 due to `/messages/` instead of `/sse`.

**Fixes**:
- Manifests here use `/sse` and drop `transport`. Update to latest CLI/SDK which prefer `/sse`.
- If you override, normalize `server.url` to end in `/sse`.

---

## Gateway shows unreachable

Confirm your local process is running and logs show `http://127.0.0.1:<port>/sse`.

From the Hub host, try:
```bash
curl -i http://127.0.0.1:<port>/sse
```
(SSE may hang; `200` headers are enough.)

---

## Windows venv issues

The SDK retries `venv.create(..., symlinks=False)` if symlinks fail.
