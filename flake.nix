{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, home-manager, ... }@attrs:
    {
      nixosConfigurations = {
        MS-7C95 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = attrs;
          modules = [ ./hosts/MS-7C95/configuration.nix ];
        };
        B550 = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = attrs;
          modules = [ ./hosts/B550/configuration.nix ];
        };
        iso = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = attrs;
          modules = [
            (
              { modulesPath, ... }:
              {
                imports = [
                  (modulesPath + "/installer/cd-dvd/installation-cd-graphical-base.nix")
                  ./modules/nixos
                  home-manager.nixosModules.home-manager
                  ./modules/home-manager
                ];
              }
            )
          ];
        };
      };
    };
}
