{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.z.ai/api/anthropic",
    "ANTHROPIC_AUTH_TOKEN": "{{ .glm_token }}",
    "ANTHROPIC_MODEL": "glm-5",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  },
  "skipDangerousModePermissionPrompt": true,
  "effortLevel": "high",
  "enabledPlugins": {
    "ralph-loop@claude-plugins-official": true
  }
}
