{ pkgs, ... }:

{
  nixpkgs.config.rocmSupport = true;
  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    rocmOverrideGfx = "10.3.0";
  };

  services.ollama.loadModels = [ "qwen2.5-coder:32b" ];
}
