# Open items

Live as of 2026-08-19. Delete entries as they close.

## Reboot pending

Generation 740 is active with **Linux 7.2 configured**, but `/run/booted-system`
is still the previous build and `uname -r` reports 7.1.8. Kernel changes do not
take effect on `switch`. **Reboot to actually run 7.2.** Until then, avoid
hotplugging hardware that needs a module not already loaded; the running
kernel's module tree and `/run/current-system` no longer agree.

## Trap: the next flake update breaks eval

`nix flake update` past nixos-unstable `ec2d622` breaks evaluation with
`error: attribute extraArgs missing`.

Upstream typo in `nixos/modules/services/home-automation/wyoming/faster-whisper.nix`:
`extraArgs` is declared on the server submodule at line 293 and read correctly
as `options.extraArgs` at line 391, but line 332 reads `cfg.extraArgs`, where
`cfg` is `config.services.wyoming.faster-whisper` and has no such attribute.
Eval crashes whenever **any** server is declared.

We declare one: `services.wyoming.faster-whisper.servers.stt` in
`modules/nixos/default.nix:413`.

Our current pin `0ae2bc1` predates the breakage and evaluates clean, which is
why the audit passes today. Found by nixos-ag.

When it bites, the options are: stay on the current pin, comment out
`servers.stt` (nixos-ag confirmed a dry-run builds clean that way, kernel
included), or carry a local overlay fixing line 332 until upstream lands a fix.
Worth checking whether upstream has fixed it before doing either.

## HDMI 2.1: waiting on VRR, deliberately

See `igpu-desktop-migration.md`. Nothing to do now. The trigger is HDMI VRR
merging into amdgpu, at which point FRL becomes default-on, the
`amdgpu.dc_feature_mask=0x400` parameter becomes unnecessary, and moving the
cable from the DP-to-HDMI adapter to the 6900 XT's HDMI port becomes clearly
better rather than a lateral trade.

## Fleet

- **clade-lens digest inaccuracy.** A `nixos-rebuild build` run was summarized
  as `nixos-rebuild switch` succeeding. The raw handle was accurate; the
  distiller inflated the command into a more consequential one. Do not trust a
  digest alone for anything destructive-sounding. Not yet reported to clade-cx.
- **clade-inbox `read` is destructive with no history subcommand.** Reported to
  clade-cx 2026-08-18; unresolved. A read whose output is lost takes the batch
  with it.
- **Closed 2026-08-19:** main-ag revised its reasoning-effort research doc
  (commit a87aaa8) with primary citations, retracted the unsourced ARC
  max-vs-xhigh split, relabelled the turn-expansion figures as an analytical
  model rather than data, and reversed its recommendation to xhigh for Opus 5.
