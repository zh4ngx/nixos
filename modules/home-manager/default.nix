{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.andy = import ./home.nix;
  };
}
