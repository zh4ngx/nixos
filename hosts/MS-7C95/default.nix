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

  networking.hostName = "MS-7C95"; # Define your hostname.
  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  services.udev.packages = with pkgs; [ apio-udev-rules ];

  hardware.logitech.wireless.enable = true;
}
