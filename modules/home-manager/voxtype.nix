{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.voxtype;
  tomlFormat = pkgs.formats.toml { };

  fetchWhisperModel =
    name: model:
    model
    // {
      engine = "whisper";
      path = pkgs.fetchurl {
        inherit (model) url hash;
        name = "ggml-${name}.bin";
      };
    };

  whisperModelDefs = builtins.mapAttrs fetchWhisperModel {
    "base.en" = {
      url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
      hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
    };
    "small.en" = {
      url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin";
      hash = "sha256-xhONbVjsyDIgl+D5h8MvG+i7ChhTKj+I9zTRu/nEHl0=";
    };
    "large-v3-turbo" = {
      url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin";
      hash = "sha256-H8cPd0046xaZk6w5Huo1fvR8iHV+9y7llDh5t+jivGk=";
    };
  };

  fetchParakeetFile =
    file: hash:
    pkgs.fetchurl {
      url = "https://huggingface.co/istupakov/parakeet-tdt-0.6b-v3-onnx/resolve/main/${file}";
      inherit hash;
    };

  parakeetModelDefs = {
    "parakeet-tdt-0.6b-v3-int8" = {
      engine = "parakeet";
      path = pkgs.linkFarm "parakeet-tdt-0.6b-v3-int8" [
        {
          name = "encoder-model.int8.onnx";
          path = fetchParakeetFile "encoder-model.int8.onnx" "sha256-YTnS+n4bCGCXsnfHFJcl7bq4nMfHrmSyPHQb5AVa/wk=";
        }
        {
          name = "decoder_joint-model.int8.onnx";
          path = fetchParakeetFile "decoder_joint-model.int8.onnx" "sha256-7qdIPuPRowN12u3I7YPjlgyRsJiBISeg2Z0ciXdmenA=";
        }
        {
          name = "vocab.txt";
          path = fetchParakeetFile "vocab.txt" "sha256-1YVEZ56kvGrFY9H1Ret9R0vWz6Rn8KbiwdwcfTfjw10=";
        }
        {
          name = "config.json";
          path = fetchParakeetFile "config.json" "sha256-ZmkDx2uXmMrywhCv1PbNYLCKjb+YAOyNejvA0hSKxGY=";
        }
      ];
    };
  };

  modelDefs = whisperModelDefs // parakeetModelDefs;

  resolvedModel =
    if cfg.model.path != null then
      cfg.model.path
    else if cfg.model.name != null then
      modelDefs.${cfg.model.name}.path
    else
      null;

  voxtypeToggle = pkgs.writeShellScriptBin "voxtype-toggle" ''
    #!/usr/bin/env bash
    set -euo pipefail
    exec ${lib.getExe cfg.package} record toggle
  '';

  voxtypeCancel = pkgs.writeShellScriptBin "voxtype-cancel" ''
    #!/usr/bin/env bash
    set -euo pipefail
    exec ${lib.getExe cfg.package} record cancel
  '';

  voxtypePostProcess = pkgs.writeShellScriptBin "voxtype-post-process" ''
    #!/usr/bin/env bash
    set -euo pipefail

    text="$(${pkgs.coreutils}/bin/cat)"
    runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}/voxtype"
    hook_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/voxtype/hooks"
    hook="$hook_dir/post-process"

    ${pkgs.coreutils}/bin/mkdir -p "$runtime_dir"
    printf '%s' "$text" > "$runtime_dir/last-transcript"

    if [ -x "$hook" ]; then
      printf '%s' "$text" | "$hook"
    else
      printf '%s' "$text"
    fi
  '';

  outputPackages = with pkgs; [
    dotool
    libnotify
    wl-clipboard
    which
    wtype
    xclip
    xdotool
    ydotool
  ];

  servicePath = lib.makeBinPath (
    [
      cfg.package
      pkgs.bash
      voxtypePostProcess
    ]
    ++ outputPackages
  );

  generatedSettings = lib.recursiveUpdate (lib.filterAttrs (_: v: v != null) {
    engine = cfg.engine;
    ${cfg.engine} = lib.optionalAttrs (resolvedModel != null) {
      model = toString resolvedModel;
    };
  }) cfg.settings;

  configFile = tomlFormat.generate "voxtype-config.toml" generatedSettings;
in
{
  options.programs.voxtype = {
    enable = lib.mkEnableOption "VoxType desktop speech-to-text";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.voxtype-vulkan;
      description = "VoxType package to run. Defaults to the Vulkan build.";
    };

    engine = lib.mkOption {
      type = lib.types.enum [
        "whisper"
        "parakeet"
        "moonshine"
        "sensevoice"
        "paraformer"
        "dolphin"
        "omnilingual"
      ];
      default = "whisper";
      description = "VoxType transcription engine.";
    };

    model = {
      name = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum (builtins.attrNames modelDefs));
        default = null;
        description = "Declaratively fetched VoxType model for the selected engine.";
      };

      path = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a VoxType model file or directory. Overrides model.name.";
      };
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      description = "VoxType TOML settings written to ~/.config/voxtype/config.toml.";
    };

    service.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run VoxType as a systemd user service.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.model.name != null && cfg.model.path != null);
        message = "programs.voxtype: set only one of model.name or model.path";
      }
      {
        assertion = cfg.model.name == null || modelDefs.${cfg.model.name}.engine == cfg.engine;
        message = "programs.voxtype: selected model.name is not for engine ${cfg.engine}";
      }
    ];

    home.packages = [
      cfg.package
      voxtypeToggle
      voxtypeCancel
      voxtypePostProcess
    ]
    ++ outputPackages;

    xdg.configFile = {
      "voxtype/config.toml".source = configFile;
      "voxtype/hooks/README.md".text = ''
        VoxType post-processing hook
        ============================

        Create an executable file at:

          ~/.config/voxtype/hooks/post-process

        The hook receives transcribed text on stdin and must print the text that
        VoxType should type/paste on stdout. It may also perform side effects,
        such as routing command-like utterances to metastack.

        If the hook is missing or not executable, dictation passes through
        unchanged. The latest raw transcript is also written to:

          $XDG_RUNTIME_DIR/voxtype/last-transcript
      '';
      "niri/voxtype.kdl".text = ''
        // VoxType bindings for niri.
        //
        // If your main niri config is declarative, copy these binds into its
        // binds block. On niri >= 25.11, you can also include this file from
        // ~/.config/niri/config.kdl.

        binds {
            Super+V repeat=false hotkey-overlay-title="Toggle Voice Dictation" {
                spawn "${voxtypeToggle}/bin/voxtype-toggle";
            }

            Super+Shift+V repeat=false hotkey-overlay-title="Cancel Voice Dictation" {
                spawn "${voxtypeCancel}/bin/voxtype-cancel";
            }
        }
      '';
    };

    systemd.user.services.voxtype = lib.mkIf cfg.service.enable {
      Unit = {
        Description = "VoxType desktop speech-to-text daemon";
        Documentation = "https://github.com/peteonrails/voxtype";
        PartOf = [ "graphical-session.target" ];
        After = [
          "graphical-session.target"
          "pipewire.service"
          "pipewire-pulse.service"
        ];
      };

      Service = {
        Type = "simple";
        Environment = [
          "PATH=${servicePath}"
          "YDOTOOL_SOCKET=/run/ydotoold/socket"
        ];
        ExecStart = "${lib.getExe cfg.package} --config ${configFile} daemon";
        Restart = "on-failure";
        RestartSec = "5s";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };

    programs.waybar.settings.main-bar = {
      modules-left = [ "custom/voxtype" ];
      modules-right = [
        "cpu"
        "memory"
        "clock"
        "tray"
      ];
      "custom/voxtype" = {
        exec = "${lib.getExe cfg.package} status --follow --format json --icon-theme minimal";
        return-type = "json";
        interval = "once";
        tooltip = true;
      };
    };

    dconf.settings = {
      "org/gnome/shell/keybindings" = {
        toggle-message-tray = [ "<Super>m" ];
      };
      "org/gnome/settings-daemon/plugins/media-keys" = {
        custom-keybindings = [
          "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voxtype-toggle/"
        ];
      };
      "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voxtype-toggle" = {
        name = "Voice Dictation";
        command = "${voxtypeToggle}/bin/voxtype-toggle";
        binding = "<Super>v";
      };
    };
  };
}
