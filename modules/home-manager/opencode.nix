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
        local = {
          npm = "@ai-sdk/openai-compatible";
          name = "Local (llama.cpp)";
          options.baseURL = "http://localhost:8081/v1";
          models = {
            "gemma-4-26b-a4b" = {
              name = "Gemma 4 26B A4B IT (Local)";
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
