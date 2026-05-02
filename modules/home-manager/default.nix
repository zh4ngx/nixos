{
  pkgs,
  self,
  inputs,
  ...
}:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit self inputs; };
    users.andy =
      { config, lib, ... }:
      {
        imports = [
          inputs.nix-index-database.homeModules.nix-index
          ./obsidian.nix
          ./opencode.nix
          ./gemini.nix
          ./codex.nix
          ./voxtype.nix
        ];

        home.stateVersion = "26.05"; # Please read the comment before changing.

        home.sessionVariables = {
          EDITOR = "zeditor --wait";
        };

        xdg.enable = true;

        # All XDG user dirs → ~/inbox (single triage zone). See vault/01-projects/xdg-inbox-refactor.md.
        xdg.userDirs = {
          enable = true;
          createDirectories = true;
          download = "$HOME/inbox";
          documents = "$HOME/inbox";
          pictures = "$HOME/inbox";
          videos = "$HOME/inbox";
          music = "$HOME/inbox";
          desktop = "$HOME/inbox";
          templates = "$HOME/inbox";
          publicShare = "$HOME/inbox";
          projects = "$HOME/dev";
        };

        # The home.packages option allows you to install Nix packages into your
        # environment.
        home.packages = with pkgs; [
          # # Adds the 'hello' command to your environment. It prints a friendly
          # # "Hello, world!" when run.
          # pkgs.hello

          # # It is sometimes useful to fine-tune packages, for example, by applying
          # # overrides. You can do that directly here, just don't forget the
          # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
          # # fonts?
          # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

          # # You can also create simple shell scripts directly inside your
          # # configuration. For example, this adds a command 'my-hello' to your
          # # environment:
          # (pkgs.writeShellScriptBin "my-hello" ''
          #   echo "Hello, ${config.home.username}!"
          # '')
          inputs.antigravity-nix.packages.x86_64-linux.google-antigravity-no-fhs
          inputs.claude-code.packages.x86_64-linux.claude-code
          inputs.metastack.packages.${pkgs.stdenv.hostPlatform.system}.default
          (pkgs.callPackage ../../packages/huddle { })
          beeper
          tea # Codeberg CLI
          gnomeExtensions.appindicator
          gnomeExtensions.hide-top-bar
          gnomeExtensions.just-perfection
          gnomeExtensions.vitals
          qbittorrent
          radeontop
          ugs
          mcp-nixos
          wl-clipboard

          # Legacy voice dictation fallback: capture mic via PipeWire,
          # transcribe via local Wyoming server, and copy transcript to the
          # Wayland clipboard. Desktop hotkeys use VoxType now; this script is
          # kept as a manual diagnostic/fallback path.
          (pkgs.writeShellScriptBin "voice-dictate" ''
            #!/usr/bin/env bash
            set -euo pipefail
            WAV=/tmp/voice-dictate.wav
            trap 'echo' INT
            echo "🎙  Recording — speak, then Ctrl+C to stop and transcribe..." >&2
            ${pkgs.pipewire}/bin/pw-record --rate 16000 --channels 1 --format s16 "$WAV" || true
            trap - INT
            if [ ! -s "$WAV" ]; then
                echo "✗ No audio captured (file empty)." >&2
                exit 1
            fi
            echo "📝 Transcribing..." >&2
            TRANSCRIPT=$(${pkgs.python3.withPackages (p: [ p.wyoming ])}/bin/python3 - "$WAV" <<'PYEOF'
            import asyncio
            import sys
            import wave

            from wyoming.asr import Transcribe, Transcript
            from wyoming.audio import AudioChunk, AudioStart, AudioStop
            from wyoming.event import async_read_event, async_write_event


            async def main(wav_path: str) -> str:
                reader, writer = await asyncio.open_connection("127.0.0.1", 10300)
                await async_write_event(Transcribe(language="en").event(), writer)
                await async_write_event(
                    AudioStart(rate=16000, width=2, channels=1).event(), writer
                )
                with wave.open(wav_path, "rb") as wf:
                    while True:
                        chunk = wf.readframes(4096)
                        if not chunk:
                            break
                        await async_write_event(
                            AudioChunk(audio=chunk, rate=16000, width=2, channels=1).event(),
                            writer,
                        )
                await async_write_event(AudioStop().event(), writer)

                text = ""
                while True:
                    ev = await async_read_event(reader)
                    if ev is None:
                        break
                    if Transcript.is_type(ev.type):
                        text = Transcript.from_event(ev).text
                        break
                writer.close()
                await writer.wait_closed()
                return text


            print(asyncio.run(main(sys.argv[1])), end="")
            PYEOF
            )
            if [ -z "$TRANSCRIPT" ]; then
                echo "✗ Empty transcript (Wyoming returned no text)." >&2
                exit 1
            fi
            printf '%s' "$TRANSCRIPT" | ${pkgs.wl-clipboard}/bin/wl-copy
            echo "✓ Copied to clipboard:" >&2
            echo "  $TRANSCRIPT" >&2
            echo
            echo "  Paste with Ctrl+Shift+V (terminal) or Ctrl+V (most apps)." >&2
          '')
          # High-frequency agent / shell tools — keeping in PATH avoids the
          # ~200-500ms `nix run nixpkgs#<x> --` eval cost per invocation
          # (statusline.sh calls jq on every render) AND protects them from
          # `nh clean` GC eviction. Convention for AGENTS: prefer Read/Glob
          # harness tools for simple inspection; reach for these shell tools
          # when a pipeline is genuinely the right shape
          # (see vault [[dispatch-strategy#Tool Selection Priority for Agents]]).
          jq
          fd
          tree
          yq
          (pkgs.writeShellScriptBin "qwencode" ''
            #!/usr/bin/env bash
            export OPENAI_API_KEY=$(cat /run/secrets/openrouter_api_key)
            export OPENAI_BASE_URL=https://openrouter.ai/api/v1
            # We override qwen-code to permanently bump its unknown model fallback limit from 131k to 1M
            exec ${pkgs.qwen-code.overrideAttrs (old: {
              postInstall = (old.postInstall or "") + ''
                sed -i 's/DEFAULT_TOKEN_LIMIT = 131072/DEFAULT_TOKEN_LIMIT = 1000000/g' $out/share/qwen-code/cli.js
              '';
            })}/bin/qwen --auth-type openai -m qwen3.6-max-preview "$@"
          '')
          (pkgs.writeShellScriptBin "claude-opus" ''
            export CLAUDE_CONFIG_DIR="$HOME/.claude-opus"
            exec claude --mcp-config /run/secrets/rendered/claude-mcp.json "$@"
          '')
          (pkgs.writeShellScriptBin "claude-opus-huddle-current" ''
            #!/usr/bin/env bash
            set -euo pipefail

            exec claude-opus --dangerously-load-development-channels server:huddle \
              --dangerously-skip-permissions "$@"
          '')
          (pkgs.writeShellScriptBin "claude-glm" ''
            export CLAUDE_CONFIG_DIR="$HOME/.claude-glm"
            exec claude --mcp-config /run/secrets/rendered/claude-mcp.json "$@"
          '')
          (pkgs.writeShellScriptBin "opencode-attach-current" ''
            #!/usr/bin/env bash
            set -euo pipefail

            ${pkgs.systemd}/bin/systemctl --user start opencode-serve.service
            exec opencode attach http://127.0.0.1:4096 --dir "$PWD" -c "$@"
          '')
          (pkgs.writeShellScriptBin "codex-continue-current" ''
            #!/usr/bin/env bash
            set -euo pipefail

            ${pkgs.systemd}/bin/systemctl --user start codex-app-server.service
            export CODEX_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}/codex"

            args=(
              --remote ws://127.0.0.1:4107
              --no-alt-screen
              -C "$PWD"
              -c 'model="gpt-5.5"'
              -c 'model_reasoning_effort="xhigh"'
              -c "projects.$PWD.trust_level=\"trusted\""
            )

            codex resume --last "''${args[@]}" || exec codex "''${args[@]}"
          '')
        ];

        # Hindsight embed daemon — perpetually-running service so claude-opus
        # SessionStart hooks find it already up (zero cold-start latency) and
        # so the OpenRouter API key lives in EnvironmentFile= rather than the
        # claude-opus settings.json env block (where it'd leak into every
        # subprocess Claude Code spawns).
        # Type=forking: `daemon start` Popens hindsight-api with --daemon, polls
        # health, then exits — systemd's cgroup heuristic picks up the surviving
        # api process as the main PID, so Restart=on-failure supervises it.
        systemd.user.services.hindsight-embed = {
          Unit = {
            Description = "Hindsight embed daemon (claude-code profile, 127.0.0.1:9077)";
          };
          Service = {
            Type = "forking";
            EnvironmentFile = "/run/secrets/rendered/hindsight-embed.env";
            ExecStart = "/run/current-system/sw/bin/uvx hindsight-embed@latest daemon --profile claude-code start";
            ExecStop = "/run/current-system/sw/bin/uvx hindsight-embed@latest daemon --profile claude-code stop";
            Restart = "on-failure";
            RestartSec = 10;
            StartLimitBurst = 5;
            TimeoutStartSec = 60;
          };
          Install.WantedBy = [ "default.target" ];
        };

        # Let Home Manager install and manage itself.
        programs.home-manager.enable = true;

        # Shared MCP servers (injected into tools via enableMcpIntegration)
        programs.mcp = {
          enable = true;
          servers.nixos = {
            command = "mcp-nixos";
          };
          servers.zellij = {
            command = "/home/andy/dev/zellij-mcp/target/release/zellij-mcp";
          };
        };

        # Use nix-index and comma
        programs.nix-index = {
          enable = true;
          enableFishIntegration = true;
        };
        programs.nix-index-database.comma.enable = true;

        # Ensure HM doesn't try to manage a legacy profile link
        home.preferXdgDirectories = true;

        xdg = {
          mimeApps = {
            enable = true;
            defaultApplications = {
              "text/html" = "firefox.desktop";
              "x-scheme-handler/http" = "firefox.desktop";
              "x-scheme-handler/https" = "firefox.desktop";
              "x-scheme-handler/about" = "firefox.desktop";
              "x-scheme-handler/unknown" = "firefox.desktop";
              "video/mp4" = "mpv.desktop";
              "video/x-matroska" = "mpv.desktop";
              "video/webm" = "mpv.desktop";
              "video/quicktime" = "mpv.desktop";
            };
          };
          configFile = {
            "mimeapps.list".force = true;
            "uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
            "autostart/io.ente.auth.desktop".source =
              "${pkgs.ente-auth}/share/applications/io.ente.auth.desktop";
          };
        };

        # --- Wayland desktop tools (useful with any compositor) ---
        programs.waybar = {
          enable = true;
          settings = {
            main-bar = {
              layer = "top";
              position = "top";
              "cpu" = {
                format = "CPU: {usage}%";
              };
              "memory" = {
                format = "MEM: {used}/{total}G ({percentage}%)";
              };
              "clock" = {
                format = "{:%a, %b %d %H:%M}";
              };
              "tray" = { };
            };
          };
        };
        programs.rofi.enable = true;
        services.walker.enable = true;
        services.mako.enable = true;

        programs.direnv = {
          enable = true;
          nix-direnv.enable = true;
          # Note: use this with caution - always audit flake.nix shellHook!
          stdlib = ''
            if [ -f flake.nix ] && [ ! -f .envrc ]; then
              use flake
            fi
          '';
        };

        programs.bat.enable = true;
        programs.ripgrep = {
          enable = true;
          arguments = [
            "--max-columns=150"
            "--max-columns-preview"
            "--colors=line:style:bold"
            "--smart-case"
          ];
        };
        programs.rio = {
          enable = true;
          settings = {
            window = {
              width = 1280;
              height = 720;
              opacity = 0.6;
              blur = true;
            };
            shell = {
              program = "${pkgs.fish}/bin/fish";
              args = [ "--interactive" ];
            };
            renderer = {
              performance = "High";
              backend = "Vulkan";
            };
          };
        };

        programs.fish = {
          enable = true;
          functions = {
            plugin = ''
              command plugin $argv
              and ~/.claude-shared/scripts/fix-plugins-nixos.sh
            '';
            # claude: bare default instance retired 2026-04-25 (was pre-split GLM-routed; history preserved in ~/.claude-glm/).
            claude = "echo '⚠ bare claude retired — use co (Opus) or cg (GLM)' >&2; return 1";
            # __zj: internal helper. Idempotent create-or-attach to a named zellij
            # session running a layout. $argv[1]=session name, $argv[2]=layout name.
            # `zellij attach --create` attaches if the session exists, or creates
            # fresh with $layout otherwise. Layout names resolve from
            # ~/.config/zellij/layouts/<name>.kdl (materialized by
            # `programs.zellij.layouts.<name>` below). The launch cwd is
            # inherited from $PWD; layouts don't pin cwd themselves.
            #
            # Pre-cleanup: zellij 0.44.x marks ended sessions as
            # "(EXITED - attach to resurrect)". Resurrecting a fully-exited
            # session leaves you in an empty pane (zellij spawns a default fish
            # at $HOME), defeating the layout. Detect EXITED and force-delete
            # first so `attach --create` recreates with the layout cleanly.
            __zj = ''
              set -l name $argv[1]
              set -l layout $argv[2]
              if zellij list-sessions -n 2>/dev/null | grep -E "^$name " | grep -q "EXITED"
                  zellij delete-session $name --force 2>/dev/null
              end
              zellij attach --create $name options --default-layout $layout
            '';
            # co: Claude Code with Anthropic Opus (Pro plan)
            co = "__zj (basename $PWD | string replace -a . _)-co co";
            # coh: Claude Code Opus with Huddle channel bridge enabled
            coh = "__zj (basename $PWD | string replace -a . _)-coh coh";
            # cg: Claude Code with Z.AI GLM
            cg = "__zj (basename $PWD | string replace -a . _)-cg cg";
            # oc: start opencode attached to the persistent OpenCode server
            oc = "__zj (basename $PWD | string replace -a . _)-oc oc";
            # qc: start qwen-code (Paid 3.6 Plus CLI)
            qc = "__zj (basename $PWD | string replace -a . _)-qc qc";
            # gc: start gemini-cli
            gc = "__zj (basename $PWD | string replace -a . _)-gc gc";
            # cx: start OpenAI Codex CLI (auth via `codex login` against ChatGPT Pro)
            cx = "__zj (basename $PWD | string replace -a . _)-cx cx";
            # agents: list zellij-backed agent sessions
            agents = "zellij list-sessions -n";
            # Title hook - sets window name for tmux/zellij to pass through
            fish_title = ''
              if set -q TMUX
                or set -q ZELLIJ
                echo (status current-command)
              else
                echo (basename $PWD)
              end
            '';
            clear-pr-notification = ''
              set pr_num $argv[1]
              if test -z "$pr_num"
                echo "Usage: clear-pr-notification <pr-number>"
                return 1
              end
              set id (gh api "notifications?all=true&participating=true" \
                --jq ".[] | select(.subject.url | endswith(\"/pulls/$pr_num\")) | .id")
              if test -z "$id"
                echo "No notification found for PR #$pr_num"
                return 0
              end
              gh api -X DELETE "notifications/threads/$id"
              echo "Cleared notification $id for PR #$pr_num"
            '';
            pr-merge-clean = ''
              set pr_num $argv[1]
              gh pr merge $pr_num --delete-branch && clear-pr-notification $pr_num
            '';
          };
          plugins = [
            {
              name = "bass";
              src = pkgs.fishPlugins.bass.src;
            }
          ];
        };

        # Agent config files - ~/.claude-shared is the canonical shared home
        home.file = {
          # Non-secret global MCP servers. Secret-bearing MCP config stays in
          # /run/secrets/rendered/claude-mcp.json and is passed via wrappers.
          ".mcp.json".text = builtins.toJSON {
            mcpServers.huddle.command = "huddle-mcp";
          };
          ".config/metastack/routing.yaml".text = ''
            version: 2

            backends:
              opencode:
                type: opencode
                base_url: http://127.0.0.1:4096

              codex:
                type: codex
                url: ws://127.0.0.1:4107
                model: gpt-5.5
                effort: xhigh
                approval_policy: never
                sandbox_policy:
                  type: dangerFullAccess

            agents:
              andy-oc:
                backend: opencode
                cwd: /home/andy
                session_id: ses_21f36d7d6ffeKfoebcrQovH0pZ

              andy-cx:
                backend: codex
                cwd: /home/andy

              nixos-cx:
                backend: codex
                cwd: /home/andy/nixos

              metastack-cx:
                backend: codex
                cwd: /home/andy/dev/metastack

              vault-cx:
                backend: codex
                cwd: /home/andy/vault
          '';

          # Canonical shared resources in ~/.claude-shared
          ".claude-shared/CLAUDE.md".source = ./../../agents/AGENTS.md;
          ".claude-shared/scripts/fix-plugins-nixos.sh".source = ./../../files/fix-plugins-nixos.sh;
          ".claude-shared/scripts/statusline.sh".source = ./../../files/statusline.sh;

          # Claude Code GLM - symlinks to shared resources from ~/.claude-shared
          ".claude-glm/settings.json".source =
            config.lib.file.mkOutOfStoreSymlink "/run/secrets/rendered/claude-settings-glm.json";
          ".claude-glm/CLAUDE.md".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude-shared/CLAUDE.md";
          ".claude-glm/scripts".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude-shared/scripts";
          ".claude-glm/plugins".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude-shared/plugins";
          ".claude-glm/skills".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude-shared/skills";
          ".claude-glm/commands".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude-shared/commands";

          # Claude Code Opus - symlinks to shared resources from ~/.claude-shared
          ".claude-opus/settings.json".source =
            config.lib.file.mkOutOfStoreSymlink "/run/secrets/rendered/claude-settings-opus.json";
          ".claude-opus/CLAUDE.md".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude-shared/CLAUDE.md";
          ".claude-opus/scripts".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude-shared/scripts";
          ".claude-opus/plugins".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude-shared/plugins";
          ".claude-opus/skills".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude-shared/skills";
          ".claude-opus/commands".source =
            config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude-shared/commands";

          # Other agent config files
          ".gemini/GEMINI.md".source = ./../../agents/AGENTS.md;
          ".config/opencode/AGENTS.md".source = ./../../agents/AGENTS.md;

          # tea CLI config from sops-nix template
          ".config/tea/config.yml".source =
            config.lib.file.mkOutOfStoreSymlink "/run/secrets/rendered/tea-config.yml";
        };

        programs.mcfly = {
          enable = true;
          enableFishIntegration = true;
          fuzzySearchFactor = 2;
          fzf.enable = true;
        };

        programs.fzf = {
          enable = true;
          enableFishIntegration = true;
        };

        programs.starship = {
          enable = true;
          enableFishIntegration = true;
        };

        programs.eza = {
          enable = true;
          enableFishIntegration = true;
          git = true;
          icons = "auto";
          colors = "auto";
        };

        programs.firefox.enable = true;

        programs.chromium = {
          enable = true;
          package = pkgs.google-chrome;
        };

        programs.emacs = {
          enable = true;
          extraPackages = epkgs: [
            epkgs.nix-mode
            epkgs.magit
          ];
        };

        programs.git = {
          enable = true;
          signing = {
            format = "ssh";
            signByDefault = true;
            key = "~/.ssh/id_ed25519.pub";
          };
          settings = {
            user = {
              name = "Andy Zhang";
              email = "zh4ng@noreply.codeberg.org";
            };
            color = {
              ui = "auto";
            };
            fetch = {
              prune = true;
            };
            push = {
              default = "simple";
              autoSetupRemote = true;
            };
            pull = {
              rebase = true;
            };
            branch = {
              autosetuprebase = "always";
            };
            init = {
              defaultBranch = "main";
            };
            aliases = {
              sync = "!git fetch upstream 2>/dev/null && git checkout main && git rebase upstream/main && git push origin main --force-with-lease && echo '✓ synced with upstream'";
              pb = "push -u origin HEAD";
            };
          };
          ignores = [
            ".envrc"
            ".direnv/"
            ".envrc.local"
          ];
        };

        # Try out htop, bottom, and btop
        programs.htop.enable = true;
        programs.bottom.enable = true;
        programs.btop.enable = true;

        programs.tmux = {
          enable = true;
          mouse = true;
          terminal = "tmux-256color";
          keyMode = "vi";
          historyLimit = 50000; # Keep 50,000 lines of history
          shortcut = "a"; # Ctrl-a instead of Ctrl-b (easier on mobile)
          extraConfig = ''
            # Split panes with | and - (more intuitive)
            bind | split-window -h
            bind - split-window -v

            # Reload config
            bind r source-file ~/.config/tmux/tmux.conf \; display "Reloaded!"

            # Pass title to terminal (Rio/Termux)
            set-option -g set-titles on
            set-option -g set-titles-string "🤖 #S - #W"

            # Pass through extended keys for better terminal compatibility
            set -s extended-keys on
            set -g xterm-keys on

            # Enable focus events for auto-reloading and UI pausing in TUIs
            set-option -g focus-events on
            # Enable true color natively for the Rio terminal
            set -as terminal-features ',rio:RGB:focus'

            # Open qwen-code in a new window (Paid 3.6 Plus)
            bind q new-window "fish -c 'qwencode'"
          '';
        };

        # Zellij is the canonical multiplexer for AI launchers (migrated from
        # tmux 2026-04-29). Fish shortcuts for co/coh/cg/oc/qc/gc/cx attach to
        # or spawn a zellij session that loads the corresponding layout below.
        # Layouts are materialized under
        # ~/.config/zellij/layouts/<name>.kdl by home-manager and referenced
        # by name from `__zj` via `zellij --session $name --layout $name`.
        # Each pane runs `fish -c '<cmd>'` with `close_on_exit=true` so the
        # session terminates cleanly when the agent CLI exits.
        programs.zellij = {
          enable = true;
          settings = {
            theme = "nord";
            show_release_notes = false;
            show_startup_tips = false;
            support_kitty_keyboard_protocol = false;
          };
          layouts =
            let
              agentLayout = command: ''
                layout {
                    pane size=1 borderless=true {
                        plugin location="tab-bar"
                    }
                    pane command="fish" close_on_exit=true {
                        args "-c" "${command}"
                    }
                    pane size=1 borderless=true {
                        plugin location="status-bar"
                    }
                }
              '';
            in
            {
              co = agentLayout "claude-opus --continue --dangerously-skip-permissions; or claude-opus --dangerously-skip-permissions";
              coh = agentLayout "claude-opus-huddle-current --continue; or claude-opus-huddle-current";
              cg = agentLayout "claude-glm --continue --dangerously-skip-permissions; or claude-glm --dangerously-skip-permissions";
              oc = agentLayout "opencode-attach-current";
              qc = agentLayout "qwencode -c";
              gc = agentLayout "gemini --yolo -r latest; or gemini --yolo";
              cx = agentLayout "codex-continue-current";
            };
        };

        programs.gh = {
          enable = true;
          settings.git_protocol = "ssh";
        };

        programs.k9s.enable = true;

        programs.mangohud.enable = true;

        programs.foot.enable = true;

        programs.mpv = {
          enable = true;
          scripts = [
            pkgs.mpvScripts.uosc
            pkgs.mpvScripts.thumbfast
          ];
          bindings = {
            q = "quit-watch-later";
            "Shift+q" = "quit";
          };
          config = {
            vo = "gpu-next";
            gpu-api = "vulkan";
            target-peak = 1200;
            target-contrast = "inf";
            autofit-larger = "80%x80%";
            hr-seek = "yes";
            target-colorspace-hint = "yes";
            scale = "ewa_lanczossharp";
            cscale = "ewa_lanczossharp";
            # Audio mixing (biased stereo)
            af = "lavfi=[pan=stereo|FL=FC+0.707*FL+0.5*SL+0.5*BL+0.5*LFE|FR=FC+0.707*FR+0.5*SR+0.5*BR+0.5*LFE]";
            volume-max = 100;
            sub-auto = "fuzzy";
            slang = "eng,en";
            sub-visibility = "yes";
            # UOSC
            osc = "no"; # Disable the default, blocky UI
            border = "no"; # Let uosc draw its own modern window border
            osd-bar = "no"; # Let uosc handle the volume/seek bars
          };
          profiles = {
            SDR-Reference = {
              profile-cond = "not p[\"video-params/sig-peak\"] or p[\"video-params/sig-peak\"] <= 1";
              target-peak = 100;
            };
            HDR-Impact = {
              profile-cond = "p[\"video-params/sig-peak\"] > 1";
              target-peak = 1200;
            };
          };
        };

        programs.vscode = {
          enable = true;
          package = pkgs.vscode;
          profiles.default = {
            extensions = [
              pkgs.vscode-extensions.banacorn.agda-mode
            ];
            userSettings = {
              "files.associations" = {
                "*.agda" = "agda";
                "*.lagda.md" = "agda";
              };
            };
          };
        };

        programs.zed-editor = {
          enable = true;
          #defaultEditor = true;
          mutableUserKeymaps = false;
          mutableUserSettings = false;
          mutableUserTasks = false;
          extensions = [
            "git-firefly"
            "haskell"
            "nix"
            "toml"
            "wit"
          ];
          extraPackages = [
            pkgs.nixd
            pkgs.nixfmt
            pkgs.haskell-language-server
            pkgs.package-version-server
            pkgs.ruff
            pkgs.rust-analyzer
            pkgs.basedpyright
            pkgs.vscode-langservers-extracted
            pkgs.yaml-language-server
          ];
          userSettings = {
            session = {
              trust_all_worktrees = true;
            };
            languages = {
              Nix = {
                language_servers = [
                  "nixd"
                  "!nil"
                ];
                formatter.external.command = "nixfmt";
              };
            };
            lsp = {
              nixd.binary.path = "nixd";
              nixfmt.binary.path = "nixfmt";
              haskell-language-server.binary.path = "haskell-language-server";
              rust-analyzer.binary.path = "rust-analyzer";
              basedpyright.binary.path = "basedpyright";
              vscode-json-languageserver.binary.path = "vscode-json-languageserver";
              yaml-language-server.binary.path = "yaml-language-server";
            };
          };
        };

        programs.voxtype = {
          enable = true;
          model.name = "large-v3-turbo";
          settings = {
            state_file = "auto";
            hotkey = {
              enabled = false;
            };
            audio = {
              device = "default";
              sample_rate = 16000;
              max_duration_secs = 90;
              feedback = {
                enabled = true;
                theme = "subtle";
                volume = 0.45;
              };
            };
            whisper = {
              mode = "local";
              language = "en";
              initial_prompt = "NixOS, Home Manager, flakes, sops, zellij, OpenCode, Codex, Claude, metastack, TypeScript, Rust.";
              gpu_device = 1;
              gpu_isolation = true;
              context_window_optimization = false;
            };
            output = {
              mode = "type";
              driver_order = [ "ydotool" ];
              fallback_to_clipboard = false;
              pre_type_delay_ms = 100;
              auto_submit = false;
              post_process = {
                command = "voxtype-post-process";
                timeout_ms = 5000;
              };
              notification = {
                on_recording_start = false;
                on_recording_stop = false;
                on_transcription = false;
              };
            };
            text = {
              spoken_punctuation = true;
              replacements = {
                "nix os" = "NixOS";
                "home manager" = "Home Manager";
                "open code" = "OpenCode";
                "zed leege" = "zellij";
                "sellij" = "zellij";
                "meta stack" = "metastack";
              };
            };
            status.icon_theme = "minimal";
          };
        };

        dconf.settings = {
          "org/gnome/desktop/peripherals/mouse" = {
            accel-profile = "flat";
            speed = 0.0;
          };
          "org/gnome/Console".shell = [ "${pkgs.fish}/bin/fish" ];
        };
      };
  };
}
