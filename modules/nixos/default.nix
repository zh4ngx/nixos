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
      ollama_api_key = {
        owner = "andy";
      };
      openrouter_api_key = {
        owner = "andy";
      };
      opencode_api_key = {
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
            "ANTHROPIC_BETA": "compact-2026-01-12",
            "HINDSIGHT_DYNAMIC_BANK_ID": "true"
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
          "voice": {
            "enabled": true,
            "mode": "hold",
            "autoSubmit": false
          },
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
          },
          "enabledPlugins": {
            "hindsight-memory@hindsight": true
          }
        }
      '';
    };

    # Env file for the hindsight-embed user service (systemd EnvironmentFile=).
    # API key stays out of /nix/store; rendered to /run/secrets/rendered/ at boot.
    # HINDSIGHT_EMBED_API_DATABASE_URL (note the EMBED infix) is read by the
    # `hindsight-embed daemon start` wrapper; if unset, it falls through to a
    # pg0:// URL and spawns embedded postgres regardless of HINDSIGHT_API_DATABASE_URL.
    # We point at the system postgres via Unix socket (peer auth as user `andy`).
    templates."hindsight-embed.env" = {
      owner = "andy";
      group = "users";
      mode = "0400";
      content = ''
        HINDSIGHT_API_LLM_PROVIDER=openai
        HINDSIGHT_API_LLM_BASE_URL=https://opencode.ai/zen/go/v1
        HINDSIGHT_API_LLM_API_KEY=${config.sops.placeholder.opencode_api_key}
        HINDSIGHT_API_LLM_MODEL=deepseek-v4-flash
        HINDSIGHT_EMBED_DAEMON_IDLE_TIMEOUT=0
        HINDSIGHT_EMBED_API_DATABASE_URL=postgresql://andy@127.0.0.1/hindsight
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
        openrouter = {
          type = "api";
          key = config.sops.placeholder.openrouter_api_key;
        };
        ollama = {
          type = "api";
          key = config.sops.placeholder.ollama_api_key;
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

  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      dates = "daily";
      extraArgs = "--keep-since 3d --keep 3 --optimise";
    };
    flake = "/home/andy/nixos";
  };

  system.autoUpgrade = {
    enable = true;
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

  programs.nix-ld = {
    enable = true;
    # Extra libs needed by hindsight-embed's bundled PostgreSQL 18.1 binaries
    # (initdb, postgres, psql — pg0-embedded shells out to psql to create
    # the hindsight role + database during first init). The default nix-ld
    # set covers libssl, libcrypto, libzstd, libz. The bundled binary expects
    # libxml2's legacy soname (libxml2.so.2) — current nixpkgs libxml2 uses
    # libxml2.so.16, so we explicitly pull libxml2_13 which still ships .so.2.
    libraries = with pkgs; [
      krb5 # libgssapi_krb5.so.2
      lz4 # liblz4.so.1
      libxml2_13 # libxml2.so.2 (legacy soname)
      readline # libreadline.so.8 (psql)
    ];
  };

  # hindsight-embed's bundled PostgreSQL was built with
  # --with-system-tzdata=/usr/share/zoneinfo (hardcoded). NixOS doesn't
  # populate /usr, so symlink that path to the system zoneinfo.
  systemd.tmpfiles.rules = [
    "L+ /usr/share/zoneinfo - - - - /etc/zoneinfo"
  ];

  # System postgres for the hindsight-embed daemon (replaces pg0-embedded).
  # Daemon connects via TCP loopback as user `andy` (trust auth on 127/::1)
  # using HINDSIGHT_EMBED_API_DATABASE_URL=postgresql://andy@127.0.0.1/hindsight.
  # pgvector is required by hindsight's HNSW indexes on memory_units.
  #
  # TCP instead of Unix socket: alembic's configparser interprets `%` in the
  # URL as interpolation syntax. SQLAlchemy URL-encodes a socket path (e.g.
  # `?host=/run/postgresql` → `?host=%2Frun%2Fpostgresql`), and configparser
  # then crashes on the `%2F`. TCP loopback avoids the encoding entirely.
  #
  # Superuser instead of ensureDBOwnership: NixOS's ensureDBOwnership=true
  # requires the role name to equal the database name, which would force
  # us to either rename the role (breaking peer auth from OS user `andy`)
  # or rename the database (breaking hindsight defaults). Granting `andy`
  # superuser is the pragmatic fix on this single-user box.
  #
  # trust auth on 127/::1: single-user host, no other postgres clients.
  # Default `peer` for local Unix socket is preserved for psql convenience.
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    extensions = ps: with ps; [ pgvector ];
    ensureDatabases = [ "hindsight" ];
    ensureUsers = [
      {
        name = "andy";
        ensureClauses = {
          login = true;
          superuser = true;
        };
      }
    ];
    authentication = pkgs.lib.mkOverride 10 ''
      local all all peer
      host  all all 127.0.0.1/32 trust
      host  all all ::1/128      trust
    '';
  };

  # Idempotent reapply of the `vector` extension into the hindsight DB on
  # every boot. ensureDatabases creates `hindsight` from template1 but does
  # not run CREATE EXTENSION; hindsight's alembic migrations assume the
  # extension is pre-loaded, so we install it before any client connects.
  # IF NOT EXISTS makes this a no-op when already present, so it covers
  # both fresh-cluster init and existing-cluster (self-heals if dropped).
  systemd.services.hindsight-pg-extensions = {
    description = "Ensure pgvector extension exists in hindsight database";
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "postgres";
      RemainAfterExit = true;
    };
    script = ''
      ${config.services.postgresql.package}/bin/psql -d hindsight \
        -c "CREATE EXTENSION IF NOT EXISTS vector"
    '';
  };

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
