{
  config,
  pkgs,
  lib,
  ...
}:
let
  magicContextDreamerModel = "ollama-cloud/mistral-large-3:675b";
in
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
      meta = (pkgs.opencode.meta or { }) // {
        mainProgram = "opencode";
      };
      postBuild = ''
        wrapProgram $out/bin/opencode \
          --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ]}
      '';
    };

    settings = {
      permission = "allow";
      autoupdate = false;
      plugin = [ "@cortexkit/opencode-magic-context" ];
      # Magic Context manages context state itself; keep native OpenCode
      # compaction disabled so both systems do not fight over history.
      compaction = {
        auto = false;
        prune = false;
      };
      model = "opencode-go/qwen3.7-max";
      small_model = "opencode-go/deepseek-v4-flash";

      provider = {
        opencode-go = {
          npm = "@ai-sdk/openai-compatible";
          name = "OpenCode Go";
          options.baseURL = "https://opencode.ai/zen/go/v1";
        };
        zai-coding = {
          npm = "@ai-sdk/openai-compatible";
          name = "Z.AI Coding Plan";
          # GLM Coding Plan endpoint. If Andy's glm_token is not Coding
          # Plan-enabled, switch this one line to https://api.z.ai/api/paas/v4.
          options.baseURL = "https://api.z.ai/api/coding/paas/v4";
          models."glm-5.1" = {
            name = "GLM-5.1";
            limit = {
              context = 202752;
              output = 32768;
            };
            reasoning = true;
            temperature = true;
            tool_call = true;
            interleaved.field = "reasoning_content";
          };
        };
        ollama-cloud = {
          npm = "@ai-sdk/openai-compatible";
          name = "Ollama Cloud";
          # OpenCode's OpenAI-compatible adapter uses Ollama Cloud's /v1
          # surface; Ollama's native API lives under /api.
          options.baseURL = "https://ollama.com/v1";
          models = {
            "mistral-large-3:675b" = {
              name = "Mistral Large 3 675B";
              limit = {
                context = 262144;
                output = 262144;
              };
              attachment = true;
              reasoning = false;
              temperature = true;
              tool_call = true;
              modalities = {
                input = [
                  "text"
                  "image"
                ];
                output = [ "text" ];
              };
            };
            "qwen3-coder:480b" = {
              name = "Qwen3 Coder 480B";
              limit = {
                context = 262144;
                output = 65536;
              };
              attachment = false;
              reasoning = false;
              temperature = true;
              tool_call = true;
              modalities = {
                input = [ "text" ];
                output = [ "text" ];
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
      model = "zai-coding/glm-5.1";
    };
    dreamer = {
      enabled = true;
      model = magicContextDreamerModel;
      schedule = "02:00-06:00";
      tasks = [
        "consolidate"
        "verify"
        "archive-stale"
        "improve"
      ];
    };
    sidekick = {
      enabled = true;
      model = "zai-coding/glm-5.1";
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
