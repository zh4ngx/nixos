#!/usr/bin/env python3
import asyncio
import base64
import io
import json
import os
import sys
import urllib.error
import urllib.request
import wave
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from wyoming.asr import Transcribe, Transcript
from wyoming.audio import AudioChunk, AudioStart, AudioStop
from wyoming.event import async_read_event, async_write_event


HOST = os.environ.get("GEMMA_VOICE_HOST", "127.0.0.1")
PORT = int(os.environ.get("GEMMA_VOICE_PORT", "18082"))
WYOMING_HOST = os.environ.get("GEMMA_VOICE_WYOMING_HOST", "127.0.0.1")
WYOMING_PORT = int(os.environ.get("GEMMA_VOICE_WYOMING_PORT", "10300"))
LLAMA_BASE_URL = os.environ.get("GEMMA_VOICE_LLAMA_BASE_URL", "http://127.0.0.1:8080/v1")
LLAMA_MODEL = os.environ.get("GEMMA_VOICE_LLAMA_MODEL", "google/gemma-4-12B-it-qat-q4_0-gguf:Q4_0")
DEFAULT_SYSTEM_PROMPT = os.environ.get("GEMMA_VOICE_SYSTEM_PROMPT", "").strip()


INDEX_HTML = r"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Gemma Voice</title>
  <style>
    :root {
      color-scheme: dark light;
      --bg: #101214;
      --panel: #181b1f;
      --muted: #a7b0ba;
      --text: #f4f6f8;
      --line: #2b3138;
      --accent: #39a275;
      --accent-strong: #49bf8d;
      --danger: #d76161;
    }
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100dvh;
      background: var(--bg);
      color: var(--text);
      font: 15px/1.45 system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    main {
      display: grid;
      grid-template-rows: auto 1fr auto;
      min-height: 100dvh;
      max-width: 920px;
      margin: 0 auto;
    }
    header {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      padding: 14px 16px;
      border-bottom: 1px solid var(--line);
    }
    h1 {
      margin: 0;
      font-size: 16px;
      font-weight: 650;
      letter-spacing: 0;
    }
    #status {
      min-width: 8rem;
      color: var(--muted);
      font-size: 13px;
      text-align: right;
    }
    #messages {
      padding: 16px;
      overflow-y: auto;
    }
    .message {
      max-width: 78ch;
      margin: 0 0 14px;
      padding: 10px 12px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--panel);
      white-space: pre-wrap;
    }
    .user { margin-left: auto; border-color: color-mix(in srgb, var(--accent) 55%, var(--line)); }
    .assistant { margin-right: auto; }
    .role {
      margin-bottom: 4px;
      color: var(--muted);
      font-size: 12px;
      text-transform: uppercase;
      letter-spacing: .04em;
    }
    form {
      display: grid;
      grid-template-columns: auto 1fr auto;
      gap: 10px;
      padding: 14px 16px 16px;
      border-top: 1px solid var(--line);
      background: color-mix(in srgb, var(--bg) 88%, black);
    }
    textarea {
      min-height: 48px;
      max-height: 160px;
      resize: vertical;
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 10px 12px;
      background: var(--panel);
      color: var(--text);
    }
    button {
      min-width: 88px;
      min-height: 44px;
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 0 14px;
      background: var(--panel);
      color: var(--text);
      font-weight: 650;
      cursor: pointer;
    }
    button.primary {
      border-color: color-mix(in srgb, var(--accent) 70%, var(--line));
      background: var(--accent);
      color: #06130d;
    }
    button.recording {
      border-color: var(--danger);
      background: color-mix(in srgb, var(--danger) 24%, var(--panel));
    }
    button:disabled, textarea:disabled {
      opacity: .55;
      cursor: not-allowed;
    }
    @media (max-width: 680px) {
      main { max-width: none; }
      form { grid-template-columns: 1fr; }
      button { width: 100%; }
      #status { min-width: 0; }
    }
  </style>
</head>
<body>
<main>
  <header>
    <h1>Gemma Voice</h1>
    <div id="status">ready</div>
  </header>
  <section id="messages"></section>
  <form id="composer">
    <button id="record" type="button">Record</button>
    <textarea id="input" placeholder="Type or record a message"></textarea>
    <button id="send" class="primary" type="submit">Send</button>
  </form>
</main>
<script>
const messagesEl = document.getElementById("messages");
const statusEl = document.getElementById("status");
const inputEl = document.getElementById("input");
const sendBtn = document.getElementById("send");
const recordBtn = document.getElementById("record");
const form = document.getElementById("composer");
const history = [];
let recorder = null;
let busy = false;

function setStatus(text) {
  statusEl.textContent = text;
}

function addMessage(role, text) {
  const item = document.createElement("article");
  item.className = `message ${role}`;
  const label = document.createElement("div");
  label.className = "role";
  label.textContent = role;
  const body = document.createElement("div");
  body.textContent = text;
  item.append(label, body);
  messagesEl.append(item);
  messagesEl.scrollTop = messagesEl.scrollHeight;
}

function setBusy(next) {
  busy = next;
  inputEl.disabled = next;
  sendBtn.disabled = next;
  recordBtn.disabled = next && !recorder;
}

async function postJson(path, payload) {
  const response = await fetch(path, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error || `HTTP ${response.status}`);
  }
  return data;
}

async function sendText(text) {
  setBusy(true);
  setStatus("thinking");
  addMessage("user", text);
  const requestHistory = history.concat([{ role: "user", content: text }]);
  try {
    const data = await postJson("api/chat", { history: requestHistory });
    history.push({ role: "user", content: text }, { role: "assistant", content: data.assistant });
    addMessage("assistant", data.assistant);
    setStatus("ready");
  } catch (error) {
    setStatus("error");
    addMessage("assistant", `Error: ${error.message}`);
  } finally {
    setBusy(false);
  }
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const text = inputEl.value.trim();
  if (!text || busy) return;
  inputEl.value = "";
  await sendText(text);
});

function mergeBuffers(buffers) {
  const total = buffers.reduce((sum, buf) => sum + buf.length, 0);
  const result = new Float32Array(total);
  let offset = 0;
  for (const buf of buffers) {
    result.set(buf, offset);
    offset += buf.length;
  }
  return result;
}

function downsample(buffer, inputRate, outputRate) {
  if (inputRate === outputRate) return buffer;
  const ratio = inputRate / outputRate;
  const length = Math.round(buffer.length / ratio);
  const result = new Float32Array(length);
  for (let i = 0; i < length; i++) {
    const start = Math.floor(i * ratio);
    const end = Math.min(Math.floor((i + 1) * ratio), buffer.length);
    let sum = 0;
    for (let j = start; j < end; j++) sum += buffer[j];
    result[i] = sum / Math.max(1, end - start);
  }
  return result;
}

function encodeWav(samples, sampleRate) {
  const bytes = new ArrayBuffer(44 + samples.length * 2);
  const view = new DataView(bytes);
  const writeString = (offset, value) => {
    for (let i = 0; i < value.length; i++) view.setUint8(offset + i, value.charCodeAt(i));
  };
  writeString(0, "RIFF");
  view.setUint32(4, 36 + samples.length * 2, true);
  writeString(8, "WAVE");
  writeString(12, "fmt ");
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, sampleRate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  writeString(36, "data");
  view.setUint32(40, samples.length * 2, true);
  let offset = 44;
  for (const sample of samples) {
    const clamped = Math.max(-1, Math.min(1, sample));
    view.setInt16(offset, clamped < 0 ? clamped * 0x8000 : clamped * 0x7fff, true);
    offset += 2;
  }
  return new Blob([view], { type: "audio/wav" });
}

async function startRecording() {
  const stream = await navigator.mediaDevices.getUserMedia({
    audio: { channelCount: 1, echoCancellation: true, noiseSuppression: true, autoGainControl: true },
  });
  const context = new AudioContext();
  const source = context.createMediaStreamSource(stream);
  const processor = context.createScriptProcessor(4096, 1, 1);
  const buffers = [];
  processor.onaudioprocess = (event) => {
    buffers.push(new Float32Array(event.inputBuffer.getChannelData(0)));
  };
  source.connect(processor);
  processor.connect(context.destination);
  recorder = {
    stop: async () => {
      processor.disconnect();
      source.disconnect();
      for (const track of stream.getTracks()) track.stop();
      const inputRate = context.sampleRate;
      await context.close();
      const merged = mergeBuffers(buffers);
      return encodeWav(downsample(merged, inputRate, 16000), 16000);
    },
  };
}

async function blobToBase64(blob) {
  const bytes = new Uint8Array(await blob.arrayBuffer());
  let binary = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

recordBtn.addEventListener("click", async () => {
  if (busy && !recorder) return;
  if (!recorder) {
    try {
      setStatus("recording");
      recordBtn.textContent = "Stop";
      recordBtn.classList.add("recording");
      await startRecording();
    } catch (error) {
      recorder = null;
      recordBtn.textContent = "Record";
      recordBtn.classList.remove("recording");
      setStatus("mic error");
      addMessage("assistant", `Microphone error: ${error.message}`);
    }
    return;
  }

  const active = recorder;
  recorder = null;
  recordBtn.textContent = "Record";
  recordBtn.classList.remove("recording");
  setBusy(true);
  setStatus("transcribing");
  try {
    const wav = await active.stop();
    const audioBase64 = await blobToBase64(wav);
    const data = await postJson("api/voice-chat", { audio_base64: audioBase64, history });
    history.push({ role: "user", content: data.transcript }, { role: "assistant", content: data.assistant });
    addMessage("user", data.transcript);
    addMessage("assistant", data.assistant);
    setStatus("ready");
  } catch (error) {
    setStatus("error");
    addMessage("assistant", `Error: ${error.message}`);
  } finally {
    setBusy(false);
  }
});
</script>
</body>
</html>
"""


async def transcribe_wav(audio_bytes: bytes) -> str:
    with wave.open(io.BytesIO(audio_bytes), "rb") as wav:
        rate = wav.getframerate()
        width = wav.getsampwidth()
        channels = wav.getnchannels()
        if rate != 16000 or width != 2 or channels != 1:
            raise ValueError(f"expected 16 kHz mono s16 WAV, got rate={rate} width={width} channels={channels}")

        reader, writer = await asyncio.open_connection(WYOMING_HOST, WYOMING_PORT)
        try:
            await async_write_event(Transcribe(language="en").event(), writer)
            await async_write_event(AudioStart(rate=rate, width=width, channels=channels).event(), writer)
            while True:
                chunk = wav.readframes(4096)
                if not chunk:
                    break
                await async_write_event(AudioChunk(audio=chunk, rate=rate, width=width, channels=channels).event(), writer)
            await async_write_event(AudioStop().event(), writer)

            while True:
                event = await async_read_event(reader)
                if event is None:
                    break
                if Transcript.is_type(event.type):
                    return Transcript.from_event(event).text.strip()
        finally:
            writer.close()
            await writer.wait_closed()
    return ""


def with_default_system_prompt(messages):
    if not DEFAULT_SYSTEM_PROMPT:
        return messages
    if any(isinstance(message, dict) and message.get("role") == "system" for message in messages):
        return messages
    return [{"role": "system", "content": DEFAULT_SYSTEM_PROMPT}] + messages


def llama_chat(messages):
    payload = {
        "model": LLAMA_MODEL,
        "messages": with_default_system_prompt(messages),
        "max_tokens": 768,
        "temperature": 0.4,
    }
    body = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{LLAMA_BASE_URL.rstrip('/')}/chat/completions",
        data=body,
        headers={"content-type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", "replace")
        raise RuntimeError(f"llama server HTTP {exc.code}: {detail}") from exc
    return data["choices"][0]["message"]["content"].strip()


class Handler(BaseHTTPRequestHandler):
    server_version = "gemma-voice-chat/0.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    def _send(self, status, content_type, body: bytes):
        self.send_response(status)
        self.send_header("content-type", content_type)
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _json(self, status, value):
        self._send(status, "application/json", json.dumps(value).encode("utf-8"))

    def _read_json(self):
        length = int(self.headers.get("content-length", "0"))
        if length > 24 * 1024 * 1024:
            raise ValueError("request body too large")
        return json.loads(self.rfile.read(length).decode("utf-8"))

    def do_GET(self):
        if self.path in {"/", "/index.html"}:
            self._send(200, "text/html; charset=utf-8", INDEX_HTML.encode("utf-8"))
        elif self.path == "/health":
            self._json(200, {"ok": True})
        else:
            self._json(404, {"error": "not found"})

    def do_POST(self):
        try:
            payload = self._read_json()
            history = payload.get("history") or []
            if not isinstance(history, list):
                raise ValueError("history must be a list")

            if self.path == "/api/chat":
                assistant = llama_chat(history)
                self._json(200, {"assistant": assistant})
                return

            if self.path == "/api/voice-chat":
                audio_b64 = payload.get("audio_base64")
                if not isinstance(audio_b64, str) or not audio_b64:
                    raise ValueError("audio_base64 is required")
                audio_bytes = base64.b64decode(audio_b64, validate=True)
                transcript = asyncio.run(transcribe_wav(audio_bytes))
                if not transcript:
                    raise ValueError("empty transcript")
                messages = history + [{"role": "user", "content": transcript}]
                assistant = llama_chat(messages)
                self._json(200, {"transcript": transcript, "assistant": assistant})
                return

            self._json(404, {"error": "not found"})
        except Exception as exc:
            self._json(500, {"error": str(exc)})


def main():
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"gemma voice chat listening on http://{HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
