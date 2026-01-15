{
  pkgs,
  ...
}:

{
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

  # Enable networking
  networking.networkmanager.enable = true;

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

  users.users.andy = {
    isNormalUser = true;
    description = "Andy";
    shell = pkgs.fish;
    extraGroups = [
      "networkmanager"
      "wheel"
      "abdusers"
      "kvm"
    ];
  };

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
