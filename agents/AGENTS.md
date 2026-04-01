# NixOS Global Agent Rules

## Environment
- Running on NixOS (not FHS Linux)
- Shell: fish at `/run/current-system/sw/bin/fish`
- bash at `/run/current-system/sw/bin/bash` (NOT /bin/bash)

## Rules for Commands

### Shebangs
Always use `#!/usr/bin/env bash` or `#!/usr/bin/env sh`
NEVER use `#!/bin/bash` or `#!/bin/sh` - these paths don't exist

### Missing Commands
Many standard commands are not in PATH. Use nix-run syntax:
- `jq` → `nix run nixpkgs#jq --`
- `find` → use Glob/Grep tools instead, or `nix run nixpkgs#findutils --`
- `file` → not available
- `which` → unreliable, prefer `command -v` or check PATH directly

### Preferred Approach
1. Use Claude's built-in tools (Glob, Grep, Read) instead of shell commands
2. For shell scripts that need external tools, use `nix run nixpkgs#tool --`
3. Don't assume any standard Linux paths exist

## Declarative Only
NEVER run imperative installers:
- `npm install -g`, `pip install`, `apt install`, `curl | bash`
- If a tool is missing, add to flake.nix or use `nix shell nixpkgs#tool --`

## Store Protection
`/nix/store` is read-only. All config changes via .nix files, never direct edits.

**Symlinks to nix store:** Many config files (e.g., `~/.claude/CLAUDE.md`) are symlinks into `/nix/store`. Always trace symlinks to find the source file in your nix config before editing.

## Plugin Issues
Plugin hook scripts often have hardcoded `/bin/bash` shebangs.
Fix script: `~/.claude/scripts/fix-plugins-nixos.sh`
Run after: `/plugin` commands, `/reload-plugins`, or when seeing "/bin/bash: bad interpreter"

## Plugin Management
- **Vendor First**: Plugins live in `~/dev/nixos/agents/plugins/`, symlinked via home-manager.
- **Patch for NixOS**: Fix shebangs to use `#!/usr/bin/env nix-shell` with required packages.
- **No Imperative Installs**: Never use `/plugin install`. Manage declaratively.

## Permissionless Safety (--dangerously-skip-permissions)
Claude is started with `--dangerously-skip-permissions` via the `dev` and `ccode` fish functions.

- **Commit-Before-Destructive**: Ensure clean git state before rm/mv/nix-collect-garbage.
- **Three Strikes**: If a command fails 3x, STOP and report. Do not loop.
- **Destructive Warning**: Print "DESTRUCTIVE ACTION" before rm/mv/nix-collect-garbage.

### Fish Functions
- `dev` - Start Claude in ~/dev with tmux (session: dev)
- `ccode` - Start Claude in current directory with tmux (session: project name)

## Rebuilding NixOS
Use `sudo nixos-rebuild switch --flake .` instead of `nh os switch`.

**Why:** Passwordless sudo is configured for `nixos-rebuild`, not `nh`. Using the former allows automated rebuilds without prompting for password.

**Always `git pull` before rebuilding.** Auto-upgrade may have pushed newer flake.lock or config changes to origin.

## Sops Secrets
Secrets use SSH-derived age keys (not standalone age keys). `sops` and `ssh-to-age` are in system PATH.

### Editing secrets
```bash
# Convert SSH key to age identity, then use sops
export SOPS_AGE_KEY=$(ssh-to-age -private-key -i ~/.ssh/id_ed25519) \
  && sops edit secrets/secrets.yaml

# Set a single key without opening editor
export SOPS_AGE_KEY=$(ssh-to-age -private-key -i ~/.ssh/id_ed25519) \
  && sops set secrets/secrets.yaml '["key_name"]' '"value"'
```

### Adding new secrets
1. Add key to `secrets/secrets.yaml` via `sops set` (above)
2. Declare in `modules/nixos/default.nix` under `sops.secrets` with `owner = "andy"`
3. Reference in config via `config.sops.placeholder.<name>` (templates) or `config.sops.secrets.<name>.path` (`/run/secrets/<name>`)

### Rules
- **Never use `yq` to edit secrets.yaml** — it writes plaintext and breaks the sops MAC
- **No standalone age key file** — keys are SSH-derived via `ssh-to-age` at runtime, nothing persists on disk
- Secrets decrypt to `/run/secrets/<name>` at boot via sops-nix using the host SSH key

## Sudo Command Paths
When configuring `security.sudo.extraRules`, use `/run/current-system/sw/bin/<command>` instead of `${pkgs.<package>}/bin/<command>`.

## Hooks: Declarative Only
Claude Code hooks and settings should be managed in NixOS config, not by editing ~/.claude/settings.json directly.

**Why:** settings.json is a symlink to /nix/store (read-only). Changes must go through nix config and rebuild.

**Why:** sudo does NOT follow symlinks when matching command rules. The nix store path won't match when running `sudo <command>` because that resolves to `/run/current-system/sw/bin/<command>` (a symlink).

```nix
# ✓ Correct
command = "/run/current-system/sw/bin/nixos-rebuild";

# ✗ Wrong - symlink not followed, rule won't match
command = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
```
