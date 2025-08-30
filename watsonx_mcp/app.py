import os
import socket
import logging
import sys
from typing import Union

from dotenv import load_dotenv
from mcp.server.fastmcp import FastMCP

from ibm_watsonx_ai import Credentials
from ibm_watsonx_ai.foundation_models import ModelInference
from ibm_watsonx_ai.metanames import GenTextParamsMetaNames as GenParams
from ibm_watsonx_ai.wml_client_error import WMLClientError

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
    """Main function to configure and run the application."""
    # Load env vars first (local .env honored)
    load_dotenv()

    API_KEY = os.getenv("WATSONX_API_KEY")
    URL = os.getenv("WATSONX_URL")
    PROJECT_ID = os.getenv("WATSONX_PROJECT_ID")
    MODEL_ID = os.getenv("MODEL_ID", "ibm/granite-3-3-8b-instruct")

    # Port selection: bind EXACTLY to what we’re asked to use.
    try:
        port = int(os.getenv("WATSONX_AGENT_PORT") or DEFAULT_PORT)
    except ValueError:
        port = DEFAULT_PORT

    # Minimal, readable log format
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s - %(message)s",
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
        log.error(f"Missing required environment variable(s): {', '.join(missing)}")
        sys.exit(1)

    # Ensure the chosen port is free (clearer error than letting uvicorn fail later)
    _require_port_available(HOST, port)

    # --- FIX START ---
    # Initialize model client and proactively check credentials
    try:
        log.info("Authenticating with watsonx.ai...")
        creds = Credentials(url=URL, api_key=API_KEY)
        model = ModelInference(
            model_id=MODEL_ID, credentials=creds, project_id=PROJECT_ID
        )
        # This call forces authentication and will fail early if credentials are bad
        model.get_details()
        log.info("Successfully authenticated and connected to watsonx.ai.")
        READY["model"] = True
    except WMLClientError as e:
        log.error("------------------------------------------------------------------")
        log.error("Authentication with watsonx.ai failed. This is often due to an")
        log.error("invalid or expired 'WATSONX_API_KEY'.")
        log.error("Please verify your credentials and environment variables.")
        log.error(f"Reason: {e}")
        log.error("------------------------------------------------------------------")
        sys.exit(1)
    except Exception as e:
        log.exception("An unexpected error occurred during watsonx.ai initialization.")
        sys.exit(1)
    # --- FIX END ---


    # Define MCP server and tools
    mcp = FastMCP("Watsonx Chat Agent", port=port)

    @mcp.tool(description="Chat with IBM watsonx.ai")
    def chat(query: str) -> str:
        q = query.strip()
        log.info(f"Received chat query: '{q}'")

        params = {
            GenParams.DECODING_METHOD: "greedy",
            GenParams.MAX_NEW_TOKENS: 512,
        }
        try:
            resp = model.generate_text(prompt=q, params=params, raw_response=True)
            if resp and resp.get("results"):
                reply = resp["results"][0]["generated_text"].strip()
            else:
                log.warning("Received an empty or malformed response from watsonx.ai.")
                reply = "Sorry, I received an unexpected response from the model."
        except Exception as e:
            log.exception("watsonx generate_text failed")
            return f"An error occurred while communicating with watsonx.ai: {e}"

        log.info(f"Sending reply: '{reply}'")
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

    log.info(f"Starting MCP server on http://{HOST}:{port}")
    log.info("SSE events can be viewed in your browser or with 'curl -N http://%s:%d/sse'", HOST, port)
    uvicorn.run(app, host=HOST, port=port, log_level="warning", access_log=False)


if __name__ == "__main__":
    main()
