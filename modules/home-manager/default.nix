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
          socat
          wl-clipboard
          # Bridge: Wyoming STT → Unix socket for voice-inject daemon
          # NOTE: services.wyoming.satellite exists but is a local-mic-to-Wyoming proxy
          # for Home Assistant pipelines. It doesn't output transcriptions to a socket/file.
          # A custom Python Wyoming protocol bridge is still needed to:
          #   1. Accept audio from Android app over Tailscale
          #   2. Forward to Wyoming STT server
          #   3. Parse Transcript events from the response
          #   4. Write transcript text to $XDG_RUNTIME_DIR/voice-stt.sock
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
          (pkgs.writeShellScriptBin "claude-glm" ''
            export CLAUDE_CONFIG_DIR="$HOME/.claude-glm"
            exec claude --mcp-config /run/secrets/rendered/claude-mcp.json "$@"
          '')
        ];

        # Voice dictation: inject STT transcriptions into tmux agent sessions
        # Connects to $XDG_RUNTIME_DIR/voice-stt.sock (written by Wyoming STT bridge)
        # Re-evaluates attached tmux session per transcription, injects via send-keys
        systemd.user.services.voice-inject = {
          Unit.Description = "Inject STT transcriptions into tmux agent sessions";
          Service = {
            ExecStart = "${pkgs.writeShellScript "voice-inject-daemon" ''
              #!/usr/bin/env bash
              set -euo pipefail

              SOCKET="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/voice-stt.sock"

              # Wait for socket to exist (bridge may not be running yet)
              while [ ! -S "$SOCKET" ]; do
                sleep 2
              done

              ${pkgs.socat}/bin/socat - UNIX-CONNECT:"$SOCKET" | while read -r line; do
                [ -z "$line" ] && continue

                # Target the tmux session with an attached client (re-evaluated per transcription)
                session=$(${pkgs.tmux}/bin/tmux list-sessions -F '#{session_name}:#{session_attached}' 2>/dev/null \
                  | grep ':1$' | head -1 | cut -d: -f1) || true

                # Fall back to first agent session if nothing is attached
                if [ -z "$session" ]; then
                  session=$(${pkgs.tmux}/bin/tmux list-sessions -F '#{session_name}' 2>/dev/null \
                    | grep -E '(co|cg|dev)$' | head -1) || continue
                fi

                ${pkgs.tmux}/bin/tmux send-keys -t "$session" -- "$line"

                # Wake phrases trigger Enter (case-insensitive)
                if [[ "''${line,,}" =~ (ship it|send it|execute|do it)$ ]]; then
                  ${pkgs.tmux}/bin/tmux send-keys -t "$session" Enter
                fi
              done
            ''}";
            Restart = "on-failure";
            RestartSec = "5s";
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
            # co: Claude Code with Anthropic Opus (Pro plan)
            co = "tmux new-session -A -D -s (basename $PWD | string replace -a . _)-co fish -c 'claude-opus --continue --dangerously-skip-permissions; or claude-opus --dangerously-skip-permissions'";
            # cg: Claude Code with Z.AI GLM
            cg = "tmux new-session -A -D -s (basename $PWD | string replace -a . _)-cg fish -c 'claude-glm --continue --dangerously-skip-permissions; or claude-glm --dangerously-skip-permissions'";
            # oc: start opencode (Default: MiniMax M2.7 via Ollama Cloud)
            oc = "tmux new-session -A -D -s (basename $PWD | string replace -a . _)-oc fish -c 'opencode -c'";
            # og: start opencode with Local Gemma 4 E4B (LOCAL TUI)
            og = "tmux new-session -A -D -s (basename $PWD | string replace -a . _)-og fish -c 'opencode -m local/gemma-4-e4b -c'";
            # qc: start qwen-code (Paid 3.6 Plus CLI)
            qc = "tmux new-session -A -D -s (basename $PWD | string replace -a . _)-qc fish -c 'qwencode -c'";
            # main: MainLoop (Opus 4.7 at ~, vault in scope)
            main = "tmux new-session -A -D -s main -c ~ fish -c 'claude-opus --continue --dangerously-skip-permissions --add-dir ~/vault; or claude-opus --dangerously-skip-permissions --add-dir ~/vault'";
            # mz: MainLoop via zellij (parallel install for evaluation vs tmux `main`)
            mz = ''
              if zellij list-sessions -sn --active 2>/dev/null | grep -qx main
                zellij attach main
              else
                zellij delete-session main --force 2>/dev/null
                pushd ~
                zellij -n main -s main
                popd
              end
            '';
            # gc: start gemini-cli
            gc = "tmux new-session -A -D -s (basename $PWD | string replace -a . _)-gc fish -c 'gemini --yolo -r latest || gemini --yolo'";
            # Title hook - sets window name for tmux to pass through
            fish_title = ''
              if set -q TMUX
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
          # Canonical shared resources in ~/.claude-shared
          ".claude-shared/CLAUDE.md".source = ./../../agents/AGENTS.md;
          ".claude-shared/scripts/fix-plugins-nixos.sh".source = ./../../files/fix-plugins-nixos.sh;

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

        # Parallel install with tmux for evaluation — user will compare and decide
        # whether to migrate AI launchers (co, cg, main, oc, og, qc, gc) later.
        programs.zellij = {
          enable = true;
          settings = {
            theme = "nord";
            show_release_notes = false;
            show_startup_tips = false;
          };
          layouts.main = ''
            layout {
                pane command="fish" close_on_exit=true {
                    args "-c" "claude-opus --continue --dangerously-skip-permissions --add-dir ~/vault; or claude-opus --dangerously-skip-permissions --add-dir ~/vault"
                }
            }
          '';
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
            language_models = {
              ollama = {
                api_url = "http://127.0.0.1:11434";
                low_speed_timeout_in_seconds = 60;
              };
            };
            assistant = {
              version = "2";
              selected_model = {
                provider = "ollama";
                model = "qwen2.5-coder:32b";
              };
            };
            inline_assist = {
              selected_model = {
                provider = "ollama";
                model = "qwen2.5-coder:14b";
              };
            };
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
