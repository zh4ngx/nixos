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
      # SutroYaro Telegram credentials
      telegram_api_id = {
        owner = "andy";
      };
      telegram_api_hash = {
        owner = "andy";
      };
      telegram_bot_token = {
        owner = "andy";
      };
      sutro_group_chat_id = {
        owner = "andy";
      };
      openrouter_api_key = {
        owner = "andy";
      };
      opencode_api_key = {
        owner = "andy";
      };
      ollama_api_key = {
        owner = "andy";
      };
      brave_api_key = {
        owner = "andy";
      };
    };

    # Generate Claude Code settings.json for Opus instance (Anthropic direct, OAuth)
    templates."claude-settings-opus.json" = {
      owner = "andy";
      group = "users";
      mode = "0400";
      content = ''
        {
          "env": {
            "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
            "CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY": "1",
            "DISABLE_ERROR_REPORTING": "1",
            "ANTHROPIC_BETA": "compact-2026-01-12"
          },
          "permissions": {
            "deny": [
              "Bash(nix search:*)"
            ]
          },
          "effortLevel": "xhigh",
          "alwaysThinkingEnabled": true,
          "cleanupPeriodDays": 99999,
          "teammateMode": "tmux",
          "skipDangerousModePermissionPrompt": true,
          "language": "en",
          "statusLine": {
            "type": "command",
            "command": "~/.claude-shared/scripts/statusline.sh"
          },
          "context_management": {
            "edits": [{
              "type": "compact_20260112",
              "trigger": {"type": "input_tokens", "value": 400000},
              "instruction": "Preserve mathematical formulations, design decisions, code references, file paths, key open questions. Discard tool-result chatter and stale debugging output."
            }]
          }
        }
      '';
    };

    # Generate Claude Code settings.json for GLM instance (Z.AI endpoint)
    templates."claude-settings-glm.json" = {
      owner = "andy";
      group = "users";
      mode = "0400";
      content = ''
        {
          "env": {
            "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
            "ANTHROPIC_AUTH_TOKEN": "${config.sops.placeholder.glm_token}",
            "ANTHROPIC_MODEL": "glm-5.1",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": "glm-5.1",
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "glm-5.1",
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "glm-5.1",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL_SUPPORTED_CAPABILITIES": "effort",
            "ANTHROPIC_DEFAULT_SONNET_MODEL_SUPPORTED_CAPABILITIES": "effort",
            "ANTHROPIC_DEFAULT_OPUS_MODEL_SUPPORTED_CAPABILITIES": "effort",
            "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
            "DISABLE_TELEMETRY": "1",
            "CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY": "1",
            "DISABLE_ERROR_REPORTING": "1"
          },
          "permissions": {
            "deny": [
              "Bash(nix search:*)"
            ]
          },
          "effortLevel": "high",
          "cleanupPeriodDays": 99999,
          "teammateMode": "tmux",
          "skipDangerousModePermissionPrompt": true,
          "attribution": {
            "commit": "Co-Authored-By: GLM 5.1 <noreply@z.ai>"
          },
          "statusLine": {
            "type": "command",
            "command": "~/.claude-shared/scripts/statusline.sh"
          },
          "enabledPlugins": {
            "ralph-loop@claude-plugins-official": true
          }
        }
      '';
    };

    # Shared MCP config for both claude-opus and claude-glm.
    # Loaded via --mcp-config flag (claude does not read mcpServers from settings.json).
    templates."claude-mcp.json" = {
      owner = "andy";
      group = "users";
      mode = "0400";
      content = ''
        {
          "mcpServers": {
            "brave-search": {
              "command": "nix",
              "args": ["shell", "nixpkgs#nodejs", "-c", "npx", "-y", "@modelcontextprotocol/server-brave-search"],
              "env": {
                "BRAVE_API_KEY": "${config.sops.placeholder.brave_api_key}"
              }
            },
            "nixos": {
              "command": "${pkgs.mcp-nixos}/bin/mcp-nixos"
            },
            "zellij": {
              "command": "/home/andy/dev/zellij-mcp/target/release/zellij-mcp"
            }
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
      content = builtins.toJSON {
        opencode = {
          type = "api";
          key = config.sops.placeholder.opencode_api_key;
        };
        opencode-go = {
          type = "api";
          key = config.sops.placeholder.opencode_api_key;
        };
        zai-coding = {
          type = "api";
          key = config.sops.placeholder.glm_token;
        };
        ollama-cloud = {
          type = "api";
          key = config.sops.placeholder.ollama_api_key;
        };
        openrouter = {
          type = "api";
          key = config.sops.placeholder.openrouter_api_key;
        };
      };
    };
  };

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
  programs.niri = {
    enable = true;
    useNautilus = true;
  };

  programs.nh = {
    enable = true;
    clean = {
      enable = false;
      dates = "daily";
      extraArgs = "--keep-since 3d --keep 3 --optimise";
    };
    flake = "/home/andy/nixos";
  };

  system.autoUpgrade = {
    enable = false;
    flake = "github:zh4ngx/nixos";
    dates = "daily";
    persistent = true;
    operation = "switch";
    upgrade = false;
  };

  systemd.services.nixos-upgrade = {
    # Give the network stack time to settle after boot, then retry transient fetch failures.
    preStart = ''
      ${pkgs.coreutils}/bin/sleep 120
    '';
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "2min";
    };
    unitConfig = {
      StartLimitIntervalSec = 1800;
      StartLimitBurst = 10;
    };
  };

  # Enable the COSMIC login manager
  # services.displayManager.cosmic-greeter.enable = true;

  # Enable the COSMIC desktop environment
  # services.desktopManager.cosmic.enable = true;

  programs.fish.enable = true;

  # Enable a display manager that supports Wayland. SDDM is a reliable choice.
  # services.displayManager = {
  #   sddm = {
  #     enable = true;
  #     wayland.enable = true;
  #   };
  # };

  programs.ente-auth.enable = true;

  environment.systemPackages = [
    pkgs.bitwarden-desktop
    pkgs.python3
    pkgs.sops
    pkgs.ssh-to-age
    pkgs.uv
  ];
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

  # Desktop dictation output fallbacks use uinput-backed virtual keyboard
  # injection so they work on GNOME Wayland as well as wlroots compositors.
  # Do not grant the broader input group unless VoxType's evdev hotkey mode is
  # enabled later; current config uses compositor shortcuts instead.
  hardware.uinput.enable = true;
  programs.ydotool = {
    enable = true;
    # ydotoold exposes a group-gated Unix socket. Use the existing primary
    # desktop-user group so the running user manager can use it without a
    # logout after enabling VoxType.
    group = "users";
  };

  services.zenohd.enable = true;

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = config.sops.secrets.tailscale_auth_key.path;
  };

  # Local STT via Wyoming protocol (Faster Whisper)
  # TODO: ROCm acceleration — module only supports cpu/cuda/auto, no AMD option yet
  services.wyoming.faster-whisper.servers.stt = {
    enable = true;
    uri = "tcp://0.0.0.0:10300";
    model = "turbo";
    language = "en";
    device = "cpu";
    sttLibrary = "faster-whisper";
    initialPrompt = "NixOS, tmux, Claude, agent, flake, rebuild, sops";
    beamSize = 5;
  };
  # Restrict STT to Tailscale interface only (survives IP changes)
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 10300 ];

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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHDTaGIMzQlCeDp3zIedPLLKv+Gg4athxZBAhl6v9Uv2"
    ];
    extraGroups = [
      "networkmanager"
      "wheel"
      "abdusers"
      "kvm"
      "uinput"
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

  # Disable flaky tests for python packages where upstream test brittleness
  # blocks NixOS rebuilds.
  # - aioboto3: moto/werkzeug "Duplicate 'Server' header" failures on nixpkgs
  #   unstable rev 01fbdeef (Apr 23 2026). Cascades to py-key-value-aio ->
  #   fastmcp -> mcp-nixos -> home-manager-path.
  # - fastmcp: pytest hangs on multi-client/keep-alive/timeout/sampling tests
  #   despite ~30 explicit -k exclusions in the derivation. test_sampling_tool
  #   in particular reliably hangs builds; rebuilds take 10+ min when uncached.
  nixpkgs.overlays = [
    (final: prev: {
      python313 = prev.python313.override {
        packageOverrides = pyFinal: pyPrev: {
          aioboto3 = pyPrev.aioboto3.overridePythonAttrs (_: {
            doCheck = false;
            doInstallCheck = false;
          });
          fastmcp = pyPrev.fastmcp.overridePythonAttrs (_: {
            doCheck = false;
            doInstallCheck = false;
          });
          lupa = pyPrev.lupa.overridePythonAttrs (old: {
            # fakeredis 2.33.0 hardcodes `import lupa.lua51`, but nixpkgs sets
            # LUPA_NO_BUNDLE=true so only luajit ships. Bundle lua51 from the
            # sdist (the other third-party/lua* dirs are empty in the PyPI
            # source, so we remove them to stop setup.py from iterating them).
            env = builtins.removeAttrs (old.env or {}) [ "LUPA_NO_BUNDLE" ];
            buildInputs = [];
            postPatch = (old.postPatch or "") + ''
              for d in third-party/lua52 third-party/lua53 third-party/lua54 \
                       third-party/lua55 third-party/luajit20 third-party/luajit21; do
                if [ -d "$d" ] && [ -z "$(ls -A "$d" 2>/dev/null)" ]; then
                  rmdir "$d"
                fi
              done
            '';
          });
        };
      };
    })
  ];

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
