{
  programs.antigravity-cli = {
    enable = true;
    enableMcpIntegration = true;
    # Only exported as $GEMINI_MODEL; AGY owns the model actually in use via
    # its own mutable settings.json. Kept in sync so the two do not disagree.
    defaultModel = "Gemini 3.7 Flash (High)";
  };

  home.file.".gemini/config/mcp_config.json".force = true;
  # AGY validates and rewrites this file on startup, so keep it mutable.
}
