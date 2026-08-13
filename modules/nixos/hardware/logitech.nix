{ pkgs, ... }:

{
  # System-level drivers and udev rules
  hardware.logitech.wireless = {
    enable = true;
  };
  programs.solaar.enable = true;

  # User-level background service for DPI persistence
  systemd.user.services.solaar = {
    description = "Solaar background manager for MX Vertical DPI";
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.solaar}/bin/solaar --window=hide";
      Restart = "on-failure";
    };
  };
}
