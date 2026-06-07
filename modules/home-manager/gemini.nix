{
  programs.antigravity-cli = {
    enable = true;
    enableMcpIntegration = true;
    defaultModel = "Gemini 3.5 Flash (High)";
    settings = {
      model = "Gemini 3.5 Flash (High)";
      statusLine = {
        type = "command";
        command = "\"\"";
        enabled = false;
      };
      toolPermission = "always-proceed";
      trustedWorkspaces = [
        "/home/andy"
        "/home/andy/office"
        "/home/andy/dev/nixpkgs"
      ];
    };
  };

  home.file.".gemini/config/mcp_config.json".force = true;
  home.file.".gemini/antigravity-cli/settings.json".force = true;
}
