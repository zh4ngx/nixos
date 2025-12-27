# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, home-manager, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/nixos
    home-manager.nixosModules.home-manager
    ../../modules/home-manager
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
