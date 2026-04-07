{ config, ... }:
{
  programs.opencode = {
    enable = true;

    settings = {
      permission = "allow";
      model = "openrouter/moonshotai/kimi-k2.5";
      small_model = "openrouter/google/gemma-4-26b-a4b-it";

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
            "google/gemma-4-26b-a4b-it" = {
              name = "Gemma 4 26B A4B IT (MoE)";
              limit = {
                context = 262144;
                output = 262144;
              };
            };
          };
        };
        ollama = {
          npm = "@ai-sdk/openai-compatible";
          name = "Ollama (Local)";
          options.baseURL = "http://localhost:11434/v1";
          models = {
            "gemma4:31b-it-q4" = {
              name = "Gemma 4 31B IT Q4 (Local)";
              limit = {
                context = 262144;
                output = 262144;
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
