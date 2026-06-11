{ config, lib, ... }:
let
  codexHome = "${config.xdg.configHome}/codex";
in
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

      notice = {
        hide_rate_limit_model_nudge = true;
      };

      projects."/home/andy".trust_level = "trusted";

      features = {
        image_generation = false;
      };
    };
  };

  home.file.".config/codex/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "/home/andy/nixos/agents/AGENTS.md";

  # Structured-injection substrate for Codex project agents. `cx` connects its
  # TUI to this loopback app-server, so orchestrators can use the Codex
  # app-server JSON-RPC protocol instead of zellij keystrokes for sessions
  # launched through the remote-backed path.
  systemd.user.services.codex-app-server = {
    Unit = {
      Description = "Codex app-server for remote agent sessions";
      After = [ "network.target" ];
    };

    Service = {
      Environment = "CODEX_HOME=${config.xdg.configHome}/codex";
      ExecStart = "${lib.getExe config.programs.codex.package} app-server --listen ws://127.0.0.1:4107 -c notice.hide_rate_limit_model_nudge=true";
      Restart = "on-failure";
      RestartSec = "5s";
    };

    Install.WantedBy = [ "default.target" ];
  };
}
