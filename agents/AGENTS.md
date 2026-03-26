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

## Rebuilding NixOS
Use `sudo nixos-rebuild switch --flake .` instead of `nh os switch`.

**Why:** Passwordless sudo is configured for `nixos-rebuild`, not `nh`. Using the former allows automated rebuilds without prompting for password.

## Teammate Sessions

**Architecture:**
File-based team coordination using shared task JSON files. Teammates run in separate tmux sessions and poll for assigned work.

```
~/.claude/teams/andy-dev/config.json  # Team member registry
~/.claude/tasks/andy-dev/*.json       # Shared task files
```

**Commands:**
- `teamup` - Start director + all teammates (background sessions)
- `teamdown` - Kill all teammate sessions (director persists)
- `team-restart` - Restart all teammates (pick up skill changes)
- `dev` - Attach to director (creates if not exists)
- `teammate <name>` - Attach to specific teammate (creates if not exists)
- `ccode` - Standalone project session (for manual debugging)

**Quick Start:**
```bash
teamup          # Start everything in background
dev             # Attach to director
# ... work in director ...
Ctrl-a d        # Detach (session keeps running)
```

**Teammates:**
| Name | Working Directory | Purpose |
|------|-------------------|---------|
| nixos | ~/dev/nixos | NixOS system configuration |
| home-manager | ~/dev/home-manager | Home Manager PRs and issues |
| clade-research | ~/dev/clade-research | Research notes and experiments |
| obsidian | ~/dev/obsidian | Knowledge base and notations |

**Director Workflow:**
1. You talk to the director (in `dev` session)
2. Director creates task files in `~/.claude/tasks/andy-dev/`
3. Director sets `owner` field to teammate name
4. Teammates poll every 1 minute, pick up assigned tasks, execute, update status

**Task File Format:**
```json
{
  "id": "1",
  "subject": "Brief task title",
  "description": "Detailed description with context and steps",
  "status": "pending",
  "owner": "home-manager",
  "notes": "Optional: clarifications from human",
  "blockedBy": [],
  "blocks": []
}
```

**Human Interjection:**
- **Attach directly**: `teammate <name>` to type in their session
- **Add notes**: Edit task file's `notes` field with clarifications
- **Block task**: Set `status: "blocked"` to pause execution

**Teammate Behavior:**
On startup, teammates run `/teammate` skill which:
1. Reads team config to confirm membership
2. Sets up `CronCreate` with 1-minute interval to poll task files
3. When task assigned: read file, execute, update status via Edit
4. When idle: wait for next poll

**Restarting After Updates:**
After updating the teammate skill or other configuration:
```bash
team-restart    # Kills and restarts all teammates
```

**Safety:**
- Use `Ctrl-a d` to detach (session keeps running)
- NOT `Ctrl-d` or `exit` (kills the session)

**When to use:**
- `teamup` + `dev` for multi-project work (recommended daily driver)
- `ccode` for isolated, single-project work or debugging a stuck teammate

## Sudo Command Paths
When configuring `security.sudo.extraRules`, use `/run/current-system/sw/bin/<command>` instead of `${pkgs.<package>}/bin/<command>`.

**Why:** sudo does NOT follow symlinks when matching command rules. The nix store path won't match when running `sudo <command>` because that resolves to `/run/current-system/sw/bin/<command>` (a symlink).

```nix
# ✓ Correct
command = "/run/current-system/sw/bin/nixos-rebuild";

# ✗ Wrong - symlink not followed, rule won't match
command = "${pkgs.nixos-rebuild}/bin/nixos-rebuild";
```
