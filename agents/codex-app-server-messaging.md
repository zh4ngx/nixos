# Codex App-Server Messaging

Use this for Codex sessions launched through `cx`.

`cx` starts `codex-app-server.service` and attaches the TUI with:

```text
--remote ws://127.0.0.1:4107
```

Do not use zellij for those sessions unless the app-server path is unavailable.
Zellij is fallback for raw/non-remote TUIs only.

## Protocol

Codex app-server is JSON-RPC over a long-lived WebSocket, not fire-and-forget
HTTP.

Endpoint:

```text
ws://127.0.0.1:4107
```

Required flow:

1. Open WebSocket.
2. Send `initialize`.
3. Find the target with `thread/list`, usually by `cwd`.
4. Send `turn/start`.
5. Keep the socket open for `item/agentMessage/delta`, `turn/completed`,
   `thread/status/changed`, errors, and approval requests.

Closing immediately after `turn/start` can still deliver the message, but the
caller will lose readback and may see a close-time client error.

## Initialize

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "clientInfo": {
      "name": "codex-app-server-client",
      "title": "Codex app-server client",
      "version": "0.1.0"
    },
    "capabilities": {
      "experimentalApi": true
    }
  }
}
```

## Find The Live Thread

For this NixOS project agent:

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "thread/list",
  "params": {
    "cwd": "/home/andy/nixos",
    "limit": 12,
    "sortKey": "updated_at",
    "sortDirection": "desc",
    "archived": false,
    "useStateDbOnly": false
  }
}
```

Pick the active CLI thread:

```text
thread.source == "cli" && thread.status.type == "active"
```

If there is no active CLI thread, pick the newest `source == "cli"` thread for
that cwd, or start/resume a thread deliberately. Do not hard-code thread ids
except in a short manual test.

## Send A Message

The important shape is `params.input`: it is an array of Codex `UserInput`
objects. It is not OpenCode's `{parts:[...]}` payload, and it is not a string.

```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "turn/start",
  "params": {
    "threadId": "<current-thread-id>",
    "input": [
      {
        "type": "text",
        "text": "hi",
        "text_elements": []
      }
    ],
    "cwd": "/home/andy/nixos",
    "model": "gpt-5.5",
    "effort": "xhigh",
    "approvalPolicy": "never",
    "sandboxPolicy": {
      "type": "dangerFullAccess"
    }
  }
}
```

Known bad payloads:

```json
{"message":{"parts":[{"type":"text","text":"hi"}]}}
```

```json
{"input":"hi"}
```

## Minimal Adapter Behavior

A real adapter should keep one WebSocket open, maintain target mappings, and
track active turns:

```text
target cwd -> active cli thread id
thread id -> active turn id
turn id -> caller correlation id / reply_to
```

It should route these notifications back to the orchestrator:

```text
item/agentMessage/delta
turn/completed
thread/status/changed
error
```

OpenCode and Codex are different transports:

```text
OpenCode: POST /session/<id>/prompt_async, fire-and-forget HTTP
Codex:    JSON-RPC over long-lived WebSocket, keep open for completion
```

Regenerate local protocol types when unsure:

```bash
codex app-server generate-ts --experimental --out /tmp/codex-app-ts
codex app-server generate-json-schema --experimental --out /tmp/codex-app-schema
```
