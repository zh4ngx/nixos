{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.opencode = {
    enable = true;
    enableMcpIntegration = true;
    extraPackages = [ pkgs.bun ];

    # opencode ships as a Bun standalone (statically-linked, no ELF interp)
    # that dlopen()s libstdc++.so.6 at runtime for its file-watcher native
    # binding. nix-ld can't help (no dynamic linker to intercept), so we
    # inject LD_LIBRARY_PATH via a wrapper. Narrow scope: only opencode's
    # own process tree sees the prefix.
    package = pkgs.symlinkJoin {
      name = "opencode-with-libstdcxx";
      paths = [ pkgs.opencode ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/opencode \
          --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}
      '';
    };

    settings = {
      permission = "allow";
      autoupdate = false;
      plugin = [ "@cortexkit/opencode-magic-context" ];
      compaction = {
        auto = false;
        prune = false;
      };
      model = "opencode-go/deepseek-v4-pro";
      small_model = "opencode-go/deepseek-v4-flash";

      provider = {
        opencode-go = {
          npm = "@ai-sdk/openai-compatible";
          name = "OpenCode Go";
          options.baseURL = "https://opencode.ai/zen/go/v1";
        };
        ollama = {
          npm = "@ai-sdk/openai-compatible";
          name = "Local Gemma (llama.cpp)";
          options.baseURL = "http://localhost:8081/v1";
          models = {
            "gemma-4-e4b" = {
              name = "Gemma 4 E4B IT (Local)";
              limit = {
                context = 131072;
                output = 131072;
              };
            };
          };
        };
        openrouter = {
          npm = "@ai-sdk/openai-compatible";
          name = "OpenRouter";
          options.baseURL = "https://openrouter.ai/api/v1";
          models = {
            "moonshotai/kimi-k2.5" = {
              name = "Kimi K2.5";
              limit = {
                context = 262144;
                output = 262144;
              };
            };
            "minimax/minimax-m2.5:free" = {
              name = "MiniMax 2.5 (Free)";
              limit = {
                context = 128000;
                output = 128000;
              };
            };
            "deepseek/deepseek-v4-pro" = {
              name = "DeepSeek V4 Pro";
              limit = {
                context = 1048576;
                output = 131072;
              };
            };
            "deepseek/deepseek-v4-flash" = {
              name = "DeepSeek V4 Flash";
              limit = {
                context = 1048576;
                output = 131072;
              };
            };
            "google/gemini-3-flash" = {
              name = "Gemini 3 Flash";
              limit = {
                context = 1048576;
                output = 65536;
              };
            };
          };
        };
        local = {
          npm = "@ai-sdk/openai-compatible";
          name = "Local (llama.cpp)";
          options.baseURL = "http://localhost:8081/v1";
          models = {
            "gemma-4-e4b" = {
              name = "Gemma 4 E4B IT (Local)";
              limit = {
                context = 131072;
                output = 131072;
              };
            };
          };
        };
      };
    };

    tui = {
      plugin = [ "@cortexkit/opencode-magic-context" ];
    };
  };

  xdg.configFile."opencode/magic-context.jsonc".text = builtins.toJSON {
    "$schema" = "https://raw.githubusercontent.com/cortexkit/opencode-magic-context/master/assets/magic-context.schema.json";
    enabled = true;
    historian = {
      model = "opencode-go/glm-5.1";
    };
    dreamer = {
      enabled = true;
      model = "opencode-go/qwen3.5-plus";
      schedule = "02:00-06:00";
      tasks = [
        "consolidate"
        "verify"
        "archive-stale"
        "improve"
        "maintain-docs"
      ];
    };
    sidekick = {
      enabled = true;
      model = "opencode-go/gemini-3-flash";
      timeout_ms = 30000;
    };
  };

  # Auth credentials from sops template
  xdg.dataFile."opencode/auth.json".source =
    config.lib.file.mkOutOfStoreSymlink "/run/secrets/rendered/opencode-auth.json";

  # Structured-injection substrate for OpenCode project agents. Normal TUI
  # launchers attach to this server, so external orchestrators can address the
  # same sessions through the OpenCode HTTP API instead of zellij keystrokes.
  systemd.user.services.opencode-serve = {
    Unit = {
      Description = "OpenCode API server for attachable agent sessions";
      After = [ "network.target" ];
    };

    Service = {
      ExecStart = "${lib.getExe' config.programs.opencode.package "opencode"} serve --hostname 127.0.0.1 --port 4096";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
