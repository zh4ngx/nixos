{
  pkgs,
  inputs,
  config,
  ...
}:

{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # Sops-nix configuration - all decryption at NixOS level using host key
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;

    secrets = {
      tailscale_auth_key = { };
      glm_token = {
        # Make readable by andy for Claude Code
        owner = "andy";
      };
      codeberg_token = {
        owner = "andy";
      };
      gemini_token = {
        owner = "andy";
      };
    };

    # Generate Claude Code settings.json
    templates."claude-settings.json" = {
      owner = "andy";
      group = "users";
      mode = "0400";
      content = ''
        {
          "env": {
            "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
            "ANTHROPIC_AUTH_TOKEN": "${config.sops.placeholder.glm_token}",
            "ANTHROPIC_MODEL": "glm-5.1",
            "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
            "DISABLE_TELEMETRY": "1",
            "CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY": "1",
            "DISABLE_ERROR_REPORTING": "1",
            "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "50000"
          },
          "statusLine": {
            "type": "command",
            "command": "~/.claude/statusline.sh"
          },
          "cleanupPeriodDays": 99999,
          "teammateMode": "tmux",
          "skipDangerousModePermissionPrompt": true,
          "attribution": {
            "commit": "",
            "pr": ""
          },
          "effortLevel": "high",
          "enabledPlugins": {
            "ralph-loop@claude-plugins-official": true
          }
        }
      '';
    };

    # Generate tea CLI config from template
    # Template file at secrets/tea-config.yml.tpl serves as reference
    templates."tea-config.yml" = {
      owner = "andy";
      group = "users";
      mode = "0400";
      content = ''
        logins:
          - name: codeberg
            url: https://codeberg.org
            token: ${config.sops.placeholder.codeberg_token}
            default: true
            ssh_host: codeberg.org
            ssh_key: /home/andy/.ssh/id_ed25519
            insecure: false
            user: zh4ng
      '';
    };

    # Generate OpenCode auth.json with API keys
    templates."opencode-auth.json" = {
      owner = "andy";
      group = "users";
      mode = "0400";
      content = ''
        {
          "zai": "${config.sops.placeholder.glm_token}",
          "gemini": "${config.sops.placeholder.gemini_token}"
        }
      '';
    };
  };

  # Bootloader.
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_latest;
  };

  networking = {
    nameservers = [
      "9.9.9.9#dns.quad9.net"
      "149.112.112.112#dns.quad9.net"
      "2620:fe::fe#dns.quad9.net"
      "2620:fe::9#dns.quad9.net"
    ];
  };

  services.resolved = {
    enable = true;
    settings = {
      Resolve = {
        DNSOverTLS = "yes";
        Domains = [ "~." ];
        FallbackDNS = [
          "1.1.1.1#cloudflare-dns.com"
          "2606:4700:4700::1111#cloudflare-dns.com"
        ];
      };
    };
  };

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = "daily";
      extraArgs = "--keep-since 3d --keep 3 --optimise";
    };
    flake = "/home/andy/dev/nixos";
  };

  system.autoUpgrade = {
    enable = true;
    flake = "github:zh4ngx/nixos";
    dates = "daily";
    persistent = true;
    operation = "switch";
    flags = [
      "--refresh"
    ];
  };

  systemd.services.nixos-upgrade = {
    # Ensures the service waits/retries if the network isn't ready
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "30s"; # Wait 30 seconds before retrying
    };
    unitConfig = {
      StartLimitIntervalSec = 300; # Allow retries for up to 5 minutes
      StartLimitBurst = 5; # Maximum 5 retries
    };
    # Optional: Explicitly check for internet before starting the main command
    preStart = "${pkgs.iputils}/bin/ping -c 1 8.8.8.8";
  };

  # Enable the COSMIC login manager
  # services.displayManager.cosmic-greeter.enable = true;

  # Enable the COSMIC desktop environment
  # services.desktopManager.cosmic.enable = true;

  programs.fish.enable = true;

  # Install and enable the Hyprland program and integrate it with UWSM.
  programs.hyprland = {
    enable = true;
    withUWSM = true; # Use the Universal Wayland Session Manager
  };

  # Enable a display manager that supports Wayland. SDDM is a reliable choice.
  # services.displayManager = {
  #   sddm = {
  #     enable = true;
  #     wayland.enable = true;
  #   };
  # };

  programs.nix-ld.enable = true;

  programs.ente-auth.enable = true;

  environment.systemPackages = [ pkgs.bitwarden-desktop ];
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.polkit.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # extraConfig.pipewire."99-motu-m2" = {
    #   "context.properties" = {
    #     # Lock the global sample rate to 96kHz
    #     "default.clock.rate" = 96000;
    #     # Set the buffer (quantum) to 128
    #     "default.clock.quantum" = 128;
    #     "default.clock.min-quantum" = 128;
    #     "default.clock.max-quantum" = 128;
    #   };
    # };
  };

  services.zenohd.enable = true;

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = config.sops.secrets.tailscale_auth_key.path;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  programs.tmux.enable = true;

  users.users.andy = {
    isNormalUser = true;
    description = "Andy";
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO4luyBTM8ikmWsD6YMJpna3GVn9NMqbxxsQ7Eg/vj+d" # Pixel 10
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCZ9PY00+8mhnD7SDx1luAmtHY86udWWwaX6OxBUok9" # Tablet
    ];
    extraGroups = [
      "networkmanager"
      "wheel"
      "abdusers"
      "kvm"
    ];
  };

  # Passwordless sudo for NixOS rebuild (remote access, automation)
  security.sudo.extraRules = [
    {
      users = [ "andy" ];
      commands = [
        {
          # Use the system profile path (symlink target) since sudo doesn't follow symlinks
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Allow unfree packages
  nixpkgs.config = {
    android_sdk.accept_license = true;
    allowUnfree = true;
  };

  # 1. High-level Flake Integration (replaces nix.registry and nix.settings.flake-registry)
  nixpkgs.flake = {
    setFlakeRegistry = true;
    setNixPath = true;
  };

  # 2. Modern Nix Behavior
  nix = {
    channel.enable = false;
    settings = {
      max-jobs = 4;
      cores = 2;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      use-xdg-base-directories = true;
      auto-optimise-store = true;
      extra-substituters = [
        "https://bytecodealliance.cachix.org"
        "https://wasmcloud.cachix.org"
        "https://nixify.cachix.org"
        "https://crane.cachix.org"
        "https://nix-community.cachix.org"
        "https://ros.cachix.org"
        "https://hyprland.cachix.org"
        "https://cosmic.cachix.org/"
        "https://claude-code.cachix.org"
      ];
      extra-trusted-substituters = [
        "https://bytecodealliance.cachix.org"
        "https://wasmcloud.cachix.org"
        "https://nixify.cachix.org"
        "https://crane.cachix.org"
        "https://nix-community.cachix.org"
        "https://ros.cachix.org"
        "https://hyprland.cachix.org"
        "https://cosmic.cachix.org/"
        "https://claude-code.cachix.org"
      ];
      extra-trusted-public-keys = [
        "bytecodealliance.cachix.org-1:0SBgh//n2n0heh0sDFhTm+ZKBRy2sInakzFGfzN531Y="
        "wasmcloud.cachix.org-1:9gRBzsKh+x2HbVVspreFg/6iFRiD4aOcUQfXVDl3hiM="
        "nixify.cachix.org-1:95SiUQuf8Ij0hwDweALJsLtnMyv/otZamWNRp1Q1pXw="
        "crane.cachix.org-1:8Scfpmn9w+hGdXH/Q9tTLiYAE/2dnJYRJP7kl80GuRk="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "ros.cachix.org-1:dSyZxI8geDCJrwgvCOHDoAfOm5sV1wCPjBkKL+38Rvo="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="
        "claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk="
      ];
    };
  };

  hardware.enableAllFirmware = true;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    # Required for containers under podman-compose to be able to talk to each other.
    defaultNetwork.settings.dns_enabled = true;
  };
}
