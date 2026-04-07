{ config, ... }:
{
  programs.opencode = {
    enable = true;

    settings = {
      permission = "allow";
      model = "ollama/gemma4:31b-it-q4";
      small_model = "ollama/gemma4:26b-a4b-it-q4";

      provider = {
        ollama = {
          npm = "@ai-sdk/openai-compatible";
          name = "Ollama (Local)";
          options.baseURL = "http://localhost:11434/v1";
          models = {
            "gemma4:31b-it-q4" = {
              name = "Gemma 4 31B IT Q4 (Dense, Local)";
              limit = {
                context = 262144;
                output = 262144;
              };
            };
            "gemma4:26b-a4b-it-q4" = {
              name = "Gemma 4 26B A4B IT Q4 (MoE, Local)";
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

  # Auth credentials from sops template (kept for OpenRouter fallback)
  xdg.dataFile."opencode/auth.json".source =
    config.lib.file.mkOutOfStoreSymlink "/run/secrets/rendered/opencode-auth.json";
}
