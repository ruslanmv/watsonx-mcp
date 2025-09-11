import os
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

# --- Global State Management ---
# Extended readiness flags to provide more granular status.
# The server will run, but these flags will control its "ready" state.
READY = {"configuration": False, "model": False}
# Store the specific error message to show the user.
CONFIGURATION_ERROR_MESSAGE = "The agent has not been configured yet."


def main() -> None:
    """Main function to configure and run the application."""
    global CONFIGURATION_ERROR_MESSAGE # Allow modification of the global variable

    # NOTE: Re-introducing dotenv call. It will load a local .env if present,
    # but will not override variables already set by the parent demo script.
    load_dotenv()

    API_KEY = os.getenv("WATSONX_API_KEY")
    URL = os.getenv("WATSONX_URL")
    PROJECT_ID = os.getenv("WATSONX_PROJECT_ID")
    MODEL_ID = os.getenv("MODEL_ID", "ibm/granite-3-3-8b-instruct")

    # Port selection: Trust the port provided by the matrix runtime environment.
    try:
        # The launcher script maps the 'PORT' env var to 'WATSONX_AGENT_PORT'
        port = int(os.environ["WATSONX_AGENT_PORT"])
    except (KeyError, ValueError):
        print("FATAL: Port not provided by runtime environment.", file=sys.stderr)
        sys.exit(1)


    # Minimal, readable log format
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s - %(message)s",
    )
    log = logging.getLogger("watsonx-agent")

    # --- MODIFIED: Validate required env but DO NOT fail fast ---
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
        # Instead of exiting, we set the state and an informative error message.
        # The server will start, but will be in a "not-ready" state.
        error_str = f"Missing required environment variable(s): {', '.join(missing)}"
        log.error(error_str)
        CONFIGURATION_ERROR_MESSAGE = (
            "Configuration Error: Please set the following environment variables: "
            f"{', '.join(missing)}"
        )
        READY["configuration"] = False
    else:
        log.info("All required environment variables are present.")
        READY["configuration"] = True


    # --- MODIFIED: Authentication logic only runs if configuration is present ---
    if READY["configuration"]:
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
            # Instead of exiting, we log the error, set the state, and update the message.
            log.error("------------------------------------------------------------------")
            log.error("Authentication with watsonx.ai failed. This is often due to an")
            log.error("invalid or expired 'WATSONX_API_KEY'.")
            log.error("Please verify your credentials and environment variables.")
            log.error(f"Reason: {e}")
            log.error("------------------------------------------------------------------")
            CONFIGURATION_ERROR_MESSAGE = (
                "Authentication Error: Could not connect to watsonx.ai. "
                "Please check your API key, URL, and Project ID. "
                f"Details: {e}"
            )
            READY["model"] = False
        except Exception as e:
            # Catch any other unexpected errors during initialization.
            log.exception("An unexpected error occurred during watsonx.ai initialization.")
            CONFIGURATION_ERROR_MESSAGE = f"An unexpected error occurred: {e}"
            READY["model"] = False

    # Define MCP server and tools
    mcp = FastMCP("Watsonx Chat Agent", port=port)

    @mcp.tool(description="Chat with IBM watsonx.ai")
    def chat(query: str) -> str:
        # --- MODIFIED: Check readiness before processing ---
        # If the model isn't ready, notify the user with the specific error.
        if not READY.get("model"):
            log.warning(f"Chat query received but model is not ready. Notifying user.")
            return CONFIGURATION_ERROR_MESSAGE

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
        # Health/Liveness: The server is running and responding.
        return JSONResponse({"status": "ok"})

    async def ready(_request):
        # Readiness: Is the server ready to perform its core function?
        # This now depends on our global state.
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
            Route("/healthz", health), # Common alias
            Route("/readyz", ready),  # Common alias
            Route("/livez", live),    # Common alias
            Mount("/", app=mcp.sse_app()), # exposes /sse
        ]
    )

    log.info(f"Starting MCP server on http://{HOST}:{port}")
    log.info("SSE events can be viewed in your browser or with 'curl -N http://%s:%d/sse'", HOST, port)
    uvicorn.run(app, host=HOST, port=port, log_level="warning", access_log=False)


if __name__ == "__main__":
    main()
