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
      OLLAMA_CONTEXT_LENGTH = "8192";
      GGML_VK_VISIBLE_DEVICES = "0";
    };
  };

  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      WEBUI_AUTH = "False";
      # Web Search Connectivity
      ENABLE_RAG_WEB_SEARCH = "True";
      RAG_WEB_SEARCH_ENGINE = "searxng";
      RAG_WEB_SEARCH_BASE_URL = "http://127.0.0.1:8888";
    };
  };

  services.searx = {
    enable = true;
    redisCreateLocally = false;
    settings = {
      server = {
        port = 8888;
        bind_address = "127.0.0.1"; # This is your real security
        secret_key = "placeholder_key_for_local_use"; # Safe for public GitHub
      };
      search.formats = [
        "html"
        "json"
      ];
      engines = [
        {
          name = "duckduckgo";
          engine = "duckduckgo";
        }
        {
          name = "wikipedia";
          engine = "wikipedia";
        }
      ];
    };
  };

  environment.variables = {
    DRI_PRIME = "1";
  };

  environment.systemPackages = [
    pkgs.amdgpu_top
  ];
}
