{ pkgs, ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-vulkan;
    loadModels = [ "qwen2.5-coder:32b" ];
  };
  environment.systemPackages = [
    pkgs.amdgpu_top
  ];
}
