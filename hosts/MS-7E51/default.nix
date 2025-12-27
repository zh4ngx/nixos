{
  pkgs,
  self,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    "${self}/modules/nixos"
    "${self}/modules/nixos/hardware/logitech.nix"
    inputs.home-manager.nixosModules.home-manager
    "${self}/modules/home-manager"
  ];

  networking.hostName = "MS-7E51"; # Define your hostname.
  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  services.udev.packages = with pkgs; [ apio-udev-rules ];
}
