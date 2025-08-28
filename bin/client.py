#!/usr/bin/env python
"""
Minimal client for the Watsonx MCP server.

Usage examples:
  python clienty.py
  python clienty.py --query "What are the main attractions in Rome?"
  python clienty.py --port 6289
  python clienty.py --host 0.0.0.0 --path /sse
"""

import argparse
import logging
from typing import Any, Iterable

import anyio
from mcp.client.sse import sse_client
from mcp.client.session import ClientSession


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Simple MCP client for Watsonx Chat Agent")
    p.add_argument(
        "--host", default="127.0.0.1", help="Server host (default: 127.0.0.1)"
    )
    p.add_argument("--port", type=int, default=6288, help="Server port (default: 6288)")
    p.add_argument("--path", default="/sse", help="SSE path (default: /sse)")
    p.add_argument(
        "--query",
        default="What are the main attractions in Rome?",
        help="Prompt sent to the 'chat' tool",
    )
    p.add_argument("--debug", action="store_true", help="Enable debug logging")
    return p.parse_args()


def _extract_text(content: Iterable[Any]) -> str:
    """Best-effort extraction of text from MCP tool response content."""
    texts = []
    for item in content or []:
        if isinstance(item, dict):
            if item.get("type") == "text" and item.get("text"):
                texts.append(item["text"])
        else:
            typ = getattr(item, "type", None)
            txt = getattr(item, "text", None)
            if typ == "text" and txt:
                texts.append(txt)
    return "\n".join(texts).strip()


async def run_client(host: str, port: int, path: str, query: str) -> None:
    server_url = f"http://{host}:{port}{path}"
    logging.info("Connecting to %s ...", server_url)

    try:
        # 1) Open SSE transport
        async with sse_client(server_url) as (read_stream, write_stream):
            # 2) Start MCP session
            async with ClientSession(read_stream, write_stream) as session:
                # 3) Handshake
                await session.initialize()
                logging.info("Session initialized; calling tool 'chat' ...")

                # Optional: verify tool exists (won't fail if it doesn't)
                try:
                    tools = await session.list_tools()
                    tool_names = [
                        t.name if hasattr(t, "name") else getattr(t, "tool", "unknown")
                        for t in tools or []
                    ]
                    if "chat" not in tool_names:
                        logging.warning(
                            "Tool 'chat' not advertised by server (tools: %s)",
                            ", ".join(tool_names),
                        )
                except Exception:
                    pass  # non-fatal; continue

                # 4) Call the tool
                result = await session.call_tool("chat", {"query": query})

                # Handle different client return shapes
                is_error = False
                for attr in ("is_error", "isError"):
                    if hasattr(result, attr):
                        is_error = bool(getattr(result, attr))
                        break

                if is_error:
                    logging.error("Tool returned an error: %r", result)
                    return

                content = getattr(result, "content", None)
                text = _extract_text(content) if content is not None else ""
                if text:
                    print("\n--- reply ---\n" + text + "\n--------------\n")
                else:
                    logging.warning("Empty content from tool; full result: %r", result)

    except anyio.exceptions.ConnectError:
        logging.error("Connection failed. Is the server running on %s?", server_url)
    except Exception as e:
        logging.exception("Unexpected error: %s", e)


def main() -> None:
    args = parse_args()
    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        format="%(asctime)s [%(levelname)s] %(message)s",
    )
    anyio.run(run_client, args.host, args.port, args.path, args.query)


if __name__ == "__main__":
    main()
