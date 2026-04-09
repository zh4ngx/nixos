{ config, ... }:
{
  programs.gemini-cli = {
    enable = true;
    defaultModel = "auto";
    settings = {
      general = {
        vimMode = true;
        sessionRetention.enabled = false;
        checkpointing.enabled = false;
      };
      model = {
        name = "auto";
        compressionThreshold = 0.9;
      };
      ui = {
        hideContextPercentage = false;
        showMemoryUsage = true;
        hideBanner = true;
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
