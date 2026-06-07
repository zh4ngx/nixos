{
  programs.antigravity-cli = {
    enable = true;
    enableMcpIntegration = true;
    defaultModel = "Gemini 3.5 Flash (High)";
  };

  home.file.".gemini/config/mcp_config.json".force = true;
  # AGY validates and rewrites this file on startup, so keep it mutable.
}
