{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixos-hardware,
      ...
    }@inputs:
    let
      mkHost =
        hostname:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit self inputs; };
          modules = [
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
