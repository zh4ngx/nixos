# NixOS new machine setup

Identify which host you are setting up and replace <hostname> with the appropriate hostname.

```fish
# Set up nix flake
cd ~
nix run nixpkgs#git clone https://github.com/zh4ngx/nixos.git nixos-config --extra-experimental-features nix-command --extra-experimental-features flakes
# insert script to run the rest of this
cd nixos-config/hosts
# copy an existing host config - this could be scripted
cp -a hosts/B550 hosts/<hostname>
cd hosts/<hostname>
cp /etc/nixos/hardware-configuration.nix .
# edit flake.nix with this new host
# finally switch to this flake 
sudo nixos-rebuild switch --flake .#<hostname>

# Set up github
ssh-keygen -t ed25519 -C "1329212+zhangbanger@users.noreply.github.com"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub # copy this key
open https://github.com/settings/ssh/new # create a new key and paste here
```

# Periodic & manual updates

The GitHub workflow `update-flake-lock.yml` handles updating the flake lock
file. Update the cron schedule as needed. Lock-file updates may be auto-merged,
but NixOS host upgrades are manual: `system.autoUpgrade` and
`nixos-upgrade.timer` should stay disabled unless Andy explicitly changes that
policy.

After first time setup, manually activate changes with
`sudo nixos-rebuild switch --flake .` from the repo root. Keep `nh clean` /
garbage collection automation enabled; it is separate from host upgrades.
