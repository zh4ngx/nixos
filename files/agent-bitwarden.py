#!/usr/bin/env python3
"""Scoped Bitwarden credential helper for supervised agent browser sessions."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


DEFAULT_ALLOWLIST_FILE = "/run/secrets/bitwarden_agent_allowlist"
DEFAULT_SESSION_FILE = "/run/secrets/bitwarden_agent_session"
DEFAULT_BW_BIN = "bw"
ALIAS_RE = re.compile(r"^[A-Za-z0-9_.-]{1,80}$")
TIMEOUT_SECONDS = 20


class AgentBitwardenError(Exception):
    def __init__(self, status: str, message: str, **details: Any) -> None:
        super().__init__(message)
        self.status = status
        self.message = message
        self.details = details

    def as_dict(self) -> dict[str, Any]:
        return {"status": self.status, "message": self.message, **self.details}


def _read_file(path: str) -> str:
    try:
        return Path(path).read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def _allowlist_path() -> str:
    return os.environ.get("AGENT_BITWARDEN_ALLOWLIST_FILE", DEFAULT_ALLOWLIST_FILE)


def _session_path() -> str:
    return os.environ.get(
        "BITWARDEN_AGENT_SESSION_FILE",
        os.environ.get("BW_SESSION_FILE", DEFAULT_SESSION_FILE),
    )


def _load_allowlist() -> dict[str, dict[str, Any]]:
    path = _allowlist_path()
    text = _read_file(path)
    if not text:
        raise AgentBitwardenError(
            "config_required",
            f"Bitwarden delegated allowlist is empty or unreadable at {path}.",
        )

    try:
        raw = json.loads(text)
    except json.JSONDecodeError as exc:
        raise AgentBitwardenError(
            "invalid_config",
            f"Bitwarden delegated allowlist is not valid JSON: {exc.msg}.",
        ) from exc

    if not isinstance(raw, dict):
        raise AgentBitwardenError("invalid_config", "Bitwarden allowlist must be a JSON object.")

    allowlist: dict[str, dict[str, Any]] = {}
    for alias, value in raw.items():
        if not isinstance(alias, str) or not ALIAS_RE.fullmatch(alias):
            raise AgentBitwardenError(
                "invalid_config",
                f"Invalid Bitwarden alias {alias!r}; use letters, numbers, dot, dash, or underscore.",
            )

        if isinstance(value, str):
            item_id = value.strip()
            label = alias
            uris: list[str] = []
        elif isinstance(value, dict):
            item_id = str(value.get("item_id") or value.get("id") or "").strip()
            label = str(value.get("label") or alias)
            raw_uris = value.get("uris") or value.get("urls") or []
            if isinstance(raw_uris, str):
                uris = [raw_uris]
            elif isinstance(raw_uris, list):
                uris = [str(uri) for uri in raw_uris if str(uri).strip()]
            else:
                uris = []
        else:
            raise AgentBitwardenError(
                "invalid_config",
                f"Allowlist entry for {alias!r} must be an item id string or object.",
            )

        if item_id:
            allowlist[alias] = {
                "alias": alias,
                "label": label,
                "item_id": item_id,
                "uris": uris,
            }

    if not allowlist:
        raise AgentBitwardenError(
            "config_required",
            "Bitwarden delegated allowlist has no item ids.",
        )
    return allowlist


def _session() -> str:
    session = os.environ.get("BITWARDEN_AGENT_SESSION", "").strip()
    if not session:
        session = os.environ.get("BW_SESSION", "").strip()
    if not session:
        session = _read_file(_session_path())
    if session in {"UNSET", "REPLACE_ME", "replace-me"}:
        session = ""
    if not session:
        raise AgentBitwardenError(
            "auth_required",
            "Bitwarden session is missing. Unlock bw and store the session in bitwarden_agent_session.",
        )
    return session


def _safe_entries(allowlist: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "alias": entry["alias"],
            "label": entry["label"],
            "uris": entry["uris"],
        }
        for entry in allowlist.values()
    ]


def _run_bw_get_item(item_id: str) -> dict[str, Any]:
    bw_bin = os.environ.get("AGENT_BITWARDEN_BW_BIN", DEFAULT_BW_BIN)
    env = os.environ.copy()
    env["BW_SESSION"] = _session()

    try:
        result = subprocess.run(
            [bw_bin, "get", "item", item_id],
            check=False,
            capture_output=True,
            env=env,
            text=True,
            timeout=TIMEOUT_SECONDS,
        )
    except FileNotFoundError as exc:
        raise AgentBitwardenError("missing_dependency", f"Bitwarden CLI not found: {bw_bin}.") from exc
    except subprocess.TimeoutExpired as exc:
        raise AgentBitwardenError("timeout", "Bitwarden CLI timed out.") from exc

    if result.returncode != 0:
        stderr = result.stderr.strip()[:500]
        raise AgentBitwardenError(
            "bitwarden_error",
            "Bitwarden CLI could not read the delegated item.",
            stderr=stderr,
        )

    try:
        item = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise AgentBitwardenError("bitwarden_error", "Bitwarden CLI returned invalid JSON.") from exc
    if not isinstance(item, dict):
        raise AgentBitwardenError("bitwarden_error", "Bitwarden CLI returned an unexpected item shape.")
    return item


def _get_login(alias: str) -> dict[str, Any]:
    allowlist = _load_allowlist()
    entry = allowlist.get(alias)
    if entry is None:
        raise AgentBitwardenError(
            "not_allowed",
            f"{alias!r} is not in the delegated Bitwarden allowlist.",
            allowed_aliases=sorted(allowlist.keys()),
        )

    item = _run_bw_get_item(entry["item_id"])
    login = item.get("login") if isinstance(item.get("login"), dict) else {}
    username = str(login.get("username") or "")
    password = str(login.get("password") or "")
    item_uris = login.get("uris") if isinstance(login.get("uris"), list) else []
    uris = entry["uris"] or [
        str(uri.get("uri"))
        for uri in item_uris
        if isinstance(uri, dict) and uri.get("uri")
    ]

    return {
        "status": "ok",
        "alias": alias,
        "label": entry["label"],
        "username": username,
        "password": password,
        "uris": uris,
        "two_factor": {
            "totp": "not_provided",
            "sms": "Use beeper-readonly to read existing SMS codes when supervised browser login triggers one.",
        },
    }


def _status() -> dict[str, Any]:
    allowlist_configured = True
    session_configured = True
    aliases: list[str] = []

    try:
        aliases = sorted(_load_allowlist().keys())
    except AgentBitwardenError:
        allowlist_configured = False

    try:
        _session()
    except AgentBitwardenError:
        session_configured = False

    return {
        "status": "ok",
        "allowlist_configured": allowlist_configured,
        "session_configured": session_configured,
        "allowed_aliases": aliases,
        "allowlist_file": _allowlist_path(),
        "session_file": _session_path(),
    }


def _emit(payload: dict[str, Any], *, as_json: bool, status: int = 0) -> int:
    if as_json:
        print(json.dumps(payload, sort_keys=True))
    elif status == 0:
        if payload.get("status") == "ok" and "entries" in payload:
            for entry in payload["entries"]:
                print(f"{entry['alias']}\t{entry['label']}")
        else:
            print(json.dumps(payload, sort_keys=True, indent=2))
    else:
        print(payload.get("message", payload), file=sys.stderr)
    return status


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="emit JSON")
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("status")
    subparsers.add_parser("list")
    get_parser = subparsers.add_parser("get")
    get_parser.add_argument("alias")
    args = parser.parse_args(argv)

    try:
        if args.command == "status":
            return _emit(_status(), as_json=args.json)
        if args.command == "list":
            allowlist = _load_allowlist()
            return _emit({"status": "ok", "entries": _safe_entries(allowlist)}, as_json=args.json)
        if args.command == "get":
            return _emit(_get_login(args.alias), as_json=args.json)
    except AgentBitwardenError as exc:
        return _emit(exc.as_dict(), as_json=args.json, status=1)

    return _emit({"status": "invalid_request", "message": "Unknown command."}, as_json=args.json, status=64)


if __name__ == "__main__":
    raise SystemExit(main())
