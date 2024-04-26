```
nix run nixpkgs#git clone https://github.com/zh4ngx/nixos.git nix --extra-experimental-features nix-command --extra-experimental-features flakes
cd nix
sudo ln -f flake.lock /etc/nixos/
sudo ln -f flake.nix /etc/nixos/
sudo ln -f home.nix /etc/nixos/
sudo ln -f configuration.nix /etc/nixos/
```
