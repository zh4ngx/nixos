{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Helper to build Obsidian plugins from GitHub release assets
  # Plugins must provide: main.js, manifest.json, styles.css (optional)
  buildObsidianPlugin =
    {
      pluginId,
      owner,
      repo,
      version,
      mainJsHash,
      manifestHash,
      stylesHash,
    }:
    let
      baseUrl = "https://github.com/${owner}/${repo}/releases/download/${version}";
      mainJs = pkgs.fetchurl {
        url = "${baseUrl}/main.js";
        hash = mainJsHash;
      };
      manifest = pkgs.fetchurl {
        url = "${baseUrl}/manifest.json";
        hash = manifestHash;
      };
      styles = pkgs.fetchurl {
        url = "${baseUrl}/styles.css";
        hash = stylesHash;
      };
    in
    pkgs.stdenv.mkDerivation {
      pname = "obsidian-plugin-${pluginId}";
      inherit version;

      # Skip default phases - we just need install
      phases = [ "installPhase" ];

      installPhase = ''
        mkdir -p $out
        cp ${mainJs} $out/main.js
        cp ${manifest} $out/manifest.json
        cp ${styles} $out/styles.css 2>/dev/null || true
      '';
    };

in
{
  programs.obsidian = {
    enable = true;

    vaults.Notes = {
      target = "Notes";
      settings.communityPlugins = [
        # Dataview - complex data views for notes
        (buildObsidianPlugin {
          pluginId = "dataview";
          owner = "blacksmithgu";
          repo = "obsidian-dataview";
          version = "0.5.64";
          mainJsHash = "sha256-YKTRDXDyhujCUI2S2ItJLO2c3APMyJKMByw8+SDSklU=";
          manifestHash = "sha256-+5Bpq0hF7qIWBKUGo/P5alRiGHIusY/FKqHgfjKfu2E=";
          stylesHash = "sha256-z8T/vXpQffcNan0khWGks5v2y1RbuEeKWoCsju4YxGw=";
        })
        # Media DB - query APIs for movies, games, music, etc.
        (buildObsidianPlugin {
          pluginId = "obsidian-media-db-plugin";
          owner = "mProjectsCode";
          repo = "obsidian-media-db-plugin";
          version = "0.8.0";
          mainJsHash = "sha256-dKlW7bdNlj/hU/PMttXSWDqPIRHcKREcor6GD17TfEY=";
          manifestHash = "sha256-Hx7+OIHZVlwh8roeZbdBdffOqivbDmjoquq7/uLW+fY=";
          stylesHash = "sha256-8AzOMvISGCnRiT83oA7xrHYy05gF6wBDEGjaz0FqAtQ=";
        })
      ];
    };
  };
}
