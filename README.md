<div align="center">
    <img src="./assets/antarctica_logo_temp.png" alt="antarctica logo" width="200rem"/>
    <h1 style="font-size: 48px; margin-left: 0.1em; text-align: center;">Antarctica</h1>
</div>

NixOS-based development environment for shared development in NerdsRuns VMs!

This should setup a NixOS VM with a bunch of container things, VM things, and general development-related things that you can use for developing things remotely.i

# Manual Intervation

You do need to make some manual adjustements before and after rebooting into the system:

## Before Deploying

- You need to put your SSH public keys onto the option `users.users.root.openssh.authorizedKeys.keys`
- Set up your disk with [disko](https://github.com/nix-community/disko) (Put the device string where the disko config is called) `/dev/sda -> /dev/whatever/you/need`
- Make secrets for specified files in `secrets/secrets.nix` with the [agenix CLI](https://github.com/ryantm/agenix?tab=readme-ov-file#agenix-cli-reference), all required secrets should be specified in the `secrets.nix` file itself

## After deploying

- Make sure to change the [agenix signing keys](https://github.com/ryantm/agenix?tab=readme-ov-file#age-module-reference) in `/var/lib/agenix/sshd/*` to the ones you used for creating secrets

# Automatic Deployment

You can automatically deploy this system by using [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) on any remote host with SSH, it uses a fancy kexec thing to install it in whatever system you are SSHing to.

## Cloning this repo

```shell
git clone (this repo)
task deploy:test # For testing if the VM even works
task deploy:remote # Make sure to specify your custom arguments, itll fail if you do not have that
```

## Raw command

```shell
nix run github:nix-community/nixos-anywhere -- --flake FLAKE_URL#antarctica USER@HOST
```

# Manual Deployment

```shell
git clone github.com/nerds-run/antarctica
cd antartica
task manual:disk # this will setup your disk with impermanence 
task manual:install # installs nixos with UEFI

# Include your ssh key on /var/lib/agenix/sshd/ssh_host_ed25519_key with chmod 600!!
task rebuild:local # rebases your current config over to the new one
```
