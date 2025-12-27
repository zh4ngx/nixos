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
    "${self}/modules/nixos/hardware/razer.nix"
  ];

  networking.hostName = baseNameOf ./.;
  time.timeZone = "America/Los_Angeles";
  hardware.amdgpu.initrd.enable = true;

  services.udev.packages = with pkgs; [ apio-udev-rules ];
}
