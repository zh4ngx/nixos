{
  inputs,
  lib,
  pkgs,
  self,
  ...
}:

let
  hwmonTemperatureLog = pkgs.writeShellApplication {
    name = "hwmon-temperature-log";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.util-linux
    ];
    text = ''
      set -euo pipefail

      log_dir="''${HWMON_TEMPERATURE_LOG_DIR:-/var/log/hwmon-temperature}"
      log_file="$log_dir/temperature.jsonl"
      powercap_state_file="$log_dir/powercap-state.tsv"
      retention_samples="''${HWMON_TEMPERATURE_RETENTION_SAMPLES:-1440}"

      json_string() {
        jq -Rn --arg v "$1" '$v'
      }

      json_num_or_null() {
        if [[ "''${1:-}" =~ ^-?[0-9]+$ ]]; then
          printf '%s' "$1"
        else
          printf 'null'
        fi
      }

      json_decimal_or_null() {
        if [[ "''${1:-}" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
          printf '%s' "$1"
        else
          printf 'null'
        fi
      }

      read_optional() {
        local path="$1"
        if [ -r "$path" ]; then
          tr -d '\n' < "$path"
        fi
      }

      read_multiline() {
        local path="$1"
        if [ -r "$path" ]; then
          tr '\n' ';' < "$path"
        fi
      }

      is_integer() {
        [[ "''${1:-}" =~ ^-?[0-9]+$ ]]
      }

      metric_kind() {
        case "$1" in
          temp*) printf 'temperature' ;;
          power*) printf 'power' ;;
          fan*) printf 'fan' ;;
          freq*) printf 'frequency' ;;
          in*) printf 'voltage' ;;
          pwm*) printf 'pwm' ;;
          *) printf 'raw' ;;
        esac
      }

      metric_unit() {
        case "$1" in
          temp*) printf 'millidegrees_c' ;;
          power*) printf 'microwatts' ;;
          fan*) printf 'rpm' ;;
          freq*) printf 'hertz' ;;
          in*) printf 'millivolts' ;;
          pwm*) printf 'raw' ;;
          *) printf 'raw' ;;
        esac
      }

      emit_metric() {
        local hwmon="$1"
        local name="$2"
        local sensor="$3"
        local label="$4"
        local kind="$5"
        local unit="$6"
        local value="$7"

        if ! is_integer "$value"; then
          return
        fi

        if [ "$first_metric" -eq 1 ]; then
          first_metric=0
        else
          printf ','
        fi

        printf '{"source":"hwmon","hwmon":%s,"name":%s,"sensor":%s,"label":%s,"kind":%s,"unit":%s,"value":%s}' \
          "$(json_string "$hwmon")" \
          "$(json_string "$name")" \
          "$(json_string "$sensor")" \
          "$(json_string "$label")" \
          "$(json_string "$kind")" \
          "$(json_string "$unit")" \
          "$value"
      }

      mkdir -p "$log_dir"
      exec 9>"$log_dir/.lock"
      if ! flock -n 9; then
        exit 0
      fi

      tmp=$(mktemp)
      new_powercap_state=$(mktemp)
      prune_tmp=
      trap 'rm -f "$tmp" "$new_powercap_state" "$prune_tmp"' EXIT

      timestamp=$(date --iso-8601=seconds)
      sample_epoch_ns=$(date +%s%N)
      host=$(tr -d '\n' < /proc/sys/kernel/hostname)

      load1=null
      load5=null
      load15=null
      running_tasks=null
      total_tasks=null
      if read -r load1 load5 load15 tasks _ < /proc/loadavg; then
        running_tasks="''${tasks%/*}"
        total_tasks="''${tasks#*/}"
      fi

      uptime_seconds=null
      idle_seconds=null
      if read -r uptime_seconds idle_seconds < /proc/uptime; then
        :
      fi

      mem_total_kb=null
      mem_available_kb=null
      swap_total_kb=null
      swap_free_kb=null
      dirty_kb=null
      writeback_kb=null
      while read -r key value _; do
        case "''${key%:}" in
          MemTotal) mem_total_kb="$value" ;;
          MemAvailable) mem_available_kb="$value" ;;
          SwapTotal) swap_total_kb="$value" ;;
          SwapFree) swap_free_kb="$value" ;;
          Dirty) dirty_kb="$value" ;;
          Writeback) writeback_kb="$value" ;;
        esac
      done < /proc/meminfo

      psi_cpu=$(read_multiline /proc/pressure/cpu)
      psi_memory=$(read_multiline /proc/pressure/memory)
      psi_io=$(read_multiline /proc/pressure/io)

      declare -A previous_powercap_energy
      declare -A previous_powercap_time
      if [ -r "$powercap_state_file" ]; then
        while IFS=$'\t' read -r cap_path cap_time cap_energy _cap_max; do
          if [ -n "''${cap_path:-}" ]; then
            previous_powercap_time["$cap_path"]="$cap_time"
            previous_powercap_energy["$cap_path"]="$cap_energy"
          fi
        done < "$powercap_state_file"
      fi

      {
        printf '{"timestamp":%s,"timestamp_ns":%s,"host":%s,"readings":[' \
          "$(json_string "$timestamp")" \
          "$(json_num_or_null "$sample_epoch_ns")" \
          "$(json_string "$host")"

        first=1
        first_metric=1
        shopt -s nullglob
        for hwmon in /sys/class/hwmon/hwmon*; do
          name=$(read_optional "$hwmon/name")
          chip=$(basename "$hwmon")

          for input in "$hwmon"/temp*_input; do
            value=$(read_optional "$input")
            if ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
              continue
            fi

            base="''${input%_input}"
            label=$(read_optional "''${base}_label")
            max=$(read_optional "''${base}_max")
            crit=$(read_optional "''${base}_crit")

            if [ "$first" -eq 1 ]; then
              first=0
            else
              printf ','
            fi

            printf '{"hwmon":%s,"name":%s,"sensor":%s,"label":%s,"millidegrees_c":%s,"max_millidegrees_c":%s,"crit_millidegrees_c":%s}' \
              "$(json_string "$chip")" \
              "$(json_string "$name")" \
              "$(json_string "$(basename "$input")")" \
              "$(json_string "$label")" \
              "$(json_num_or_null "$value")" \
              "$(json_num_or_null "$max")" \
              "$(json_num_or_null "$crit")"
          done
        done

        printf '],"metrics":['

        for hwmon in /sys/class/hwmon/hwmon*; do
          name=$(read_optional "$hwmon/name")
          chip=$(basename "$hwmon")

          for metric in \
            "$hwmon"/temp*_input \
            "$hwmon"/power*_input \
            "$hwmon"/power*_average \
            "$hwmon"/power*_cap \
            "$hwmon"/power*_cap_max \
            "$hwmon"/fan*_input \
            "$hwmon"/fan*_max \
            "$hwmon"/freq*_input \
            "$hwmon"/in*_input \
            "$hwmon"/pwm*; do
            if [ ! -f "$metric" ]; then
              continue
            fi

            value=$(read_optional "$metric")
            if ! is_integer "$value"; then
              continue
            fi

            sensor=$(basename "$metric")
            prefix="''${sensor%%_*}"
            label=$(read_optional "$hwmon/''${prefix}_label")
            emit_metric "$chip" "$name" "$sensor" "$label" "$(metric_kind "$sensor")" "$(metric_unit "$sensor")" "$value"
          done
        done

        printf '],"system":{"uptime_seconds":%s,"idle_seconds":%s,"loadavg":{"one":%s,"five":%s,"fifteen":%s,"running_tasks":%s,"total_tasks":%s},"memory":{"mem_total_kb":%s,"mem_available_kb":%s,"swap_total_kb":%s,"swap_free_kb":%s,"dirty_kb":%s,"writeback_kb":%s},"pressure":{"cpu":%s,"memory":%s,"io":%s},"powercap":[' \
          "$(json_decimal_or_null "$uptime_seconds")" \
          "$(json_decimal_or_null "$idle_seconds")" \
          "$(json_decimal_or_null "$load1")" \
          "$(json_decimal_or_null "$load5")" \
          "$(json_decimal_or_null "$load15")" \
          "$(json_num_or_null "$running_tasks")" \
          "$(json_num_or_null "$total_tasks")" \
          "$(json_num_or_null "$mem_total_kb")" \
          "$(json_num_or_null "$mem_available_kb")" \
          "$(json_num_or_null "$swap_total_kb")" \
          "$(json_num_or_null "$swap_free_kb")" \
          "$(json_num_or_null "$dirty_kb")" \
          "$(json_num_or_null "$writeback_kb")" \
          "$(json_string "$psi_cpu")" \
          "$(json_string "$psi_memory")" \
          "$(json_string "$psi_io")"

        first_powercap=1
        for powercap in /sys/class/powercap/*; do
          if [ ! -d "$powercap" ] || [ ! -r "$powercap/energy_uj" ]; then
            continue
          fi

          cap_name=$(read_optional "$powercap/name")
          energy_uj=$(read_optional "$powercap/energy_uj")
          max_energy_range_uj=$(read_optional "$powercap/max_energy_range_uj")
          if ! is_integer "$energy_uj"; then
            continue
          fi

          previous_energy="''${previous_powercap_energy[$powercap]:-}"
          previous_time="''${previous_powercap_time[$powercap]:-}"
          delta_uj=null
          delta_ns=null
          power_microwatts=null

          if is_integer "$previous_energy" && is_integer "$previous_time"; then
            delta_ns=$((sample_epoch_ns - previous_time))
            delta_uj=$((energy_uj - previous_energy))
            if [ "$delta_uj" -lt 0 ] && is_integer "$max_energy_range_uj"; then
              delta_uj=$((delta_uj + max_energy_range_uj))
            fi
            if [ "$delta_ns" -gt 0 ] && [ "$delta_uj" -ge 0 ]; then
              delta_us=$((delta_ns / 1000))
              if [ "$delta_us" -gt 0 ]; then
                power_microwatts=$((delta_uj * 1000000 / delta_us))
              fi
            fi
          fi

          printf '%s\t%s\t%s\t%s\n' "$powercap" "$sample_epoch_ns" "$energy_uj" "$max_energy_range_uj" >> "$new_powercap_state"

          if [ "$first_powercap" -eq 1 ]; then
            first_powercap=0
          else
            printf ','
          fi

          printf '{"path":%s,"name":%s,"energy_uj":%s,"max_energy_range_uj":%s,"delta_uj":%s,"delta_ns":%s,"power_microwatts":%s}' \
            "$(json_string "$powercap")" \
            "$(json_string "$cap_name")" \
            "$(json_num_or_null "$energy_uj")" \
            "$(json_num_or_null "$max_energy_range_uj")" \
            "$(json_num_or_null "$delta_uj")" \
            "$(json_num_or_null "$delta_ns")" \
            "$(json_num_or_null "$power_microwatts")"
        done

        printf ']}}\n'
      } > "$tmp"

      cat "$tmp" >> "$log_file"
      sync -f "$log_file" || true

      cat "$new_powercap_state" > "$powercap_state_file"
      sync -f "$powercap_state_file" || true

      if [[ "$retention_samples" =~ ^[0-9]+$ ]] && [ "$retention_samples" -gt 0 ]; then
        line_count=$(wc -l < "$log_file")
        if [ "$line_count" -gt "$retention_samples" ]; then
          prune_tmp=$(mktemp)
          tail -n "$retention_samples" "$log_file" > "$prune_tmp"
          cat "$prune_tmp" > "$log_file"
          sync -f "$log_file" || true
          rm -f "$prune_tmp"
          prune_tmp=
        fi
      fi
      cat "$tmp"
    '';
  };

  gemmaVoiceChatPython = pkgs.python3.withPackages (p: [ p.wyoming ]);
  gemmaVoiceChat = pkgs.writeShellApplication {
    name = "gemma-voice-chat";
    runtimeInputs = [ gemmaVoiceChatPython ];
    text = ''
      exec ${gemmaVoiceChatPython}/bin/python3 ${../../files/gemma-voice-chat.py} "$@"
    '';
  };
  gemmaCommsSystemPrompt = ''
    You are Gemma, Andy's local fallback assistant.

    Talking to Andy:
    Be brief, and use progressive disclosure: lead with the simple, accurate answer; keep the detail ready and let Andy pull more. Brevity is not dropping information, it is not front-loading all of it. You must actually have the depth when he drills in. Most replies are too long; match length to how hard the question is.

    - Plain English. ELI5 a hard idea only when it helps.
    - Use the correct precise term when it is the right word (quota, endpoint, polling, heuristic, persistent thread, one-shot vs stateful, KL, LoRA). Do not dumb down or avoid real terms.
    - One good example beats a paragraph.

    Avoid AI-slop. It is two patterns, not a fixed list:
    1. Jargon pile-up: stacking shorthand in one breath.
    2. Over-naming: coining a label for a concept instead of just saying it. "Fused vs seams" and "load-bearing" are tells, so are the buzzwords (delve, robust, seamless, leverage, synergy). The blocklist always lags, so judge by the pattern, not the word: if it reads like an AI reaching for a label, cut it and say the plain thing.

    The bar: the Q4-vs-BF16 exemplar at /home/andy/vault/02-areas/agents/comms-style-exemplar.md.
  '';
  gemmaLlamaUiConfig = pkgs.writeText "llama-ui-config.json" (builtins.toJSON {
    autoMicOnEmpty = true;
    systemMessage = gemmaCommsSystemPrompt;
  });
in

{
  imports = [
    ./hardware-configuration.nix
    "${self}/modules/nixos"
    "${self}/modules/home-manager"
    "${self}/modules/nixos/hardware/logitech.nix"
    "${self}/modules/nixos/hardware/amd-6900xt.nix"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It’s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

  networking.hostName = baseNameOf ./.;
  time.timeZone = "America/Los_Angeles";

  # Zram swap for OOM protection (compressed RAM-based swap)
  zramSwap = {
    enable = true;
    memoryPercent = 50; # Up to 15GB on 30GB RAM system
  };

  # Disk-backed swap as spillover for transient peaks (added 2026-04-25 after
  # OOM cascade: 3 concurrent Opus TUIs peaked at ~42GB demand; zram alone left
  # ~37GB usable budget). zram stays priority 5 (preferred); disk defaults lower.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 32 * 1024; # 32 GB in MiB
    }
  ];

  services.udev.packages = [
    pkgs.apio-udev-rules
    pkgs.keychron-udev-rules
  ];
  hardware.amdgpu.initrd.enable = true;

  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp-vulkan;
    openFirewall = false;
    settings = {
      host = "0.0.0.0";
      port = 8080;
      model = "/home/andy/models/gemma-4-12b-it-qat-q4_0/gemma-4-12b-it-qat-q4_0.gguf";
      mmproj = "/home/andy/models/gemma-4-12b-it-qat-q4_0/mmproj-gemma-4-12b-it-qat-q4_0.gguf";
      alias = "google/gemma-4-12B-it-qat-q4_0-gguf:Q4_0";
      ctx-size = 32768;
      n-gpu-layers = 99;
      parallel = 1;
      cache-type-k = "q8_0";
      cache-type-v = "q8_0";
      flash-attn = "auto";
      jinja = true;
      ui-config-file = gemmaLlamaUiConfig;
      reasoning = "off";
    };
  };

  # Expose the llama.cpp chat UI to Andy's tablet over Tailscale only.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    443
    8443
    8080
  ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts.gemma-tailnet = {
      listen = [
        {
          addr = "127.0.0.1";
          port = 18080;
        }
      ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:8080";
        proxyWebsockets = true;
        extraConfig = ''
          client_max_body_size 64m;
          proxy_buffering off;
          proxy_read_timeout 300s;
        '';
      };
      locations."/voice/" = {
        proxyPass = "http://127.0.0.1:18082/";
        extraConfig = ''
          client_max_body_size 64m;
          proxy_buffering off;
          proxy_read_timeout 300s;
        '';
      };
    };
    virtualHosts.fakebook-tailnet = {
      listen = [
        {
          addr = "127.0.0.1";
          port = 18084;
        }
      ];
      root = "${inputs.fakebook.packages.x86_64-linux.web}";
      extraConfig = ''
        index index.html;
      '';
      locations."/" = {
        tryFiles = "$uri $uri/ /index.html";
      };
    };
  };

  systemd.services.gemma-voice-chat = {
    description = "Reliable Gemma voice chat bridge through Wyoming STT";
    after = [
      "network.target"
      "wyoming-faster-whisper-stt.service"
      "llama-cpp.service"
    ];
    wants = [
      "wyoming-faster-whisper-stt.service"
      "llama-cpp.service"
    ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      GEMMA_VOICE_HOST = "127.0.0.1";
      GEMMA_VOICE_PORT = "18082";
      GEMMA_VOICE_WYOMING_HOST = "127.0.0.1";
      GEMMA_VOICE_WYOMING_PORT = "10300";
      GEMMA_VOICE_LLAMA_BASE_URL = "http://127.0.0.1:8080/v1";
      GEMMA_VOICE_LLAMA_MODEL = "google/gemma-4-12B-it-qat-q4_0-gguf:Q4_0";
      GEMMA_VOICE_SYSTEM_PROMPT = gemmaCommsSystemPrompt;
    };
    serviceConfig = {
      ExecStart = "${gemmaVoiceChat}/bin/gemma-voice-chat";
      DynamicUser = true;
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };

  systemd.services.tailscale-serve-gemma = {
    description = "Expose Gemma chat over Tailscale HTTPS";
    after = [
      "tailscaled.service"
      "nginx.service"
    ];
    wants = [
      "tailscaled.service"
      "nginx.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.coreutils
      pkgs.tailscale
    ];
    script = ''
      set -euo pipefail

      for _ in $(seq 1 30); do
        if tailscale status --self >/dev/null 2>&1; then
          break
        fi
        sleep 1
      done

      if ! timeout 20s tailscale serve --bg --yes --https=443 127.0.0.1:18080; then
        cat >&2 <<'EOF'
Tailscale Serve is not enabled or could not be configured automatically.
Enable Serve in the tailnet admin flow, then run:
  sudo systemctl start tailscale-serve-gemma.service
EOF
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };

  systemd.services.tailscale-serve-fakebook = {
    description = "Expose Fakebook over Tailscale HTTPS";
    after = [
      "tailscaled.service"
      "nginx.service"
    ];
    wants = [
      "tailscaled.service"
      "nginx.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.coreutils
      pkgs.tailscale
    ];
    script = ''
      set -euo pipefail

      for _ in $(seq 1 30); do
        if tailscale status --self >/dev/null 2>&1; then
          break
        fi
        sleep 1
      done

      if ! timeout 20s tailscale serve --bg --yes --https=8443 127.0.0.1:18084; then
        cat >&2 <<'EOF'
Tailscale Serve is not enabled or could not be configured automatically.
Enable Serve in the tailnet admin flow, then run:
  sudo systemctl start tailscale-serve-fakebook.service
EOF
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
    };
  };

  systemd.services.llama-cpp.serviceConfig = {
    # The trial model is a manually downloaded multi-GB artifact under Andy's
    # home, outside rebuild-time Nix inputs.
    DynamicUser = lib.mkForce false;
    User = "andy";
    Group = "users";
    SupplementaryGroups = [
      "render"
      "video"
    ];
    ProtectHome = lib.mkForce "read-only";
    PrivateUsers = lib.mkForce false;
  };

  environment.systemPackages = [
    pkgs.lm_sensors
    hwmonTemperatureLog
  ];

  hardware.rasdaemon.enable = true;

  boot.kernelModules = [ "nct6683" ];
  boot.extraModprobeConfig = ''
    # Expose MSI MAG X870 TOMAHAWK WIFI fan/pump tach sensors.
    options nct6683 force=1
  '';

  boot.kernelParams = [
    # Let pstore-capable backends keep kmsg breadcrumbs when the kernel gets
    # far enough to dump them before a reset. systemd-pstore is already enabled
    # and archives /sys/fs/pstore on the next boot when entries exist.
    "printk.always_kmsg_dump=1"
  ];

  systemd.services.hwmon-temperature-log = {
    description = "Log hardware sensor and pressure snapshot";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${hwmonTemperatureLog}/bin/hwmon-temperature-log";
      LogsDirectory = "hwmon-temperature";
      Environment = "HWMON_TEMPERATURE_RETENTION_SAMPLES=1440";
    };
  };

  systemd.timers.hwmon-temperature-log = {
    description = "Log hardware sensors every 5 seconds";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "5s";
      AccuracySec = "1s";
    };
  };
}
