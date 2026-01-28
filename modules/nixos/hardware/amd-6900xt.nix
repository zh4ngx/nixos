{ pkgs, ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    loadModels = [
      "qwen2.5-coder:32b"
      "qwen2.5-coder:14b"
    ];
    environmentVariables = {
      GGML_VK_VISIBLE_DEVICES = "0";
    };
  };

  services.open-webui = {
    enable = true;
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
    };
  };

  environment.systemPackages = [
    pkgs.amdgpu_top
  ];
}
