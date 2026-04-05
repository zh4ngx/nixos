{ ... }:
{
  programs.opencode = {
    enable = true;

    settings = {
      permission = "allow";
      model = "openrouter/qwen3.6-plus:free";
    };
  };
}
