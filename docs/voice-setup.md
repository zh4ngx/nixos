# Voice STT Setup

## Desktop Dictation

Primary desktop dictation is VoxType:

```
Super+V -> voxtype record toggle -> whisper.cpp Vulkan -> type at cursor
```

Configured by:

- `modules/home-manager/voxtype.nix`: local Home Manager module, user service, Waybar module, GNOME binding, niri snippet, post-process hook wrapper
- `modules/home-manager/default.nix`: VoxType model/settings
- `modules/nixos/default.nix`: niri package, `uinput`, and `ydotoold`

Current behavior:

- `voxtype` runs as a systemd user service.
- The active engine is `whisper` via the nixpkgs `voxtype-vulkan` build, using
  the declaratively fetched `large-v3-turbo` model.
- Whisper is pinned to Vulkan GPU index `0`, which `vulkaninfo --summary`
  reports as the RX 6900 XT on MS-7E51. The integrated Granite Ridge GPU is
  index `1`.
- Parakeet TDT v3 int8 is wired into the local Home Manager module as an
  alternate model path, but nixpkgs only packages the CPU ONNX VoxType build.
  Use it for an English dictation comparison, or package VoxType's upstream
  ONNX GPU variant for ROCm if Parakeet should satisfy the GPU requirement on
  this AMD host.
- Super+V toggles recording in GNOME.
- `~/.config/niri/voxtype.kdl` contains the niri binds; include it from the real niri config when niri becomes the active compositor config.
- Transcripts type at the focused cursor through `ydotool`. This avoids GNOME
  Wayland's unreliable `wl-copy` + paste-keystroke path.
- Waybar can show recording state through `voxtype status --follow --format json`.
- Raw transcripts are written to `$XDG_RUNTIME_DIR/voxtype/last-transcript`.

### Post-Processing Hook

Create an executable hook at:

```bash
~/.config/voxtype/hooks/post-process
```

The hook receives transcribed text on stdin and must print the text VoxType
should type on stdout. This is the extension point for command routing,
metastack integration, or local text cleanup beyond VoxType's built-in
replacement table.

## Legacy Wyoming Fallback

The older Wyoming Faster Whisper service is still configured on
`tcp://0.0.0.0:10300`, restricted to `tailscale0`.

The `voice-dictate` command remains as a manual fallback:

```
voice-dictate
```

It records from PipeWire, sends audio to the local Wyoming service, and copies
the transcript to the Wayland clipboard. It does not inject into agents.

The removed tmux-era `voice-inject` socket service is no longer part of the
configuration. If Android-over-Tailnet dictation becomes active again, the
missing piece is a real Wyoming protocol bridge or a separate metastack routing
integration.

## Status

- [x] VoxType Vulkan desktop dictation prototype
- [x] Parakeet ONNX alternate model documented
- [x] GNOME Super+V binding
- [x] Waybar status module config
- [x] Post-processing hook wrapper
- [x] Wyoming fallback service retained
- [x] Live microphone/GPU transcription test after rebuild
- [ ] niri config include wired into the real niri config
- [ ] Android/Tailnet dictation bridge, if still desired
