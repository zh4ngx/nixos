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
    "${self}/modules/home-manager"
    "${self}/modules/nixos/hardware/razer.nix"

    inputs.nixos-hardware.nixosModules.gigabyte-b550
  ];

  networking.hostName = baseNameOf ./.;
  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  services.udev.packages = with pkgs; [ apio-udev-rules ];
}
