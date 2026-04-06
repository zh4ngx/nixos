{ config, ... }:
{
  programs.opencode = {
    enable = true;

    settings = {
      permission = "allow";
      model = "openrouter/google/gemma-4-26b-a4b-it";
      provider = {
        openrouter = {
          npm = "@ai-sdk/openai-compatible";
          name = "OpenRouter";
          options.baseURL = "https://openrouter.ai/api/v1";
          models = {
            "google/gemma-4-26b-a4b-it" = {
              name = "Gemma 4 26B A4B IT";
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
