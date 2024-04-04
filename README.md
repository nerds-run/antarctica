# Antartica

NixOS-based development environment for shared development in NerdsRuns VMs!

This should setup a NixOS VM with a bunch of container things, VM things, and general development-related things that you can use for developing things remotely.

```
git clone github.com/nerds-run/antarctica
sudo nix run github:nix-community/disko -- --mode zap_create_mount antarctica/disko-config.nix
nixos-install --flake github:nerds-run/antarctica# --root /mnt
```
