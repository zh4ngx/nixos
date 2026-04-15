{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    antigravity-nix = {
      url = "github:jacopone/antigravity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code.url = "github:sadjow/claude-code-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }@inputs:
    let
      # Overlay to pin rio to 0.3.10 (clipboard crash fix)
      # TODO: remove when nixpkgs has rio >= 0.3.2
      rio-overlay = final: prev: {
        rio = prev.rio.overrideAttrs (finalAttrs: prevAttrs: rec {
          version = "0.3.10";
          src = prev.fetchFromGitHub {
            owner = "raphamorim";
            repo = "rio";
            tag = "v${finalAttrs.version}";
            hash = "sha256-5WXYyC/+apZHI3/A48WRucmRvtuoQmGze0XmvQ8wxlY=";
          };
          cargoDeps = prev.rustPlatform.importCargoLock {
            lockFile = finalAttrs.src + "/Cargo.lock";
          };
        });
      };

      # Overlay to pin llama.cpp to a version with Gemma 4 support
      # TODO: remove when nixpkgs has llama-cpp >= b8693
      llama-cpp-overlay = final: prev: {
        llama-cpp = prev.llama-cpp.overrideAttrs (finalAttrs: prevAttrs: {
          version = "8693";
          src = prev.fetchFromGitHub {
            owner = "ggml-org";
            repo = "llama.cpp";
            tag = "b${finalAttrs.version}";
            hash = "sha256-L1Rkg2T7nQCfEhou4eNJxtCLHXwM3JPMBjuGcWVnJ6g=";
            leaveDotGit = true;
            postFetch = ''
              git -C "$out" rev-parse --short HEAD > $out/COMMIT
              find "$out" -name .git -print0 | xargs -0 rm -rf
            '';
          };
          npmDepsHash = "sha256-eeftjKt0FuS0Dybez+Iz9VTVMA4/oQVh+3VoIqvhVMw=";
          # b8693 no longer ships this file; override postPatch
          postPatch = ''
            rm -f tools/server/public/index.html.gz
          '';
        });
      };

      mkHost =
        hostname:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit self inputs; };
          modules = [
            { nixpkgs.overlays = [ rio-overlay llama-cpp-overlay ]; }
            ./hosts/${hostname}
          ];
        };
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs [
        "MS-7C95"
        "MS-7E51"
        "B550"
      ] (name: mkHost name);
    };
}
