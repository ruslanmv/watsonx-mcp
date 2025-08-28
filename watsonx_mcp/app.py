import os
import socket
import logging
from typing import Union

from dotenv import load_dotenv
from mcp.server.fastmcp import FastMCP

from ibm_watsonx_ai import Credentials
from ibm_watsonx_ai.foundation_models import ModelInference
from ibm_watsonx_ai.metanames import GenTextParamsMetaNames as GenParams

from starlette.applications import Starlette
from starlette.responses import JSONResponse, PlainTextResponse
from starlette.routing import Route, Mount
import uvicorn


HOST = "127.0.0.1"
DEFAULT_PORT = 6288

READY = {"model": False}  # Simple readiness flag


def _require_port_available(host: str, port: int) -> None:
    """
    Fail fast if the requested port is already in use.
    Keeping a static, predictable port avoids mismatches with manifests/gateways.
    """
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            s.bind((host, port))
        except OSError as e:
            raise RuntimeError(
                f"Port {port} is already in use on {host}. "
                "Set WATSONX_AGENT_PORT/PORT to a free port."
            ) from e


def main() -> None:
    # Load env vars first (local .env honored)
    load_dotenv()

    API_KEY = os.getenv("WATSONX_API_KEY")
    URL = os.getenv("WATSONX_URL")
    PROJECT_ID = os.getenv("WATSONX_PROJECT_ID")
    MODEL_ID = os.getenv("MODEL_ID", "ibm/granite-3-3-8b-instruct")

    # Port selection: bind EXACTLY to what we’re asked to use.
    try:
        port = int(os.getenv("WATSONX_AGENT_PORT") or os.getenv("PORT") or DEFAULT_PORT)
    except ValueError:
        port = DEFAULT_PORT

    # Minimal, readable log format
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s - %(message)s",
    )
    log = logging.getLogger("watsonx-mcp")

    # Validate required env (fail fast)
    missing = [
        n
        for n, v in [
            ("WATSONX_API_KEY", API_KEY),
            ("WATSONX_URL", URL),
            ("WATSONX_PROJECT_ID", PROJECT_ID),
        ]
        if not v
    ]
    if missing:
        raise RuntimeError(f"Missing required env var(s): {', '.join(missing)}")

    # Ensure the chosen port is free (clearer error than letting uvicorn fail later)
    _require_port_available(HOST, port)

    # Initialize model client
    creds = Credentials(url=URL, api_key=API_KEY)
    model = ModelInference(model_id=MODEL_ID, credentials=creds, project_id=PROJECT_ID)
    READY["model"] = True

    # Define MCP server and tools
    mcp = FastMCP("Watsonx Chat Agent", port=port)

    @mcp.tool(description="Chat with IBM watsonx.ai (accepts str or int)")
    def chat(query: Union[str, int]) -> str:
        q = str(query).strip()
        if q == "0":
            q = "What is the capital of Italy?"
        log.info("chat() query=%r", q)

        params = {GenParams.DECODING_METHOD: "greedy", GenParams.MAX_NEW_TOKENS: 200}
        try:
            resp = model.generate_text(prompt=q, params=params, raw_response=True)
            reply = resp["results"][0]["generated_text"].strip()
        except Exception as e:
            log.exception("watsonx generate_text failed")
            return f"Error from watsonx: {e}"

        log.info("chat() reply=%r", reply)
        return reply

    # --------- HTTP endpoints (liveness/readiness) ----------
    async def health(_request):
        return JSONResponse({"status": "ok"})

    async def ready(_request):
        ok = all(READY.values())
        return JSONResponse(
            {"status": "ready" if ok else "not-ready", "checks": READY},
            status_code=200 if ok else 503,
        )

    async def live(_request):
        return PlainTextResponse("ok")

    # Build ASGI app: health routes first, then mount MCP SSE under /
    app = Starlette(
        routes=[
            Route("/health", health),
            Route("/healthz", health),
            Route("/readyz", ready),
            Route("/livez", live),
            Mount("/", app=mcp.sse_app()),  # exposes /sse
        ]
    )

    log.info("Starting Watsonx MCP on http://%s:%d/sse", HOST, port)
    uvicorn.run(app, host=HOST, port=port, log_level="info", access_log=False)


if __name__ == "__main__":
    main()
