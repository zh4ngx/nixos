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
    "${self}/modules/nixos/hardware/amd-6900xt.nix"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

  networking.hostName = baseNameOf ./.;
  time.timeZone = "America/Los_Angeles";

  services.udev.packages = [
    pkgs.apio-udev-rules
    pkgs.keychron-udev-rules
  ];
  hardware.amdgpu.initrd.enable = true;
}
