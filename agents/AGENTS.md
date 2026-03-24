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
- **Commit-Before-Destructive**: Ensure clean git state before rm/mv/nix-collect-garbage.
- **Three Strikes**: If a command fails 3x, STOP and report. Do not loop.
- **Destructive Warning**: Print "DESTRUCTIVE ACTION" before rm/mv/nix-collect-garbage.

## Git Commits
- **No Co-Authored-By**: Do not add "Co-authored-by: Claude ..." to commit messages. Keep commit history clean.

## Sudo Command Paths
When configuring `security.sudo.extraRules`, use `/run/current-system/sw/bin/<command>` instead of `${pkgs.<package>}/bin/<command>`.

**Why:** sudo does NOT follow symlinks when matching command rules. The nix store path won't match when running `sudo <command>` because that resolves to `/run/current-system/sw/bin/<command>` (a symlink).

```nix
# ✓ Correct
command = "/run/current-system/sw/bin/nixos-rebuild";

# ✗ Wrong - symlink not followed, rule won't match
command = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
```
