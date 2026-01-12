{
  pkgs,
  lib,
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
      { config, ... }:
      {
        imports = [
          inputs.nix-index-database.homeModules.nix-index
        ];

        home.stateVersion = "23.05"; # Please read the comment before changing.

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
          beeper
          gnomeExtensions.appindicator
          gnomeExtensions.just-perfection
          gnomeExtensions.vitals
          qbittorrent
          radeontop
          ugs
        ];

        # Let Home Manager install and manage itself.
        programs.home-manager.enable = true;

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
            };
          };
          configFile = {
            "mimeapps.list".force = true;
            "uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
          };
        };

        # --- Hyprland configuration ---
        wayland.windowManager.hyprland = {
          enable = true;
          # set the Hyprland and XDPH packages to null to use the ones from the NixOS module
          package = null;
          portalPackage = null;
          # https://wiki.hypr.land/Nix/Hyprland-on-Home-Manager/#programs-dont-work-in-systemd-services-but-do-on-the-terminal
          # systemd.variables = [ "--all" ];
          systemd.enable = false;
          # Define Hyprland settings directly in Nix

          # Hyprland's configuration
          settings = {
            "$mod" = "SUPER";

            # -----------------
            # Keybindings
            # -----------------
            bind = [
              # Launch terminal (now Rio)
              "$mod, RETURN, exec, $terminal"

              # Kill active window
              "$mod, Q, killactive,"

              # Launch application menu (wofi)
              "$mod, D, exec, wofi --show drun"

              # File manager (dolphin)
              "$mod, E, exec, dolphin"

              # Exit Hyprland session (using UWSM's command)
              "$mod, M, exec, uwsm stop"

              # Screenshot tool (grimblast)
              "$mod, P, exec, grimblast copy area"

              # Reload Hyprland configuration
              "$mod, R, exec, hyprctl reload"

              # Switch to workspace
              "$mod, 1, workspace, 1"
              "$mod, 2, workspace, 2"
              "$mod, 3, workspace, 3"
              "$mod, 4, workspace, 4"
              "$mod, 5, workspace, 5"
              "$mod, 6, workspace, 6"
              "$mod, 7, workspace, 7"
              "$mod, 8, workspace, 8"
              "$mod, 9, workspace, 9"
              "$mod, 0, workspace, 10"

              # Move active window to a workspace
              "$mod SHIFT, 1, movetoworkspace, 1"
              "$mod SHIFT, 2, movetoworkspace, 2"
              "$mod SHIFT, 3, movetoworkspace, 3"
              "$mod SHIFT, 4, movetoworkspace, 4"
              "$mod SHIFT, 5, movetoworkspace, 5"
              "$mod SHIFT, 6, movetoworkspace, 6"
              "$mod SHIFT, 7, movetoworkspace, 7"
              "$mod SHIFT, 8, movetoworkspace, 8"
              "$mod SHIFT, 9, movetoworkspace, 9"
              "$mod SHIFT, 0, movetoworkspace, 10"

              # Move focus with arrow keys
              "$mod, left, movefocus, l"
              "$mod, right, movefocus, r"
              "$mod, up, movefocus, u"
              "$mod, down, movefocus, d"
            ];

            # -----------------
            # Graphics and aesthetics
            # -----------------
            animations = {
              enabled = true;
              bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
              animation = "windows, 1, 7, myBezier";
            };

            decoration = {
              rounding = 10;
              blur = {
                enabled = true;
                size = 5;
                passes = 3;
              };
              shadow = {
                enabled = true;
                color = "rgba(1a1a1aee)";
              };
            };
            input = {
              # 1:1 Tracking Settings
              accel_profile = "flat"; # Disables acceleration
              sensitivity = 0.0; # Neutral software multiplier (1.0x)
            };
          };
        };

        # --- Peripheral program declarations ---
        # Define and enable the status bar (Waybar)
        programs.waybar = {
          enable = true;
          # Configure Waybar directly in Nix
          settings = {
            main-bar = {
              layer = "top";
              position = "top";
              "hyprland/workspaces" = { };
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

        # Enable the application launcher (Rofi or Wofi)
        programs.rofi.enable = true;

        services.walker.enable = true;

        # Enable the notification daemon (Mako)
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
          plugins = [
            {
              name = "bass";
              src = pkgs.fishPlugins.bass.src;
            }
          ];
          interactiveShellInit = lib.mkAfter ''
            # 1. Erase the legacy event-based handlers from memory
            functions -e __fish_command_not_found_handler
            functions -e fish_command_not_found

            # 2. Manually define the modern nix-index / comma handler
            # We do NOT use --on-event here; modern Fish prefers the plain function name.
            function fish_command_not_found
                # This uses your comma/nix-index database to suggest packages
                if command -vq comma
                    comma $argv
                else
                    # Fallback to standard error if comma isn't ready
                    printf "Command '%s' not found\n" "$argv[1]"
                end
            end
          '';
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
          settings = {
            user = {
              name = "Andy Zhang";
              email = "1329212+zh4ngx@users.noreply.github.com";
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

        programs.k9s.enable = true;

        programs.mangohud.enable = true;

        programs.foot.enable = true;

        programs.mpv = {
          enable = true;
          scripts = [
            pkgs.mpvScripts.uosc
            pkgs.mpvScripts.thumbfast
          ];
          config = {
            vo = "gpu-next";
            gpu-api = "vulkan";
            target-peak = 1200;
            target-colorspace-hint = "yes";
            scale = "ewa_lanczossharp";
            cscale = "krigbilateral";
            # Audio mixing (biased stereo)
            af = "lavfi=[pan=stereo|FL=FC+0.707*FL+0.5*SL+0.5*BL+0.5*LFE|FR=FC+0.707*FR+0.5*SR+0.5*BR+0.5*LFE]";
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
            pkgs.nodePackages.vscode-json-languageserver
            pkgs.yaml-language-server
          ];
          userSettings = {
            languages = {
              Nix = {
                language_servers = [
                  "nixd"
                  "!nil"
                ];
              };
            };
          };
        };

        services.ollama = {
          enable = false;
          # acceleration = "rocm";
          # rocmOverrideGfx = "10.3.0"; # Replace with your version
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
