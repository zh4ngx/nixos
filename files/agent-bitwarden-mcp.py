#!/usr/bin/env python3
"""MCP server exposing only delegated Bitwarden login aliases."""

from __future__ import annotations

import json
import os
import subprocess
from typing import Any

from fastmcp import FastMCP


DEFAULT_COMMAND = "/etc/profiles/per-user/andy/bin/agent-bitwarden"
TIMEOUT_SECONDS = 25

mcp = FastMCP("bitwarden-delegated")


def _command() -> str:
    return os.environ.get("AGENT_BITWARDEN_COMMAND", DEFAULT_COMMAND)


def _run_agent_bitwarden(*args: str) -> dict[str, Any]:
    try:
        result = subprocess.run(
            [_command(), "--json", *args],
            check=False,
            capture_output=True,
            env=os.environ.copy(),
            text=True,
            timeout=TIMEOUT_SECONDS,
        )
    except FileNotFoundError:
        return {"status": "missing_dependency", "message": f"agent-bitwarden not found: {_command()}"}
    except subprocess.TimeoutExpired:
        return {"status": "timeout", "message": "agent-bitwarden timed out."}

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError:
        payload = {
            "status": "error",
            "message": "agent-bitwarden returned non-JSON output.",
            "stderr": result.stderr[:500],
        }

    if result.returncode != 0 and payload.get("status") == "ok":
        payload["status"] = "error"
    return payload


@mcp.tool
def bitwarden_delegated_status() -> dict[str, Any]:
    """Check delegated Bitwarden allowlist and session readiness."""
    return _run_agent_bitwarden("status")


@mcp.tool
def bitwarden_list_delegated_logins() -> dict[str, Any]:
    """List aliases available through the delegated Bitwarden wrapper."""
    return _run_agent_bitwarden("list")


@mcp.tool
def bitwarden_get_delegated_login(alias: str) -> dict[str, Any]:
    """Return username/password only for a delegated alias, never arbitrary item ids."""
    return _run_agent_bitwarden("get", alias)


if __name__ == "__main__":
    mcp.run(show_banner=False)
