# NixOS new machine setup

```fish
# Set up nix flake
nix run nixpkgs#git clone https://github.com/zh4ngx/nixos.git nix --extra-experimental-features nix-command --extra-experimental-features flakes
cd nix
sudo ln -f flake.lock /etc/nixos/
sudo ln -f flake.nix /etc/nixos/
sudo ln -f home.nix /etc/nixos/
sudo ln -f configuration.nix /etc/nixos/

# Set up github
ssh-keygen -t ed25519 -C "1329212+zhangbanger@users.noreply.github.com"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub # copy this key
open https://github.com/settings/ssh/new # create a new key and paste here
```

# Update flake

```fish
cd nix
nix flake update
sudo ln -f flake.lock /etc/nixos/
diff /etc/nixos/ flake.lock # double check
sudo nixos-rebuild boot # evaluate and build new derivation for next boot
```
