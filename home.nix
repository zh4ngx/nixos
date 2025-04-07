{ config, pkgs, ... }:

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
    gnomeExtensions.appindicator
    gnomeExtensions.dash-to-dock
    gnomeExtensions.just-perfection
    gnomeExtensions.vitals
    qbittorrent
    radeontop
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

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableBashIntegration = true;
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

  programs.bash.enable = true;
  programs.fish.enable = true;

  programs.eza = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
  };

  programs.firefox.enable = true;

  programs.chromium = {
    enable = true;
    package = pkgs.google-chrome;
  };

  programs.emacs = {
    enable = true;
    extraPackages = epkgs: [ epkgs.nix-mode epkgs.magit ];
  };

  programs.git = {
    enable = true;
    userName = "Andy Zhang";
    userEmail = "1329212+zh4ngx@users.noreply.github.com";
    extraConfig = {
      color = { ui = "auto"; };
      core = { editor = "zeditor -w"; };
      push = {
        default = "simple";
        autoSetupRemote = true;
      };
      pull = { rebase = true; };
      branch = { autosetuprebase = "always"; };
      init = { defaultBranch = "main"; };
    };
  };

  programs.htop.enable = true;

  programs.k9s.enable = true;

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
    extensions = [ "nix" "toml" "wit" ];
    extraPackages = [ pkgs.nixd pkgs.nixfmt-rfc-style ];
    userSettings = {
      languages = { Nix = { language_servers = [ "nixd" "!nil" ]; }; };
    };
  };
}
