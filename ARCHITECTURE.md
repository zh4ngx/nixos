# Architecture

This is the high-level orientation for the NixOS/Home Manager configuration in
this repository. Operational agent rules live in `agents/AGENTS.md`; this file
describes the system shape and where responsibilities sit.

## Overview

The repository is a declarative NixOS flake for multiple hosts:

- `MS-7E51`
- `MS-7C95`
- `B550`

The flake owns system configuration, Home Manager configuration, encrypted
secret declarations, local package wrappers, and shared agent documentation.
Hosts import common modules and add only host-specific hardware or identity
configuration.

## Layers

**Flake layer**

- Entry point: `flake.nix`
- Defines flake inputs and `nixosConfigurations`
- Uses a small `mkHost` helper to instantiate each host by hostname
- Passes `self` and `inputs` down through `specialArgs`

**Host layer**

- Location: `hosts/<hostname>/`
- Owns host identity, hardware imports, `hardware-configuration.nix`, timezone,
  swap, and host-only device rules
- Imports the shared NixOS and Home Manager modules

**NixOS module layer**

- Location: `modules/nixos/`
- Owns system-wide services and policies: boot, networking, desktop stack,
  sops-nix, sudo, nix settings, caches, hardware support, manual upgrade
  policy, and system packages
- Hardware-specific shared modules live under `modules/nixos/hardware/`

**Home Manager layer**

- Location: `modules/home-manager/`
- Owns Andy's user environment: packages, dotfiles, fish functions, agent
  launchers, zellij layouts, user services, application modules, and XDG config
- Per-application modules live next to `default.nix`

**Package layer**

- Location: `packages/`
- Owns local derivations that are not consumed directly from nixpkgs or flake
  inputs
- No active local package derivations at the moment

## Rebuild Flow

1. Run `sudo nixos-rebuild switch --flake .` from the repo root.
2. Nix evaluates the host matching `hostname -s`.
3. The host imports shared system and Home Manager modules.
4. sops-nix decrypts declared secrets into `/run/secrets/` and renders secret
   templates into `/run/secrets/rendered/`.
5. Nix builds and activates the new system generation.

Previous generations remain available for rollback. Rollback is an operational
choice, not something this repo should describe as automatic unless a specific
automatic rollback mechanism is configured.

## Secrets And Runtime Config

Secrets are encrypted in `secrets/secrets.yaml` and decrypted at activation or
boot by sops-nix using SSH-derived age keys. Plaintext secrets must not enter
the Nix store.

Common patterns:

- Declare secrets in `modules/nixos/default.nix`.
- Render secret-bearing config with `sops.templates`.
- Point Home Manager symlinks at `/run/secrets/rendered/...` when a tool needs
  a config file.
- Use small wrappers when a tool needs runtime environment injection from
  `/run/secrets/...`.

## Agent Integration

Agent configuration is declarative and user-scoped where possible.

- Shared agent guidance lives in `agents/AGENTS.md`.
- Claude shared resources are symlinked through Home Manager.
- OpenCode and Codex have persistent user services for structured injection.
- MetaStack is consumed through its upstream Home Manager module; this repo owns
  only the local routing configuration. It is retained for legacy/debug
  fallback; normal agent coordination uses CLADE inbox.
- VoxType is configured through the local Home Manager module for desktop STT.

Use `agents/AGENTS.md` for exact dispatch, routing, and canonical-tooling
policy. This architecture document should not duplicate command policy in full.

## Failure Model

Nix evaluation and build errors fail before activation. Runtime service failures
are handled by systemd policies where configured. NixOS host upgrades are
manual: `system.autoUpgrade` and `nixos-upgrade.timer` should stay disabled
unless Andy explicitly changes that policy. The GitHub flake-lock workflow may
still update `flake.lock`, so rebuild commands should pull first before manual
activation.

The practical recovery path is:

- Inspect build or service logs.
- Fix declarative config.
- Rebuild.
- Roll back to a previous generation when the activated system is bad.

## Maintenance Notes

Keep this file durable:

- Prefer directories and option names over exact line numbers.
- Avoid line counts; they go stale quickly.
- Link to operational policy instead of duplicating it.
- Update this file when a new major layer, host, package, or agent integration
  is added.
