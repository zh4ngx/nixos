{ pkgs, ... }:

{
  hardware.openrazer.enable = true;
  hardware.openrazer.users = [ "andy" ];

  home-manager.users.andy = {
    home.packages = [ pkgs.polychromatic ];
  };
}
