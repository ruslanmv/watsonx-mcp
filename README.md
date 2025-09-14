

# watsonx-mcp — Matrix-ready MCP Server (local process, package + bin)

<p align="center">
  <img src="https://img.shields.io/badge/MCP-SSE%20Server-0B7285?style=for-the-badge" alt="MCP SSE Server">
  <a href="https://github.com/agent-matrix/matrix-hub"><img src="https://img.shields.io/badge/MatrixHub-Ready-brightgreen?logo=matrix&logoColor=white&style=for-the-badge" alt="MatrixHub Ready"></a>
  <img src="https://img.shields.io/badge/License-Apache%202.0-blue?logo=apache&style=for-the-badge" alt="License">
  <img src="https://img.shields.io/badge/IBM-watsonx-0f62fe?logo=ibm&logoColor=white&style=for-the-badge" alt="IBM watsonx">
</p>


A production-grade, Matrix-friendly **Model Context Protocol (MCP)** server that talks to **IBM watsonx.ai**.  
It ships as a Python package (`watsonx_mcp`) with a tiny launcher (`bin/run_watsonx_mcp.py`), an MCP manifest, and a `runner.json`
for Matrix runtimes. Transport is **Server-Sent Events (SSE)** at `http://127.0.0.1:<PORT>/sse`.

> **Highlights**
> - Clean layout: app code in `watsonx_mcp/`, launcher in `bin/`.
> - **SSE** endpoint at `/sse` and a `/health` route for probes.
> - **Matrix CLI** compatible; manifest targets `/sse`, no custom transport.
> - Reads configuration from **.env** (IBM watsonx credentials, model, port).
> - Ready for **PyPI** (PEP-517/518; `pyproject.toml`).

---

## Installation

From source (editable dev install):

```bash
python -m venv .venv
# Windows: .venv\Scripts\activate
source .venv/bin/activate

pip install -e .
```

> Tip: This repo also includes a `Makefile` for a one-command setup:
>
> ```bash
> make install     # creates venv and installs the package (editable)
> make dev         # adds black, ruff, mypy, pytest, etc.
> ```

---

## Configuration (.env)

Create a `.env` (you can copy `.env.example`) and set:

| Variable             | Required | Example / Default                   | Notes                                     |
| -------------------- | :------: | ----------------------------------- | ----------------------------------------- |
| `WATSONX_API_KEY`    |     ✅    | `xxxxxxxxxxxxxxxxx`                 | IBM watsonx.ai API key                    |
| `WATSONX_URL`        |     ✅    | `https://us-south.ml.cloud.ibm.com` | Base URL for your watsonx deployment      |
| `WATSONX_PROJECT_ID` |     ✅    | `1234abcd-...`                      | Project/space identifier                  |
| `MODEL_ID`           |    ⛔️    | `ibm/granite-3-3-8b-instruct`       | Optional; default as shown                |
| `PORT`               |    ⛔️    | `6288`                              | Matrix runtimes pass `PORT` automatically |
| `WATSONX_AGENT_PORT` |    ⛔️    | `6288`                              | Used if `PORT` is not provided            |

The server loads these via [`python-dotenv`](https://pypi.org/project/python-dotenv/).

---

## Run locally

Using the launcher script:

```bash
export PORT=6288                       # optional for ad-hoc runs
python bin/run_watsonx_mcp.py
# → http://127.0.0.1:6288/sse
```

Using the Makefile:

```bash
make run
# health check:
curl http://127.0.0.1:6288/health
```

---

## Matrix CLI

Install (using an inline manifest URL):

```bash
matrix install tool:watsonx-chat@0.1.0 \
  --alias watsonx-chat \
  --manifest "https://raw.githubusercontent.com/ruslanmv/watsonx-mcp/master/manifests/watsonx.manifest.json"

matrix run watsonx-chat
# Matrix runtime will pass PORT and launch the SSE server
```

Probe and call:

```bash
matrix mcp probe --alias watsonx-chat
matrix mcp call chat --alias watsonx-chat --args '{"query":"hello"}'
```

---

## Project layout

```
watsonx-mcp/
├─ pyproject.toml
├─ runner.json
├─ manifests/
│  └─ watsonx.manifest.json
├─ bin/
│  └─ run_watsonx_mcp.py
├─ watsonx_mcp/
│  ├─ __init__.py
│  └─ app.py
├─ .env.example
└─ Makefile
```

* **`watsonx_mcp/app.py`** — The MCP server implementation.
  It loads `.env`, initializes the watsonx client, exposes `chat` as an MCP tool,
  and serves **SSE** at `/sse` with a `/health` route.
* **`bin/run_watsonx_mcp.py`** — Minimal launcher calling `watsonx_mcp.app:main`.

---

## `runner.json` (local process)

The included runner starts the launcher and wires in environment variables:

```json
{
  "type": "python",
  "entry": "bin/run_watsonx_mcp.py",
  "python": { "venv": ".venv" },
  "endpoint": "/sse",
  "sse": { "endpoint": "/sse" },
  "health": { "path": "/health" },
  "env": {
    "PORT": "${port}",
    "WATSONX_AGENT_PORT": "${port}",
    "WATSONX_API_KEY": "${WATSONX_API_KEY}",
    "WATSONX_URL": "${WATSONX_URL}",
    "WATSONX_PROJECT_ID": "${WATSONX_PROJECT_ID}",
    "MODEL_ID": "${MODEL_ID}"
  }
}
```



---

## Make targets

```text
make install     # venv + editable install
make dev         # add black, ruff, mypy, pytest, etc.
make run         # start SSE server (PORT defaults to 6288)
make health      # curl GET /health
make lint        # ruff check
make fmt         # black + ruff --fix
make typecheck   # mypy package
make json-lint   # validate runner + manifest JSON
make zip-all     # full distribution archive
make zip-min     # minimal runtime archive
make clean       # remove build artifacts/caches
make deepclean   # also remove .venv
make client       # one-shot client call; pass Q="your prompt"
make client-repl  # small interactive loop using the client
```





## 🔹 Quick client (manual test)

A tiny MCP client is provided at **`bin/client.py`** so you can test the `chat` tool without Matrix:

```bash
# one-shot call (set Q to your prompt)
make client Q="What are the main attractions in Rome?"

# interactive loop (blank line to exit)
make client-repl
```

Alternatively, run directly:

```bash
python bin/client.py --port 6288 --path /sse --query "Hello"
```

> The client uses the standard MCP SSE transport and works with whatever port your server binds to.

---

## 🔹 Health & readiness endpoints

* **Basic health**: `GET /health` → `{"status":"ok"}`
* **Extended** (if enabled in the app):

  * `GET /healthz` → liveness
  * `GET /readyz`  → readiness (503 until dependencies are ready)
  * `GET /livez`   → simple liveness text

When using extended endpoints with Matrix runners, point the health probe to `/healthz`:

```json
{
  "health": { "path": "/healthz" }
}
```

---

## 🔹 Runner note (health path option)

The included `runner.json` points to `/health` by default.
If you enable the extended endpoints, you can switch to:

```json
"health": { "path": "/healthz" }
```

Both work—choose the one that matches your app configuration.

---

## 🔹 Project layout additions

Alongside the existing tree, this repo also includes:

```
bin/
  client.py         # simple MCP client for local testing
```

These dev utilities are intentionally kept in `bin/` (outside the `watsonx_mcp` package) so they don’t ship as library code.

---





---

## Troubleshooting

* **`ModuleNotFoundError: No module named 'watsonx_mcp'`**
  Ensure the package is installed (editable or wheel):

  ```bash
  pip install -e .
  # or, run with a local import path:
  PYTHONPATH=. python bin/run_watsonx_mcp.py
  ```
* **401/403 from watsonx**
  Double-check `WATSONX_API_KEY`, `WATSONX_URL`, and `WATSONX_PROJECT_ID` in `.env`.

---

## Security & Privacy

* Credentials are loaded from the local environment via `.env`.
* No credentials are logged. Review logs before sharing.

