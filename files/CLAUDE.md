# NixOS Constraints for Claude Code

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

## Plugin Issues
Plugin hook scripts often have hardcoded `/bin/bash` shebangs.
Fix script: `~/.claude/scripts/fix-plugins-nixos.sh`
Run after: `/plugin` commands, `/reload-plugins`, or when seeing "/bin/bash: bad interpreter"
