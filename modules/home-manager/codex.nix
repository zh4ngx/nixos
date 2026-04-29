{ config, ... }:
{
  programs.codex = {
    enable = true;
    enableMcpIntegration = true;

    # OAuth via ChatGPT Pro subscription — `codex login` flow writes
    # credentials under $CODEX_HOME (defaults to ~/.codex). We do NOT
    # symlink ~/.codex/auth.json to /run/secrets — the OAuth tokens are
    # interactive-issued and refresh in place.
    settings = {
      # Prefer OAuth (ChatGPT Pro plan) over API key fallback.
      preferred_auth_method = "chatgpt";

      # No telemetry.
      hide_agent_reasoning = false;
    };
  };

  home.file.".codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "/home/andy/nixos/agents/AGENTS.md";
}
