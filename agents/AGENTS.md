# NixOS Global Agent Rules

## Environment
- Running on NixOS (not FHS Linux)
- Shell: fish at `/run/current-system/sw/bin/fish`
- bash at `/run/current-system/sw/bin/bash` (NOT /bin/bash)

## Rules for Commands

### Shebangs
Always use `#!/usr/bin/env bash` or `#!/usr/bin/env sh`
NEVER use `#!/bin/bash` or `#!/bin/sh` - these paths don't exist

### Package Hallucination Prevention

NixOS does NOT ship with standard FHS command sets. Many commands that exist on other distros are not in PATH.

**CRITICAL RULE: NEVER assume a command exists. Always verify before using.**

1. **Verify first**: Before running any command (non-obvious ones), check with `command -v <cmd>` or `type <cmd>`. If it returns nothing, the command is not installed.
2. **Use nix run**: For packages not in base PATH, use `nix run nixpkgs#<package> -- <args>`
3. **Known to be in PATH**: `git`, `nix`, `sudo`, `command`, `ls`, `cp`, `mv`, `rm`, `cat`, `mkdir`, `chmod`, `curl`, `wget`, `ssh`, `echo`, `date`, `systemctl`, `fish`, `bash`, `sops`, `ssh-to-age`, `rg` (ripgrep), `htop`, `jq`, `metastack`
4. **Capability discovery stack** (use in order):
   - `command -v <cmd>` — runtime PATH check (always first)
   - Read `flake.nix` / `configuration.nix` — declarative intent
   - `mcp-nixos` MCP tool (`action="search"`, `source="nixos"`) — structured package discovery (primary, not fallback)
5. **Flag unknown**: Do NOT attempt to run commands blindly. If not found via discovery stack, confirm with user.

### Missing Commands (Common Examples)
Many standard commands are not in PATH. Use nix-run syntax:
- `find` → use Glob/Grep tools instead, or `nix run nixpkgs#findutils --`
- `file` → not available
- `which` → unreliable, prefer `command -v` or check PATH directly
- `yq`, `fd`, `tree`, `ncdu` → all need `nix run nixpkgs#<pkg> --`

### Preferred Approach
1. Use Claude's built-in tools (Glob, Grep, Read) instead of shell commands
2. For shell scripts that need external tools, use `nix run nixpkgs#tool --`
3. Don't assume any standard Linux paths exist

## Declarative Only
NEVER run imperative installers:
- `npm install -g`, `pip install`, `apt install`, `curl | bash`
- If a tool is missing, add to flake.nix or use `nix shell nixpkgs#tool --`

## Home Manager Best Practices
- **Prefer `programs.*` modules** over raw `home.packages` when a HM module exists (e.g. `programs.opencode`, `programs.tmux`, `programs.fish`)
- **Wrap binaries** with `writeShellScriptBin` when you need runtime env var injection (e.g. secrets from `/run/secrets/`)
- **Env var scoping — narrowest scope first.** When a var affects one tool, prefer in this order:
  1. **Tool's own `env` block** in its config file (e.g. Claude Code `~/.claude-*/settings.json` `env`, opencode provider `options`, `programs.<tool>.settings.env`) — narrowest, never leaks
  2. **Per-binary wrapper** via `writeShellScriptBin` setting the env before `exec` — also right pattern for runtime secrets injection
  3. **systemd service `Environment=`** — per-service scope when the var only matters for one daemon
  4. **`programs.fish.functions`** function setting `set -x VAR …` before launching — fish-only, per-invocation
  5. **`home.sessionVariables`** — **last resort**, exports to *every* user process. Only legitimate for truly user-global vars (`EDITOR`, `BROWSER`)
  
  Don't reach for `home.sessionVariables` because it's easy — narrow scope means less surprise downstream. Concrete example: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` belongs in the sops template that renders `~/.claude-*/settings.json`'s `env` block (option 1), not in `home.sessionVariables` (option 5).
- **Never manipulate files at runtime in wrappers** (`ln -sf`, `cp`, `cat >`) — use sops templates, `home.file`, or CLI flags instead
- **Never use activation scripts to replace HM-managed symlinks with writable copies.** If a program needs to write to its config, preconfigure all required fields in the HM settings module so it never needs to write. If a setting truly can't be preconfigured declaratively, document that limitation rather than working around it with activation scripts.

## Store Protection
`/nix/store` is read-only. All config changes via .nix files, never direct edits.

**Symlinks to nix store:** Many config files (e.g., `~/.claude-shared/CLAUDE.md`, `~/.claude-opus/settings.json`) are symlinks into `/nix/store`. Always trace symlinks (`readlink -f <path>`) to find the source file in your nix config before editing.

## Plugin Issues
Plugin hook scripts often have hardcoded `/bin/bash` shebangs.
Fix script: `~/.claude/scripts/fix-plugins-nixos.sh`
Run after: `/plugin` commands, `/reload-plugins`, or when seeing "/bin/bash: bad interpreter"

## Plugin Management
- **Vendor First**: Plugins live in `~/nixos/agents/plugins/`, symlinked via home-manager.
- **Patch for NixOS**: Fix shebangs to use `#!/usr/bin/env nix-shell` with required packages.
- **No Imperative Installs**: Never use `/plugin install`. Manage declaratively.

## Permissionless Safety (--dangerously-skip-permissions)
All AI CLI launchers (`co`, `coh`, `cg`, `gc`, `oc`, `qc`, `cx`) run inside zellij
with auto-approve flags (`--dangerously-skip-permissions` / `--yolo`).

- **Commit-Before-Destructive**: Ensure clean git state before rm/mv/nix-collect-garbage.
- **Three Strikes**: If a command fails 3x, STOP and report. Do not loop.
- **Destructive Warning**: Print "DESTRUCTIVE ACTION" before rm/mv/nix-collect-garbage.

### Fish Functions
- `co` - Claude Opus, per-project (session: `{dir}-co`)
- `coh` - Claude Opus with Huddle channel bridge, per-project (session: `{dir}-coh`)
- `cg` - Claude GLM, per-project (session: `{dir}-cg`)
- `oc` - OpenCode attached to the persistent local `opencode-serve` API server (session: `{dir}-oc`)
- `qc` - Qwen Code 3.6 Plus (session: `{dir}-qc`)
- `gc` - Gemini CLI (session: `{dir}-gc`)
- `cx` - Codex CLI attached to the persistent local `codex-app-server` (GPT-5.5 xhigh, session: `{dir}-cx`)
- `agents` - list zellij-backed agent sessions

There is no special `main` launcher. Main-loop identity is operational:
`cwd + harness`. Examples: `cd ~; oc` → `andy-oc`, `cd ~; cx` →
`andy-cx`, `cd ~/nixos; co` → `nixos-co`. Run agents from the project root
they own instead of adding unrelated roots to scope.

## Tooling Discipline

Prefer canonical paths over ad hoc invocations. When the team owns an
abstraction (`metastack send`, `vault-cx` for vault writes, Huddle MCP tools),
default to that path. Reach for the lower-level primitive only when the
abstraction is broken, missing a feature, or you are explicitly debugging the
abstraction itself; document the exception when you do.

Examples:
- Use `metastack send <target> "<message>"` for routed agent communication
  rather than raw backend APIs or zellij keystrokes.
- Dispatch vault writes to `vault-cx` instead of editing `~/vault` directly
  from the NixOS or MetaStack project agent.
- Use Huddle MCP/channel tools for Claude channel messaging instead of
  keystroke injection when the session is channel-enabled.

## Anti-slop writing style (for human-facing drafts)

When drafting text Andy may paste or send to a human reader, remove obvious AI writing tells. This applies to support chats, emails, PR descriptions, issue comments, public posts, dispute notes, and external-facing docs. It does not apply to internal CLI conversation, scratch planning, quoted source text, generated code, or technical formats where bullets, headings, or tables are genuinely the clearest form.

Write in Andy's voice: direct, specific, low-drama, and not promotional. Prefer plain prose over template-like structure.

1. Do not use em-dashes. Use a period, comma, colon, semicolon, or parentheses.
2. Cut chatbot leakage: "I'd be happy to," "Great question," "Of course," "Certainly," "I hope this helps," and "Let me know."
3. Avoid throat-clearing: "Clearly," "Simply," "In fact," "It turns out," "This matters because," "Make no mistake," and "The key is."
4. Avoid AI vocabulary clusters: delve, landscape, pivotal, showcase, underscore, robust, seamless, nuanced, transformative, comprehensive, tapestry, testament, synergy.
5. Avoid perfect parallel structure. Do not make every sentence or paragraph follow the same rhythm.
6. Avoid the automatic three-item list. Use one or two items when that is enough.
7. Do not overuse bullets, tables, or Title Case headings in short human-facing replies. Use normal paragraphs unless structure actually helps.
8. Avoid promotional summary language. Say what happened, what is needed, and what evidence supports it.
9. Preserve useful specificity: dates, costs, model names, links, invoice numbers, error messages, and concrete asks.
10. Before finalizing external text, scan once for AI tells and rewrite anything that sounds like a generic assistant.

## Project Boundaries (Dispatch)

This rule is **agent-agnostic** — applies to Claude Code, OpenCode, Codex, Qwen
Code, Gemini CLI, or any other AI agent operating across this user's project
roots. Examples below use Claude CLI flags as one concrete instance; substitute
the equivalent headless mode for other agents.

When dispatching Codex / GPT-5.5 agents, always request `xhigh` reasoning
effort. Do not rely on inherited defaults for Codex dispatches.

**Project-scoped work uses project-scoped agents.** When work in one root
(e.g. `~/nixos`) would spill into another (`~/vault`, `~/dev/<repo>`),
dispatch to a separate headless agent for that project rather than reaching
across roots.

### The work being dispatched

Spawn a fresh agent instance scoped to the target project, run a single bounded
task, capture output to a known location. Claude example:

```fish
cd ~/<repo> && stdbuf -oL -eL claude-opus -p "..." \
  --dangerously-skip-permissions --add-dir ~/<repo> \
  --output-format=stream-json --verbose --include-partial-messages \
  > /tmp/<task>.jsonl 2>&1
```

For other agents, use their headless / non-interactive mode (consult agent docs
for exact flags). The principle is constant.

For OpenCode-specific launch substrates (headless push-back, zellij pane
dispatch, and metastack), use the canonical vault note:
`~/vault/02-areas/agents/dispatch-strategy.md` §"Dispatch Substrate".

MetaStack structured send is available as a declarative user package. Use the
HM-managed routing file instead of ad hoc `/tmp` route YAML. The default
routing path is `~/.config/metastack/routing.yaml`, so this is normally enough:

```bash
metastack send <target> "<message>"
```

Current local targets include `andy-oc`, `andy-cx`, `nixos-cx`,
`metastack-cx`, `vault-cx`, and `sutro-cx`.

For parent/upstream communication, prefer `metastack send <parent-target>
"<message>"` when the HM-managed routing config has that target. On this host,
the parent OpenCode target is `andy-oc`, so upstream reports should use:

```bash
metastack send andy-oc "<message>"
```

Use raw backend APIs (OpenCode `prompt_async`, Codex app-server JSON-RPC, etc.)
only as an explicitly documented fallback or debug path. Do not use zellij
keystroke messaging for parent/upstream communication unless no structured
route exists.

MetaStack flake governance: NixOS consumes semver tags when available, or an
explicit reviewed rev. Do not track floating `main`; branch promotion and tag
cutting happen in the MetaStack project before NixOS updates its input.

OpenCode interactive project agents should be launched through `oc`, not raw
`opencode`, when future programmatic injection matters. `oc` attaches the TUI
to the user service `opencode-serve` on `127.0.0.1:4096`; external
orchestrators can then use the OpenCode HTTP API for serve-backed sessions.
Already-running raw OpenCode TUIs remain keystroke-only.

Claude Code channels are the right structured injection path in principle, but
they are opt-in via `coh`, not the default `co` launcher. `coh` launches Claude
with `--dangerously-load-development-channels server:huddle`, uses the
HM-managed global `~/.mcp.json` Huddle server, and tries `--continue` before
falling back to a fresh session. `DISABLE_TELEMETRY=1` prevents Claude Code
feature-flag evaluation and caused `Channels are not currently available` on
Opus; keep that variable out of the Opus settings when testing channels. Claude
TUIs that were not launched with channel flags remain keystroke-only.

Codex interactive project agents should be launched through `cx`, not raw
`codex`, when future programmatic injection matters. `cx` starts the user
service `codex-app-server` on `127.0.0.1:4107`, then attaches the TUI with
`--remote ws://127.0.0.1:4107`. External orchestrators can use the Codex
app-server JSON-RPC protocol (`thread/start`, `thread/resume`, `turn/start`,
etc.) against that service. Raw Codex TUIs that were not launched with
`--remote` remain keystroke-only. Exact Codex JSON-RPC request shapes are in
`~/nixos/agents/codex-app-server-messaging.md`; use that guide instead of
guessing from OpenCode payloads.

**Trace continuity** lives in the agent's project-slug directory (Claude:
`~/.claude-opus/projects/-home-andy-<repo>/`; other agents have their own
schemes). Project-scoped traces enable agent `--continue` semantics and keep
project-specific knowledge out of the parent session's global context.

### How the parent agent launches it — two patterns

**Default: parent-agent's backgrounded-shell facility.** For Claude Code, that
is `Bash(run_in_background: true)`; equivalents exist in OpenCode, Codex, etc.
The parent tracks the subprocess in its UI (statusline shows it), output is
pollable via the parent's shell-output facility. Lifecycle is tied to the
parent agent — acceptable in this user's setup because the parent always runs
inside tmux/zellij, which preserves the parent across SSH disconnect, terminal
close, machine sleep.

**Edge case: shell-detach `(cmd &)`.** Use only when the dispatch must outlive
a deliberate parent-agent `/exit`, span machine reboot, or be true
fire-and-forget walk-away. Trade-off: invisible to parent UI, no convenient
poll handle. Wrap as `(cd ~/<repo> && ... > /tmp/<task>.jsonl 2>&1) &` so the
process is orphaned to init and the cd stays local.

### Concurrency

**Essentially uncapped** on this host (32GB RAM + 15GB zram + 32GB disk swap on
MS-7E51). Don't pre-throttle headless dispatches. If RAM pressure surfaces
(OOM, swap thrashing), back off then.

### Anti-patterns

**In-process sub-agent for project work.** The parent agent's in-process
sub-agent tool (e.g. Claude Code's `Agent` tool with `general-purpose` subagent
type) keeps the trace in the parent's project slug, not the target project's
slug. Use only for cross-project research / synthesis where the trace
genuinely belongs in the parent.

**Interactive attach by default.** Don't default to spawning interactive
`co`/`cg`/`oc`/`gc`/`qc` instances. Reserve for tasks that genuinely need
real-time human steering — and ask the user first.

**`cd` in parent-agent shell tool calls without a subshell.** Use
`git -C <path>`, `cmd -C <path>`, `--flake <path>`, or `(cd /path && cmd)`.
If the parent's CWD drifts mid-session, project slug and tool resolution break.

### Canonical version

The full canonical version of this rule (with vault cross-links and
session-history rationale) lives in
`~/vault/02-areas/agents/user-preferences.md` §"Project-scoped dispatch (default pattern)".

## Zellij Orchestration

When driving zellij programmatically (spawning panes, sending input, reading
screen state), follow the canonical policy in
`~/vault/02-areas/agents/zellij-orchestration.md` — covers
`$ZELLIJ_PANE_ID` for current-pane identification, `new-pane` stdout capture,
`write-chars` + `write 13` for CR submit, `dump-screen` for reading pane
content, no `nohup` (zellij sessions already provide persistence), and
`run_in_background` as the default dispatch pattern over orphaned detach.

## Rebuilding NixOS
Use `sudo nixos-rebuild switch --flake .` instead of `nh os switch`.

**Why:** Passwordless sudo is configured for `nixos-rebuild`, not `nh`. Using the former allows automated rebuilds without prompting for password.

**Always `git pull` before rebuilding.** Auto-upgrade may have pushed newer flake.lock or config changes to origin.

**Don't specify `.#<hostname>` unless cross-host deploying.** Plain `.` auto-matches by `hostname -s` and fails safely on mismatch. Manually typing the hostname risks silently activating the wrong machine's config (recoverable via rollback to previous generation, but disruptive).

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

## Git Branch Naming
Never use `feat/`, `fix/`, or `chore/` branch prefixes — they're meaningless noise in small-team and personal projects. `docs/` is acceptable when the branch is genuinely docs-only.

Use short descriptive names:
- `vscode-agda` not `feat/vscode-agda`
- `gemini-oauth` not `fix/auth-method`
- `flake-lock-update` not `chore/deps`
- `docs/api-reference` — ok, this one actually means something

If a project has its own CONTRIBUTING.md or branch convention, follow that instead. This rule is the default override.

## Agent Commit Attribution
For GPT-5.5 agent work in git commits, use:

```text
Co-Authored-By: GPT-5.5 <noreply@openai.com>
```

Do not use `Signed-off-by` for agent attribution. DCO `Signed-off-by` is for
legal/process attestation; `Co-Authored-By` records authorship attribution.

When work is done by multiple agents, each agent gets its own
`Co-Authored-By` line.

## Branch Cleanup After Merge

After any merge to main, delete both local and remote feature branch:

- **If merged via `gh pr merge`**: pass `--delete-branch` to auto-clean the remote, then `git branch -d <name>` locally.
- **If merged locally (fast-forward)**: `git branch -d <name>` + `git push origin --delete <name>`.
- **After cleanup**: run `clear-pr-notification <N>` to dismiss the GitHub notification thread.

Skip for long-lived branches: main, release/*, hotfix/*, gh-pages.

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

## Uncertainty on Research-Heavy Questions

On math proofs, formal verification, or research questions where fabricating a plausible-but-wrong answer is worse than admitting ignorance:

- Flag uncertainty explicitly ("I'm not confident about this step") rather than hedging.
- Don't fabricate. An honest "I don't know" beats a confident wrong proof step.
- When appropriate, recommend the user verify with a reasoning-specialized model. Don't name a specific one durably — SOTA shifts.
- This rule applies to research content, not routine code or config work.
