# Antarctica NixOS-to-Ansible Migration Inventory

Complete inventory of the Antarctica NixOS server, extracted from all `.nix` configuration files. This document serves as the authoritative reference for building Ansible roles and Pulumi infrastructure.

---

## Migration Decisions

| Decision | Detail |
|---|---|
| Provider | Proxmox (Pulumi with `pulumi-proxmoxve`) |
| Target OS | Debian (stable) |
| Container runtime | Podman (Quadlet `.container` files for every service) |
| PostgreSQL | Podman Quadlet container (not native) |
| Reverse proxy / TLS | Caddy as native systemd service, auto-HTTPS via Let's Encrypt |
| Drop: Hydra | NixOS-specific build system, no replacement needed |
| Drop: System76 Scheduler | NixOS-specific, no Debian equivalent |
| Drop: Impermanence | Standard persistent Debian server; Ansible reconvergence replaces ephemeral root |
| Drop: persist-retro | Not needed without impermanence |
| Replace: home-manager | Ansible `dev_tools` role handles package installation and dotfiles |
| Replace: rust-motd | Simple `/etc/motd` or dynamic-motd |
| Replace: Woodpecker exec agent (Nix) | Docker/Podman-based agent instead |
| Replace: Nix GC / auto-upgrade | `apt unattended-upgrades` |
| Replace: nix-direnv | `direnv` from apt/binary, no Nix integration |
| Keep | Docker Registry, SSHX, Cockpit, OpenVSCode Server, Gitea Actions runner |
| Dev tools | Full 50+ package replication via Ansible |

---

## Services

| # | Service | Source File | Port(s) | Domain | Backend / DB | Container? | Migration Notes |
|---|---|---|---|---|---|---|---|
| 1 | Forgejo | `nixos/modules/forgejo.nix` | 3030 (HTTP) | forgejo.dev.nerds.run | SQLite (default) | Podman Quadlet | LFS enabled; dumps disabled; `DEFAULT_ACTIONS_URL=https://github.com`; webhook allowed hosts: `external,loopback,woodpecker.dev.nerds.run` |
| 2 | Gitea Actions Runner | `nixos/modules/forgejo.nix` | -- | -- | -- | Podman Quadlet | Runner name: `antarctica`; capacity: 5; timeout: 45m; privileged; volumes: `["*"]`; labels: debian-latest, ubuntu-latest, ubuntu-22.04, ubuntu-20.04, ubuntu-18.04 (all `catthehacker/ubuntu:act-latest`); token from `/run/secrets/action-runner.env`; podman socket: `/var/run/podman/podman.sock` |
| 3 | Woodpecker Server | `nixos/modules/woodpecker/server.nix` | 3040 (HTTP), 3041 (gRPC) | woodpecker.dev.nerds.run | PostgreSQL (`postgres:///woodpecker?host=/run/postgresql`) | Podman Quadlet | `WOODPECKER_OPEN=true`; admins: `abanna,tulilirockz`; Gitea integration enabled pointing at Forgejo ROOT_URL; log level: debug; runs as user `woodpecker`; secrets from `/run/secrets/woodpecker.env` |
| 4 | Woodpecker Agent (Docker) | `nixos/modules/woodpecker/agent-docker.nix` | -- | -- | -- | Podman Quadlet | Backend: docker; max workflows: 10; filter: `type=docker`; connects to `woodpecker.dev.nerds.run:3041`; runs as root; binds docker socket; health check disabled; `restartIfChanged=false` |
| 5 | Woodpecker Agent (Exec) | `nixos/modules/woodpecker/agent-exec.nix` | -- | -- | -- | **Replace** | Backend: local; max workflows: 10; filter: `type=exec`; `NIX_REMOTE=daemon`; path includes nix tooling. **NixOS-specific -- replace with Docker/Podman-based agent in Debian.** |
| 6 | PostgreSQL | enabled by woodpecker `server.nix` | Unix socket | -- | -- | Podman Quadlet | Database: `woodpecker`; user: `woodpecker` (superuser); socket at `/run/postgresql` |
| 7 | OpenSSH | `configuration/antarctica.nix` | 22 | -- | -- | Native systemd | Keyboard auth: disabled; password auth: true (overridden by `AuthenticationMethods=publickey`); SFTP: disabled; TCP forwarding: yes; X11/agent/stream-local forwarding: disabled; host keys: ed25519 + RSA-4096 at `/var/lib/agenix/sshd/` |
| 8 | Docker Registry | `configuration/antarctica.nix` | 5000 (default) | -- | Filesystem | Podman Quadlet | Delete enabled; GC enabled; storage persisted via impermanence |
| 9 | Cockpit | `configuration/antarctica.nix` | 9090 (default) | -- | -- | Native systemd | Default config; firewall opened |
| 10 | OpenVSCode Server | `configuration/antarctica.nix` | 3000 (default) | -- | -- | Podman Quadlet | Host: `0.0.0.0`; no connection token (open access); extra packages: neovim + full LSP stack |
| 11 | SSHX | `nixos/modules/sshx.nix` | 8051 (HTTP), 5090 (Redis) | -- | Redis (local) | Podman Quadlet | Listen: `0.0.0.0`; Redis URL: `redis://forgejo.dev.nerds.run:5090`; systemd type: exec, restart on-failure |
| 12 | Docker | `virtual.nix` | -- | -- | -- | N/A | Insecure registries: fqdn, `forgejo.dev.nerds.run:3030`, `localhost:3030` |
| 13 | Podman | `virtual.nix` | -- | -- | -- | N/A | Auto-prune enabled; docker socket compat + docker compat (when Docker disabled); DNS enabled |
| 14 | Libvirtd | `virtual.nix` | -- | -- | -- | Native systemd | KVM/QEMU virtualization |
| 15 | QEMU Guest Agent | `configuration/antarctica.nix` | -- | -- | -- | Native systemd | Enabled for Proxmox integration |
| 16 | Caddy (new) | -- | 80, 443 | *.dev.nerds.run | -- | **Native systemd** | Not in NixOS config. New addition for Debian: reverse proxy all services, auto-HTTPS via Let's Encrypt |

---

## Packages

### System-level Packages (from `configuration/antarctica.nix`)

| Package | Purpose | Migration |
|---|---|---|
| nushell | Default shell for all users | apt / GitHub release |
| linuxPackages_latest | Latest kernel | Debian default kernel (or backports) |
| figlet | MOTD banner | apt |
| lolcat | MOTD banner (colorized) | apt / gem |
| neovim | Editor for openvscode-server | apt |

### LSP / Language Server Packages (system-level, for OpenVSCode Server)

| Package | Language | Migration |
|---|---|---|
| python-lsp-server (pylsp) | Python | pip / apt |
| yaml-language-server | YAML | npm |
| tailwindcss-language-server | TailwindCSS | npm |
| clang-tools | C/C++ | apt |
| nil | Nix | Drop (Nix-specific) |
| zls | Zig | GitHub release |
| marksman | Markdown | GitHub release |
| rust-analyzer | Rust | rustup |
| gopls | Go | go install |
| ruff | Python linter | pip |
| docker-ls | Dockerfiles | GitHub release |
| vscode-langservers-extracted | HTML/CSS/JSON | npm |
| clojure-lsp | Clojure | GitHub release |
| dockerfile-language-server-nodejs | Dockerfiles | npm |

### Home-Manager Dev Tools (`devtools.nix` -- installed for "antarctica" user)

| Package | Migration |
|---|---|
| waypipe | apt |
| unzip | apt |
| git | apt |
| ollama | official install script |
| buildah | apt |
| gh (GitHub CLI) | apt / GitHub release |
| glab (GitLab CLI) | apt / GitHub release |
| fd | apt |
| ripgrep | apt |
| sbctl | GitHub release |
| podman-compose | pip / apt |
| tldr | npm / pip |
| jq | apt |
| yq | GitHub release |
| scc | GitHub release |
| just | GitHub release / cargo |
| iotop | apt |
| nix-prefetch-git | Drop (Nix-specific) |
| pre-commit | pip |
| fh (FlakeHub) | Drop (Nix-specific) |
| trashy | cargo |
| android-tools | apt |
| wormhole-rs | cargo |
| lldb | apt |
| gdb | apt |
| bubblewrap | apt |
| cage | apt |
| distrobox | GitHub release |
| cosign | GitHub release |
| jsonnet | apt / GitHub release |
| kubernetes-helm | official install script |
| kind | GitHub release |
| go-task | GitHub release |
| kubectl | official install script |
| talosctl | GitHub release |
| jujutsu | cargo / GitHub release |
| melange | GitHub release |
| dive | GitHub release |
| earthly | official install script |
| poetry | pip / official installer |
| gdu | apt / GitHub release |
| asciinema | apt / pip |
| maturin | pip / cargo |
| bun | official install script |
| act | GitHub release |
| wasmer | official install script |

### Home-Manager CLI Tools (`clitools.nix`)

| Package / Program | Config | Migration |
|---|---|---|
| fzf | home-manager program | apt + dotfile |
| atuin | home-manager program | official install script + dotfile |
| carapace | home-manager program | GitHub release + dotfile |
| tmux | home-manager program; plugins: tmux-fzf, tmux-thumbs, catppuccin, sensible, vim-tmux-navigator | apt + TPM plugin manager + dotfile |
| nushell | home-manager program | apt / GitHub release + dotfile |
| zoxide | home-manager program | apt + dotfile |

### Home-Manager Configured Programs (`devtools.nix`)

| Program | Config Details | Migration |
|---|---|---|
| helix | Default editor; theme: `boo_berry`; full LSP stack configured | GitHub release + `~/.config/helix/` dotfiles |
| yazi | File manager | GitHub release + dotfile |
| zellij | Terminal multiplexer | GitHub release + dotfile |
| direnv | nix-direnv + nushell/bash integration | apt + dotfile (no nix-direnv) |
| git | `enable=false`; has signing config + excludes file | apt + `~/.gitconfig` dotfile |

---

## Users

| User | Type | Shell | Groups | SSH Keys | Initial Password |
|---|---|---|---|---|---|
| root | system | default | -- | tulip, abanna | -- |
| antarctica | normal | nushell | wheel, libvirtd, qemu | tulip, abanna | `antarctica` |
| abanna | normal | nushell | wheel, libvirtd, qemu | abanna | `antarctica` |
| tulili | normal | nushell | wheel, libvirtd, qemu | tulip | `antarctica` |

### SSH Public Keys

| Name | Key |
|---|---|
| tulip | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEGQB1RVrTnUl5JDIs19lzIJVGi60yuXB7zYCcwN/XxZ tulili@studio` |
| abanna | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB0Xc+SiOJZ9r3WR+UqeZgOaRYl3ZOTCpcbVfvIHJu3t abanna@pop-os` |

> **Note:** `mutableUsers = false` in NixOS. In Debian, set passwords with Ansible vault and manage with `ansible.builtin.user`.

---

## Secrets

All secrets are encrypted with agenix using Antarctica's ed25519 host key:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMFXZQVV6Que5yV1ToypCfUmcF+eXLRvMKRKwcLZIO2P root@antarctica
```

| Secret File | Contents | Consumer | Migration |
|---|---|---|---|
| `woodpecker.age` | `WOODPECKER_AGENT_SECRET`, `WOODPECKER_GITEA_CLIENT`, `WOODPECKER_GITEA_SECRET` | Woodpecker server + agents | Ansible Vault encrypted vars, injected as Podman Quadlet env file |
| `action-runner.age` | `TOKEN` (Gitea Actions runner registration token) | Gitea Actions runner | Ansible Vault encrypted vars, injected as Podman Quadlet env file |

---

## Disk Layout (from `nixos/disko-config.nix`)

3 physical disks, combined into a single LVM volume group:

| Disk | Partition | Size | Filesystem | Mount | Notes |
|---|---|---|---|---|---|
| /dev/sda | sda1 (ESP) | 1 GB | vfat | /boot | EFI System Partition |
| /dev/sda | sda2 (LVM PV) | remainder | LVM PV | -- | Member of `root_vg` |
| /dev/sdb | sdb1 (LVM PV) | entire disk | LVM PV | -- | Member of `root_vg` |
| /dev/sdc | sdc1 (LVM PV) | entire disk | LVM PV | -- | Member of `root_vg` |
| root_vg | root (LV) | 100%FREE | btrfs | / | Subvolumes: `/` (root), `/persist` (noatime), `/nix` (noatime) |

> **Migration:** Pulumi will provision the Proxmox VM with appropriate disk(s). The btrfs subvolume layout and impermanence scheme are NixOS-specific and will not be replicated. Use a standard ext4 or btrfs root filesystem.

---

## Network

| Setting | Value | Migration |
|---|---|---|
| Hostname | `antarctica` | Ansible `hostname` |
| Network manager | NetworkManager | Debian default (NetworkManager or systemd-networkd) |
| Firewall | **DISABLED** (`mkForce false`) | `ufw` or `nftables` -- consider enabling |
| NFTables | **DISABLED** | -- |
| DHCP | All interfaces (from `hardware-configuration.nix`) | Proxmox VM network config via Pulumi |

### Firewall Ports (opened in NixOS config, but firewall is disabled)

| Port | Protocol | Service |
|---|---|---|
| 22 | TCP | OpenSSH |
| 3030 | TCP | Forgejo |
| 3040 | TCP | Woodpecker HTTP |
| 3041 | TCP | Woodpecker gRPC |
| 5000 | TCP | Docker Registry |
| 5090 | TCP | SSHX Redis |
| 8051 | TCP | SSHX |
| 9090 | TCP | Cockpit |

> **Note:** The NixOS config opens these ports in the firewall module, but the firewall itself is force-disabled. In Debian, decide whether to enable `ufw`/`nftables` and open these ports explicitly, or continue with the firewall disabled behind Proxmox network controls.

---

## Impermanence (NixOS-specific -- reference only)

The NixOS root filesystem is ephemeral: the btrfs root subvolume is wiped and recreated on each boot. Old roots are kept as snapshots for 10 days. This will **not** be replicated in Debian.

### Persistent System Directories (under `/persist/system/`)

These directories survive reboots in NixOS and indicate stateful data that must be preserved in Debian:

| Directory | Service / Purpose |
|---|---|
| `/etc/nixos` | NixOS config (drop) |
| `/var/log` | System logs |
| `/var/lib/nixos` | NixOS state (drop) |
| `/var/lib/systemd/coredump` | Core dumps |
| `/var/lib/containers` | Podman container storage |
| `/var/lib/machines` | systemd-nspawn machines |
| `/var/lib/agenix` | Agenix decrypted secrets |
| `/var/lib/libvirt` | Libvirt VM storage |
| `/var/lib/woodpecker-server` | Woodpecker data |
| `/var/lib/private/woodpecker-server` | Woodpecker private data |
| `/var/lib/docker` | Docker data |
| `/etc/NetworkManager/system-connections` | NetworkManager connections |
| Forgejo `stateDir` | Forgejo repositories + data |
| Docker Registry `storagePath` | Registry image layers |

### Persistent Home Directories (under `/persist/home/antarctica/`)

| Directory | Purpose |
|---|---|
| `Downloads`, `Music`, `Pictures`, `Documents`, `Videos`, `Games` | User data |
| `opt` | User-local software |
| `.gnupg` | GPG keys |
| `.ssh` | SSH keys |
| `.nixops` | NixOps state (drop) |
| `.wasmer` | Wasmer runtime data |
| `.vscode`, `.vscodium` | VS Code settings |
| `.var` | Flatpak data |
| Various `.cache/*`, `.config/*`, `.local/share/*`, `.local/state/*` | App caches, configs, state |

---

## Environment Variables (from home-manager)

| Variable | Purpose | Migration |
|---|---|---|
| `GNUPGHOME` | GPG home directory | Shell profile / Ansible dotfiles |
| `NUGET_PACKAGES` | NuGet package cache | Shell profile |
| `TLDR_CACHE_DIR` | tldr cache | Shell profile |
| `CARGO_HOME` | Rust cargo home | Shell profile |
| `DOTNET_CLI_HOME` | .NET CLI home | Shell profile |
| `HISTFILE` | Shell history file | Shell profile |
| `GOPATH` | Go workspace | Shell profile |
| `XDG_DATA_HOME` | XDG data directory | Shell profile |
| `XDG_CONFIG_HOME` | XDG config directory | Shell profile |
| `XDG_STATE_HOME` | XDG state directory | Shell profile |
| `XDG_CACHE_HOME` | XDG cache directory | Shell profile |

---

## System Settings

| Setting | Value | Migration |
|---|---|---|
| Timezone | `America/Chicago` | `timedatectl` / Ansible |
| Locale | `en_US.UTF-8` | Ansible locale |
| zramSwap | Enabled at 75% | `zram-tools` package |
| kernel.sysrq | `1` (enabled) | `/etc/sysctl.d/` |
| Boot | systemd-boot, UEFI, latest kernel | GRUB (Proxmox default) |
| binfmt | aarch64-linux emulation | `qemu-user-static` + `binfmt-support` |
| sudo | `lecture=never` | `/etc/sudoers.d/` |
| Auto-upgrade | Daily at 12:00 +45min random delay | `unattended-upgrades` |
| Nix GC | Daily, delete older than 2d | N/A (drop) |
| mutableUsers | `false` | Ansible `user` module |

---

## NixOS-Specific Features (No Direct Debian Equivalent)

| Feature | NixOS Source | Migration Strategy |
|---|---|---|
| Impermanence (ephemeral root) | `nixos/modules/impermanence.nix` | Standard persistent Debian server. Ansible reconvergence = rebuild guarantee. |
| Hydra | `configuration/antarctica.nix` | **DROP.** NixOS-specific build system, not needed. |
| System76 Scheduler | `configuration/antarctica.nix` | **DROP.** No Debian equivalent, not needed. |
| rust-motd | `configuration/antarctica.nix` | Replace with simple `/etc/motd` or `dynamic-motd` script. |
| Woodpecker exec agent (Nix backend) | `nixos/modules/woodpecker/agent-exec.nix` | Replace with Docker/Podman-based agent. The local exec agent relies on Nix daemon. |
| Nix GC + auto-upgrade | `configuration/antarctica.nix` | Replace with `apt unattended-upgrades`. |
| home-manager | `home-manager/` | Ansible `dev_tools` role handles package installation and dotfile templating. |
| persist-retro | `nixos/modules/impermanence.nix` | Not needed without impermanence. |
| nix-direnv | `home-manager/devtools.nix` | Install `direnv` from apt/binary release. No Nix integration. |
| nix-prefetch-git | `home-manager/devtools.nix` | **DROP.** Nix-specific tooling. |
| fh (FlakeHub CLI) | `home-manager/devtools.nix` | **DROP.** Nix-specific tooling. |
| nil (Nix LSP) | `configuration/antarctica.nix` | **DROP.** Nix-specific language server. |
