# NixOS new machine setup

Identify which host you are setting up and replace <hostname> with the appropriate hostname.

```fish
# Set up nix flake
cd ~
nix run nixpkgs#git clone https://github.com/zh4ngx/nixos.git nixos-config --extra-experimental-features nix-command --extra-experimental-features flakes
cd nixos-config
sudo nixos-rebuild switch --flake .#<hostname> --extra-experimental-features nix-command --extra-experimental-features flakes

# Set up github
ssh-keygen -t ed25519 -C "1329212+zhangbanger@users.noreply.github.com"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub # copy this key
open https://github.com/settings/ssh/new # create a new key and paste here
```

# Update flake

The github workflow update-flake-lock handles updating the flake lock file. Update the cron schedule as needed.

```fish
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#<hostname>
```
