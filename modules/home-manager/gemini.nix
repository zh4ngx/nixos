{ config, ... }:
{
  programs.gemini-cli = {
    enable = true;
    defaultModel = "gemini-3.1-pro-preview";
    settings = {
      general = {
        vimMode = true;
      };
      privacy = {
        usageStatisticsEnabled = false;
      };
      security = {
        auth = {
          selectedType = "vertex-ai";
        };
      };
    };
  };

  # Configure Vertex AI authentication via ADC
  programs.fish.shellInit = ''
    set -gx GOOGLE_CLOUD_PROJECT "capped-gemini"
    set -gx GOOGLE_CLOUD_LOCATION "global"
  '';
}
