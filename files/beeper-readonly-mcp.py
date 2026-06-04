#!/usr/bin/env python3
"""Read-only MCP wrapper for Beeper Desktop's local API."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any
from urllib.parse import quote

import httpx
from fastmcp import FastMCP


DEFAULT_BASE_URL = "http://127.0.0.1:23373"
DEFAULT_TOKEN_FILE = "/run/secrets/beeper_desktop_api_token"
MAX_ITEMS = 20
TIMEOUT_SECONDS = 10.0

mcp = FastMCP("beeper-readonly")


def _base_url() -> str:
    return os.environ.get("BEEPER_DESKTOP_BASE_URL", DEFAULT_BASE_URL).rstrip("/")


def _access_token() -> str:
    env_token = os.environ.get("BEEPER_ACCESS_TOKEN", "").strip()
    if env_token:
        return env_token

    token_path = Path(os.environ.get("BEEPER_ACCESS_TOKEN_FILE", DEFAULT_TOKEN_FILE))
    try:
        if token_path.is_file():
            return token_path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""
    return ""


def _auth_required() -> dict[str, Any]:
    return {
        "status": "auth_required",
        "message": (
            "Beeper Desktop API requires an access token. Start Beeper Desktop, "
            "enable Settings -> Integrations/Developers -> Desktop API, create "
            "an approved connection token, and add it to NixOS sops as "
            "beeper_desktop_api_token."
        ),
    }


def _clamp(count: int | None) -> int:
    if count is None:
        return 10
    return max(1, min(int(count), MAX_ITEMS))


def _quote_segment(value: str) -> str:
    return quote(value, safe="")


def _sanitize(value: Any, *, max_text_chars: int = 1000) -> Any:
    if isinstance(value, dict):
        result: dict[str, Any] = {}
        for key, item in value.items():
            if key in {"srcURL", "posterImg", "avatarURL", "thumbnailURL"}:
                continue
            if key == "attachments" and isinstance(item, list):
                result[key] = [_sanitize_attachment(attachment) for attachment in item[:MAX_ITEMS]]
                continue
            result[key] = _sanitize(item, max_text_chars=max_text_chars)
        return result

    if isinstance(value, list):
        return [_sanitize(item, max_text_chars=max_text_chars) for item in value[:MAX_ITEMS]]

    if isinstance(value, str):
        if len(value) > max_text_chars:
            return f"{value[:max_text_chars]}... [truncated]"
        return value

    return value


def _sanitize_attachment(value: Any) -> Any:
    if not isinstance(value, dict):
        return _sanitize(value)

    allowed = {
        "type",
        "fileName",
        "fileSize",
        "mimeType",
        "duration",
        "isGif",
        "isSticker",
        "isVoiceNote",
        "transcription",
    }
    return {key: _sanitize(item) for key, item in value.items() if key in allowed}


def _trim_items(data: Any, limit: int) -> Any:
    if isinstance(data, dict) and isinstance(data.get("items"), list):
        trimmed = dict(data)
        trimmed["items"] = data["items"][:limit]
        return trimmed
    if isinstance(data, list):
        return data[:limit]
    return data


def _get(
    path: str,
    *,
    params: list[tuple[str, str]] | None = None,
    require_auth: bool = True,
    limit: int | None = None,
    max_text_chars: int = 1000,
) -> dict[str, Any]:
    token = _access_token()
    if require_auth and not token:
        return _auth_required()

    headers = {"Accept": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    try:
        with httpx.Client(timeout=TIMEOUT_SECONDS) as client:
            response = client.get(f"{_base_url()}{path}", headers=headers, params=params)
            response.raise_for_status()
            data = response.json()
    except httpx.ConnectError:
        return {
            "status": "not_running",
            "message": "Beeper Desktop API is not reachable on 127.0.0.1:23373. Start Beeper Desktop first.",
        }
    except httpx.HTTPStatusError as exc:
        status_code = exc.response.status_code
        if status_code in {401, 403}:
            return {
                "status": "auth_failed",
                "http_status": status_code,
                "message": "Beeper Desktop API rejected the configured token.",
            }
        return {
            "status": "http_error",
            "http_status": status_code,
            "body": exc.response.text[:500],
        }
    except (httpx.HTTPError, ValueError) as exc:
        return {"status": "error", "message": str(exc)}

    if limit is not None:
        data = _trim_items(data, limit)
    return {"status": "ok", "data": _sanitize(data, max_text_chars=max_text_chars)}


@mcp.tool
def beeper_status() -> dict[str, Any]:
    """Check whether Beeper Desktop's local API is reachable."""
    return _get("/v1/info", require_auth=False, max_text_chars=500)


@mcp.tool
def beeper_search_messages(
    query: str,
    limit: int = 10,
    date_after: str | None = None,
    date_before: str | None = None,
    chat_id: str | None = None,
    account_id: str | None = None,
) -> dict[str, Any]:
    """Search existing Beeper messages. Read-only; returns at most 20 matches."""
    params: list[tuple[str, str]] = [("query", query), ("limit", str(_clamp(limit)))]
    if date_after:
        params.append(("dateAfter", date_after))
    if date_before:
        params.append(("dateBefore", date_before))
    if chat_id:
        params.append(("chatIDs", chat_id))
    if account_id:
        params.append(("accountIDs", account_id))
    return _get("/v1/messages/search", params=params, limit=_clamp(limit))


@mcp.tool
def beeper_search_chats(
    query: str,
    limit: int = 10,
    inbox: str | None = None,
    include_muted: bool = True,
) -> dict[str, Any]:
    """Search Beeper chats by title, network, or participant names. Read-only."""
    params: list[tuple[str, str]] = [
        ("query", query),
        ("limit", str(_clamp(limit))),
        ("includeMuted", "true" if include_muted else "false"),
    ]
    if inbox:
        params.append(("inbox", inbox))
    return _get("/v1/chats/search", params=params, limit=_clamp(limit), max_text_chars=500)


@mcp.tool
def beeper_get_chat(chat_id: str) -> dict[str, Any]:
    """Fetch metadata for one Beeper chat. Read-only."""
    return _get(f"/v1/chats/{_quote_segment(chat_id)}", max_text_chars=500)


@mcp.tool
def beeper_list_messages(
    chat_id: str,
    cursor: str | None = None,
    direction: str = "before",
    limit: int = 10,
) -> dict[str, Any]:
    """List recent messages from a chat with cursor pagination. Read-only."""
    params: list[tuple[str, str]] = []
    if cursor:
        params.append(("cursor", cursor))
    if direction not in {"before", "after"}:
        return {"status": "invalid_request", "message": "direction must be 'before' or 'after'."}
    params.append(("direction", direction))
    return _get(f"/v1/chats/{_quote_segment(chat_id)}/messages", params=params, limit=_clamp(limit))


@mcp.tool
def beeper_get_message(chat_id: str, message_id: str) -> dict[str, Any]:
    """Fetch one Beeper message by chat ID and message ID. Read-only."""
    path = f"/v1/chats/{_quote_segment(chat_id)}/messages/{_quote_segment(message_id)}"
    return _get(path)


if __name__ == "__main__":
    mcp.run(show_banner=False)
