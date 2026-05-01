{ config, lib, pkgs, ... }:

let
  cfg = config.programs.voxtype;
  tomlFormat = pkgs.formats.toml { };

  modelDefs = {
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

  resolvedModel =
    if cfg.model.path != null then
      cfg.model.path
    else if cfg.model.name != null then
      let modelDef = modelDefs.${cfg.model.name}; in
      pkgs.fetchurl {
        inherit (modelDef) url hash;
      }
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

  servicePath = lib.makeBinPath ([
    cfg.package
    pkgs.bash
    voxtypePostProcess
  ] ++ outputPackages);

  generatedSettings = lib.recursiveUpdate
    (lib.filterAttrs (_: v: v != null) {
      engine = cfg.engine;
      ${cfg.engine} = lib.optionalAttrs (resolvedModel != null) {
        model = toString resolvedModel;
      };
    })
    cfg.settings;

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
      type = lib.types.enum [ "whisper" ];
      default = "whisper";
      description = "VoxType transcription engine.";
    };

    model = {
      name = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum (builtins.attrNames modelDefs));
        default = null;
        description = "Declaratively fetched Whisper model.";
      };

      path = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a Whisper model file. Overrides model.name.";
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
    ];

    home.packages = [
      cfg.package
      voxtypeToggle
      voxtypeCancel
      voxtypePostProcess
    ] ++ outputPackages;

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
        ];
        ExecStart = "${lib.getExe cfg.package} daemon";
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
