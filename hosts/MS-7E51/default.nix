{
  pkgs,
  self,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    "${self}/modules/nixos"
    "${self}/modules/home-manager"
    "${self}/modules/nixos/hardware/logitech.nix"
  ];

  networking.hostName = baseNameOf ./.;
  time.timeZone = "America/Los_Angeles";

  services.udev.packages = with pkgs; [ apio-udev-rules ];
  hardware.amdgpu.initrd.enable = true;
}
