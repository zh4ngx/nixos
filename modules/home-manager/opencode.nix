{ config, lib, pkgs, ... }:
{
  # Install OpenCode package
  home.packages = [ pkgs.opencode ];

  # OpenCode configuration
  xdg.configFile."opencode/opencode.json" = {
    text = builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";

      # Z.AI GLM-5.1 provider (OpenAI-compatible)
      provider = {
        zai = {
          npm = "@ai-sdk/openai-compatible";
          name = "Z.AI";
          options.baseURL = "https://api.z.ai/api/coding/paas/v4";
          models = {
            "glm-5.1" = {
              name = "GLM-5.1";
              limit = {
                context = 200000;
                output = 131072;
              };
            };
          };
        };
        # Gemini provider for long context
        gemini = {
          npm = "@ai-sdk/google";
          name = "Google Gemini";
          models = {
            "gemini-2.5-pro" = {
              name = "Gemini 2.5 Pro";
              limit = {
                context = 1000000;
                output = 65536;
              };
            };
          };
        };
      };

      # Default to GLM-5.1
      model = "zai/glm-5.1";
    };
  };

  # Auth credentials from sops template
  xdg.dataFile."opencode/auth.json".source =
    config.lib.file.mkOutOfStoreSymlink "/run/secrets/rendered/opencode-auth.json";
}
