{ pkgs, lib, ... }:

{
  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override { vulkanSupport = true; };
    host = "127.0.0.1";
    port = 8081;
    model = "/var/lib/llama-cpp/models/gemma-4-26b-a4b-q4km.gguf";
    extraFlags = [
      "-ngl" "99"
      "-c" "262144"
    ];
  };

  # Override systemd service to run as andy and set Vulkan device
  systemd.services.llama-cpp = {
    serviceConfig = {
      User = lib.mkForce "andy";
      Group = lib.mkForce "users";
      DynamicUser = lib.mkForce false;
      ProtectHome = lib.mkForce false;
      Environment = [
        "LLAMA_CACHE=/var/cache/llama-cpp"
        "GGML_VK_VISIBLE_DEVICES=0"
      ];
    };
  };

  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:8081/v1";
      WEBUI_AUTH = "False";
    };
  };

  environment.variables = {
    DRI_PRIME = "1";
  };

  environment.systemPackages = [
    pkgs.amdgpu_top
  ];
}
