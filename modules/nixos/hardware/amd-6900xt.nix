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
  environment.systemPackages = [
    pkgs.amdgpu_top
  ];
}
