{ config, ... }:
{
  programs.opencode = {
    enable = true;
    enableMcpIntegration = true;

    settings = {
      permission = "allow";
      autoupdate = false;
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
          name = "Ollama Cloud";
          options.baseURL = "https://ollama.com/v1";
          models = {
            "minimax-m2.7:cloud" = {
              name = "MiniMax M2.7 (Ollama Cloud)";
              limit = {
                context = 262144;
                output = 262144;
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
  };

  # Auth credentials from sops template
  xdg.dataFile."opencode/auth.json".source =
    config.lib.file.mkOutOfStoreSymlink "/run/secrets/rendered/opencode-auth.json";
}
