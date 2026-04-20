# Voice-to-Code Setup

Dictate from Android phone over Tailscale → NixOS host transcribes with Whisper → text injected into active Claude Code tmux session.

## Architecture

```
Android phone ──(audio over Tailscale)──→ Wyoming STT (100.80.128.117:10300)
                                              │
                                         voice-stt-bridge
                                              │
                                         /run/voice-stt.sock
                                              │
                                         voice-inject (vi)
                                              │
                                         tmux send-keys → agent session
```

## NixOS Side

Already configured in `modules/nixos/default.nix`:

- **Wyoming Faster Whisper** on `tcp://100.80.128.117:10300` (Tailscale interface only)
- Model: `turbo` (faster than large-v3), English, CPU mode
- `voice-stt-bridge` placeholder script (needs Wyoming protocol implementation)
- `vi` fish function for injecting transcriptions into tmux

### Manual testing

```bash
# Start a Wyoming listener that writes to the socket
socat UNIX-LISTEN:/run/voice-stt.sock,fork STDOUT

# In another terminal, inject test text
echo "hello from voice" | socat - UNIX-CONNECT:/run/voice-stt.sock

# Or use vi directly with a test file
echo "test transcription" | vi dev-co
```

### Tailscale endpoint

The STT server is at: `ws://100.80.128.117:10300` (Wyoming protocol over TCP)

## Android Side

### Recommended Apps

| App | Notes |
|-----|-------|
| **Futo Voice Input** | Open source, can target custom STT endpoints, works system-wide |
| **Home Assistant Voice** | Uses Wyoming protocol natively, designed for this |

### Configuration

Point the app's STT server to your Tailscale IP and port:
- Host: `100.80.128.117`
- Port: `10300`
- Protocol: Wyoming (TCP)

The app must be on the same Tailnet. Install Tailscale on the phone from the Play Store or F-Droid.

## Status

- [x] Wyoming STT service configured
- [x] voice-inject fish function (`vi`)
- [x] Unix socket bridge placeholder
- [ ] Wyoming protocol bridge implementation (Python recommended)
- [ ] ROCm GPU acceleration (module only supports cpu/cuda/auto)
- [ ] Android app tested with real audio
