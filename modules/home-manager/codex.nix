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

      model = "gpt-5.5";
      model_reasoning_effort = "xhigh";
      sandbox_mode = "danger-full-access";
      approval_policy = "never";

      tui.status_line = [
        "model-with-reasoning"
        "git-branch"
        "task-progress"
        "context-remaining"
        "context-used"
        "context-window-size"
        "five-hour-limit"
        "weekly-limit"
        "current-dir"
      ];

      # No telemetry.
      hide_agent_reasoning = false;
    };
  };

  home.file.".config/codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "/home/andy/nixos/agents/AGENTS.md";
}
