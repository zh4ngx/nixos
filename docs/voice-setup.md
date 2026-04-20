# Voice-to-Code Setup

Dictate from Android phone over Tailscale → NixOS host transcribes with Whisper → text injected into active Claude Code tmux session.

## Architecture

```
Android phone ──(audio over Tailnet)──→ Wyoming STT (0.0.0.0:10300, firewall: tailscale0 only)
                                             │
                                        STT bridge (TODO: Python Wyoming protocol parser)
                                             │
                                        /run/voice-stt.sock
                                             │
                                        voice-inject systemd user service
                                             │
                                        tmux send-keys → attached agent session
```

## NixOS Side

Configured across `modules/nixos/default.nix` and `modules/home-manager/default.nix`:

- **Wyoming Faster Whisper** on `tcp://0.0.0.0:10300` (firewall restricts to `tailscale0` interface)
- Model: `turbo` (faster than large-v3), English, CPU mode
- **voice-inject** systemd user service (starts at login, auto-detects attached tmux session)
- STT bridge placeholder (needs Python Wyoming protocol implementation)

### How targeting works

The voice-inject service re-evaluates the tmux target on every transcription:
1. Finds the session with an attached client (`session_attached == 1`)
2. Falls back to the first `*-co` / `*-cg` / `*-dev` session if nothing is attached
3. Injects text via `tmux send-keys`; appends Enter on wake phrases ("ship it", "send it", "execute", "do it")

### Manual testing

```bash
# Create a test socket
socat UNIX-LISTEN:/run/voice-stt.sock,fork -

# In another terminal, inject test text
echo "hello from voice" | socat - UNIX-CONNECT:/run/voice-stt.sock
```

### Tailscale endpoint

Use the host's MagicDNS name (not hardcoded IP): `<hostname>:10300`
The firewall only accepts connections on the `tailscale0` interface.

## Android Side

### Recommended Apps

| App | Notes |
|-----|-------|
| **Futo Voice Input** | Open source, can target custom STT endpoints, works system-wide |
| **Home Assistant Voice** | Uses Wyoming protocol natively, designed for this |

### Configuration

Point the app's STT server to your Tailscale hostname and port:
- Host: your machine's Tailscale MagicDNS name
- Port: `10300`
- Protocol: Wyoming (TCP)

The app must be on the same Tailnet. Install Tailscale on the phone from the Play Store or F-Droid.

## Status

- [x] Wyoming STT service configured (firewall-restricted to tailscale0)
- [x] voice-inject systemd user service (persistent, auto-targeting)
- [x] Socket read via socat (not fish stdin redirection)
- [ ] Wyoming protocol bridge implementation (Python recommended)
- [ ] ROCm GPU acceleration (module only supports cpu/cuda/auto)
- [ ] Android app tested with real audio
