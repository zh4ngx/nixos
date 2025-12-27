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
    inputs.home-manager.nixosModules.home-manager
    "${self}/modules/home-manager"
  ];

  networking.hostName = "MS-7C95"; # Define your hostname.
  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  services.udev.packages = with pkgs; [ apio-udev-rules ];

  hardware.logitech.wireless.enable = true;
}
