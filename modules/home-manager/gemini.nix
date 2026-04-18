{ config, ... }:
{
  programs.gemini-cli = {
    enable = true;
    defaultModel = "gemini-3.1-pro-preview";
    settings = {
      general = {
        vimMode = true;
        sessionRetention.enabled = false;
        checkpointing.enabled = false;
      };
      model = {
        name = "gemini-3.1-pro-preview";
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
          selectedType = "oauth-personal";
        };
      };
    };
  };

  # Gemini model pinning
  programs.fish.shellInit = ''
    set -gx GEMINI_MODEL "gemini-3.1-pro-preview"
  '';
}
