{ config, ... }:
{
  programs.opencode = {
    enable = true;

    settings = {
      permission = "allow";
      model = "openrouter/moonshotai/kimi-k2.5";
      small_model = "local/gemma-4-e4b";

      provider = {
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
