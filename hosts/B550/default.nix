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

  networking.hostName = "B550"; # Define your hostname.
  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  services.udev.packages = with pkgs; [ apio-udev-rules ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", DRIVER=="pcieport", ATTR{power/wakeup}="disabled"
  '';

  hardware.openrazer = {
    enable = true;
    users = [ "andy" ];
  };
}
