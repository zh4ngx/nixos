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
cat ~/.ssh/id_ed25519.pub # Go to Settings and add key
```
