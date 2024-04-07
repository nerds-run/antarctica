# Antartica

NixOS-based development environment for shared development in NerdsRuns VMs!

This should setup a NixOS VM with a bunch of container things, VM things, and general development-related things that you can use for developing things remotely.

```shell
git clone github.com/nerds-run/antarctica
cd antartica
task disk # this will setup your disk with impermanence 
task install # installs nixos with UEFI

# Whenever you want to update
task rebuild # rebases your current config over to the new one
```
