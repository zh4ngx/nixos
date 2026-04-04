{ config, ... }:
{
  programs.opencode = {
    enable = true;

    settings = {
      model = "openrouter/qwen3.6-plus:free";
      provider = {
        openrouter = {
          npm = "@ai-sdk/openai-compatible";
          name = "OpenRouter";
          options.baseURL = "https://openrouter.ai/api/v1";
          models = {
            "qwen3.6-plus:free" = {
              name = "Qwen 3.6 Plus";
              limit = {
                context = 1000000;
                output = 65536;
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
