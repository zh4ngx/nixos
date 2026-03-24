# NixOS Cluster Architecture

This document describes the architecture and ongoing projects for the NixOS configuration in this repository. It serves as context for both human operators and AI agents working on this system.

## Current Infrastructure

### Hosts

| Hostname | Role | Status | Hardware |
|----------|------|--------|----------|
| MS-7E51 | Main workstation | Active | Daily driver, AMD GPU |
| MS-7C95 | Secondary | Active | - |
| B550 | Secondary | Active | - |
| worker-node | Headless node | Planned | 6-core AM4/AM5, 16GB RAM |

### Network

- **Tailscale**: All nodes connected via Tailnet for secure remote access
- **SSH**: Password auth disabled, key-only. Passwordless sudo for `nixos-rebuild` on specific hosts.

### Secrets Management

- **sops-nix**: Encrypted secrets stored in `secrets/secrets.yaml`
- **Age key**: Derived from SSH key (`~/.ssh/id_ed25519.pub`)
- **Decryption**: Secrets decrypted to `/run/secrets/` at activation time

### Key Decisions

1. **Git email**: Use `zh4ng@noreply.codeberg.org` everywhere (GitHub + Codeberg)
2. **Sudo paths**: Use `/run/current-system/sw/bin/<command>` for sudo rules (symlink issue)
3. **Store protection**: Never edit `/nix/store` directly; trace symlinks to source files

---

## Project: Headless Worker Node

**Goal**: Transform the old AM4/AM5 work machine into a headless Tailscale node for distributed storage, LLM hosting, and agent execution (CLADE).

### Prerequisites

- [x] sops-nix configured
- [ ] Tailscale auth key added to secrets
- [ ] Old machine powered on and accessible on local network

### Phase 1: Connectivity & Modernization

- [ ] Verify SSH access to old machine using local IP
- [ ] Create new host directory: `hosts/worker-node/`
- [ ] Extract `hardware-configuration.nix` from old machine
- [ ] Update flake to include new host

### Phase 2: Core Infrastructure

- [ ] Add Tailscale service to host config
- [ ] Configure sops-nix to inject Tailscale auth key
- [ ] Configure headless operation (no X11/Wayland)
- [ ] Optimize power settings

### Phase 3: Deployment & Verification

- [ ] Deploy via: `nixos-rebuild switch --flake .#worker-node --target-host root@<local-ip>`
- [ ] Verify Tailnet connection
- [ ] Lock SSH to `tailscale0` interface only

### Deployment Command

```bash
# From main machine, deploy to worker node
sudo nixos-rebuild switch --flake .#worker-node --target-host root@<ip>
```

---

## Future: Windows 11 Migration (Project 2)

**Status**: Deferred

The current Windows 11 machine (gaming, music recording, specialized hardware) will eventually migrate to NixOS. Options:

1. **Pure NixOS**: PipeWire + WINE/Proton (hard mode)
2. **VFIO Passthrough**: NixOS host, Windows VM with direct hardware access
3. **Dual Boot**: Separate NVMe drives

---

## Quick Reference

### Adding/Editing Secrets

```bash
cd ~/dev/nixos
nix shell nixpkgs#sops --command sops secrets/secrets.yaml
```

### Rebuilding

```bash
# Local
nh os switch

# Remote
sudo nixos-rebuild switch --flake .#<hostname> --target-host root@<ip>
```

### Age Key

Derived from SSH key: `age1n8tv84p2027x8hrsrhjcgwv2gmvhalzwvn8xuudsjcqtff5g69ss8ny64s`
