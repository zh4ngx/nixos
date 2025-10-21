{ pkgs, config, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "andy";
  home.homeDirectory = "/home/andy";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
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
    polychromatic
    qbittorrent
    radeontop
    solaar
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/andy/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  home.sessionVariables = {
    EDITOR = "zeditor";
    BROWSER = "firefox";
    TERMINAL = "rio";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/andy/nixos-config"; # sets NH_OS_FLAKE variable for you
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

    # # Hyprland's configuration, with the terminal set to Rio.
    settings = {
      "$mod" = "SUPER";
      "$terminal" = "rio";

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
  };

  programs.bat.enable = true;
  programs.ripgrep.enable = true;
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
        program = "fish";
        args = [ ];
      };
      editor = {
        program = "zeditor";
        args = [ ];
      };
      renderer = {
        performance = "High";
        backend = "Vulkan";
      };
    };
  };

  programs.fish.enable = true;

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
    userName = "Andy Zhang";
    userEmail = "1329212+zh4ngx@users.noreply.github.com";
    extraConfig = {
      color = {
        ui = "auto";
      };
      core = {
        editor = "zeditor -w";
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
    scripts = [ pkgs.mpvScripts.uosc ];
    config = {
      vo = "gpu-next";
      gpu-api = "vulkan";
    };
  };

  programs.zed-editor = {
    enable = true;
    extensions = [
      "haskell"
      "nix"
      "toml"
      "wit"
    ];
    extraPackages = [
      pkgs.nixd
      pkgs.nixfmt-rfc-style
      pkgs.haskell-language-server
      pkgs.package-version-server
      pkgs.rust-analyzer
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

  # Integrate Home Manager environment variables with UWSM.
  xdg.configFile."uwsm/env".source =
    "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
}
