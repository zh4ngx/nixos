{
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
    ];
    text = ''
      set -euo pipefail

      log_dir="''${HWMON_TEMPERATURE_LOG_DIR:-/var/log/hwmon-temperature}"
      log_file="$log_dir/temperature.jsonl"
      retention_samples="''${HWMON_TEMPERATURE_RETENTION_SAMPLES:-1440}"

      json_string() {
        jq -Rn --arg v "$1" '$v'
      }

      json_num_or_null() {
        if [[ "$1" =~ ^-?[0-9]+$ ]]; then
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

      mkdir -p "$log_dir"
      tmp=$(mktemp)
      prune_tmp=
      trap 'rm -f "$tmp" "$prune_tmp"' EXIT

      timestamp=$(date --iso-8601=seconds)
      host=$(tr -d '\n' < /proc/sys/kernel/hostname)

      {
        printf '{"timestamp":%s,"host":%s,"readings":[' \
          "$(json_string "$timestamp")" \
          "$(json_string "$host")"

        first=1
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

        printf ']}\n'
      } > "$tmp"

      cat "$tmp" >> "$log_file"
      if [[ "$retention_samples" =~ ^[0-9]+$ ]] && [ "$retention_samples" -gt 0 ]; then
        line_count=$(wc -l < "$log_file")
        if [ "$line_count" -gt "$retention_samples" ]; then
          prune_tmp=$(mktemp)
          tail -n "$retention_samples" "$log_file" > "$prune_tmp"
          cat "$prune_tmp" > "$log_file"
          rm -f "$prune_tmp"
          prune_tmp=
        fi
      fi
      cat "$tmp"
    '';
  };
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

  environment.systemPackages = [
    pkgs.lm_sensors
    hwmonTemperatureLog
  ];

  hardware.rasdaemon.enable = true;

  systemd.services.hwmon-temperature-log = {
    description = "Log hardware temperature sensor snapshot";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${hwmonTemperatureLog}/bin/hwmon-temperature-log";
      LogsDirectory = "hwmon-temperature";
      Environment = "HWMON_TEMPERATURE_RETENTION_SAMPLES=1440";
    };
  };

  systemd.timers.hwmon-temperature-log = {
    description = "Log hardware temperature sensors every 5 seconds";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "5s";
      AccuracySec = "1s";
    };
  };
}
