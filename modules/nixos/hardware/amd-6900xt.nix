{ pkgs, inputs, ... }:
let
  stable-pkgs = import inputs.nixpkgs-stable { system = "x86_64-linux"; };
in
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
      ENABLE_PERSISTENT_CONFIG = "False";
      # Web Search Connectivity
      ENABLE_RAG_WEB_SEARCH = "True";
      RAG_WEB_SEARCH_ENGINE = "searxng";
      RAG_WEB_SEARCH_BASE_URL = "http://127.0.0.1<query>&format=json";
      # This makes the model "think" before searching (Gemini style)
      ENABLE_SEARCH_QUERY_GENERATION = "True";
    };
  };

  services.searx = {
    enable = true;
    package = stable-pkgs.searxng;
    redisCreateLocally = false;
    settings = {
      server = {
        port = 8888;
        bind_address = "127.0.0.1"; # This is your real security
        secret_key = "placeholder_key_for_local_use"; # Safe for public GitHub
        limiter = false; # Disable the internal rate-limiter
        public_instance = false;
      };
      user_agent_override = "Mozilla/5.0 (X11; Linux x86_64; rv:134.0) Gecko/20100101 Firefox/134.0";
      search.formats = [
        "html"
        "json"
      ];
      engines = [
        {
          name = "brave";
          engine = "brave";
          shortcut = "br";
        }
        {
          name = "qwant";
          engine = "qwant";
          shortcut = "qw";
        }
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
