# Antarctica Migration Guide

NixOS to Debian 12 + Ansible + Pulumi

---

## Overview

Antarctica is migrating from a NixOS-based server to **Debian 12 (Bookworm)** managed by **Ansible** for configuration and **Pulumi (Go)** for infrastructure provisioning on Proxmox.

### What changed and why

| Before | After | Why |
|---|---|---|
| NixOS | Debian 12 | Broader team familiarity, simpler operational model |
| Nix flakes | Ansible roles | Declarative config without Nix learning curve |
| Manual VM | Pulumi (Go) | Reproducible infrastructure-as-code on Proxmox |
| Agenix secrets | 1Password (`op` CLI) | Team-accessible secret management |
| Nix containers | Podman Quadlet | Systemd-native container management |
| Nginx (NixOS) | Caddy | Automatic HTTPS, simpler config |
| Impermanence | Standard persistent root | Ansible reconvergence replaces ephemeral root guarantee |

### Architecture

```
                         +--------------------------+
                         |        Proxmox Host      |
                         |                          |
                         |  +--------------------+  |
                         |  |   antarctica VM    |  |
                         |  |   Debian 12        |  |
    Operator             |  |                    |  |
    Workstation          |  |  +--------------+  |  |
   +----------+          |  |  |    Caddy     |  |  |
   |          |  SSH     |  |  |  :80 / :443  |  |  |
   | Pulumi   +--------->+  |  +------+-------+  |  |
   | Ansible  |          |  |         |           |  |
   | mise     |          |  |    +----v----+      |  |
   | op CLI   |          |  |    | Forgejo |      |  |
   +----------+          |  |    | :3000   |      |  |
                         |  |    +----+----+      |  |
                         |  |         |           |  |
                         |  |  +------v--------+  |  |
                         |  |  |  Woodpecker   |  |  |
                         |  |  |  Server :3040 |  |  |
                         |  |  |  Agent        |  |  |
                         |  |  +------+--------+  |  |
                         |  |         |           |  |
                         |  |  +------v--------+  |  |
                         |  |  |  PostgreSQL   |  |  |
                         |  |  |  :5432        |  |  |
                         |  |  +--------------+  |  |
                         |  +--------------------+  |
                         +--------------------------+

    All services run as Podman Quadlet containers
    (except Caddy, which is a native systemd service).
    Containers communicate over the "antarctica" Podman network.
```

### Data flow

```
Internet --> Caddy (:443) --> Forgejo (:3000)
                          --> Woodpecker (:3040)
                          --> OpenVSCode Server (:3100)

Forgejo --> Forgejo PostgreSQL (:5433)
Forgejo webhooks --> Woodpecker Server --> Woodpecker Agent
                                      --> PostgreSQL (:5432)
Forgejo Actions --> Actions Runner

Git SSH --> Forgejo (:2222)
```

---

## Prerequisites

Install these tools on your **local workstation** before deploying:

| Tool | Purpose | Install |
|---|---|---|
| `mise` | Task runner (replaces Makefile) | https://mise.jdx.dev |
| `pulumi` | Infrastructure provisioning | `mise install pulumi` or https://www.pulumi.com/docs/install/ |
| `ansible` | Configuration management | `pip install ansible` or `mise install ansible` |
| `op` | 1Password CLI for secrets | https://developer.1password.com/docs/cli/ |
| `go` | Pulumi provider language | `mise install go` |
| `ssh` | Remote access | Pre-installed on most systems |

You also need:

- SSH key added to the server (ed25519 recommended)
- 1Password access to the **Infrastructure** vault (items prefixed with `antiarctica_`)
- Proxmox API credentials (for Pulumi)

---

## Deploy from Scratch

Full workflow to stand up Antarctica from nothing:

### 1. Clone and enter the repo

```bash
git clone <repo-url> antarctica
cd antarctica
```

### 2. Set up prerequisites

```bash
# Install mise tasks tool
curl https://mise.jdx.dev/install.sh | sh

# Authenticate with 1Password
op signin

# Set Proxmox credentials for Pulumi
export PROXMOX_VE_ENDPOINT="https://proxmox.example.com:8006"
export PROXMOX_VE_USERNAME="root@pam"
export PROXMOX_VE_PASSWORD="..."
```

### 3. Provision infrastructure

```bash
mise run deploy:infra
```

This runs `pulumi up` to create the Proxmox VM, then exports the VM's IP to `ansible/inventory/pulumi_output.json`.

### 4. Configure the server

```bash
mise run deploy:configure
```

This runs the full Ansible playbook (`site.yml`) which:
1. Configures base OS (hostname, locale, users, SSH, firewall)
2. Installs Podman and configures container runtime
3. Deploys Caddy as reverse proxy with auto-HTTPS
4. Deploys PostgreSQL container
5. Deploys Forgejo container
6. Deploys Woodpecker Server + Agent containers
7. Installs dev tools

### 5. Validate

```bash
mise run deploy:validate
```

Runs health checks on all services. See `ansible/playbooks/validate.yml` for details.

### One-command full deploy

```bash
mise run deploy
```

This chains `deploy:infra` then `deploy:configure` automatically.

---

## Common Operations

### Update configuration

Edit the relevant Ansible variables and re-run:

```bash
# Edit group vars
$EDITOR ansible/inventory/group_vars/antarctica.yml

# Apply all changes
mise run deploy:configure

# Or target a specific service
mise run deploy:forgejo
mise run deploy:woodpecker
mise run deploy:caddy
mise run deploy:base
```

### Add a new user

1. Edit `ansible/inventory/group_vars/antarctica.yml`
2. Add an entry to the `users` list:

```yaml
users:
  # ... existing users ...
  - name: newuser
    groups: "sudo,libvirt,kvm"
    shell: /usr/bin/bash
    ssh_keys:
      - "ssh-ed25519 AAAA... newuser@host"
```

3. Run the base playbook:

```bash
mise run deploy:base
```

### Add a new secret

1. Create the secret in the **Infrastructure** vault in 1Password (with `antiarctica_` prefix)
2. Add the `op://` reference to `ansible/inventory/group_vars/antarctica.yml`:

```yaml
op_new_secret: "op://Infrastructure/antiarctica_service-name/field-name"
```

3. Reference it in the relevant Ansible role template
4. Re-run the playbook for that service

### Rotate secrets

See `docs/runbooks/rotate-secrets.md`.

---

## Key Differences from NixOS

| Area | NixOS | Debian + Ansible |
|---|---|---|
| Declarative guarantee | Nix store ensures exact state | Ansible idempotency ensures convergence |
| Rollback | `nixos-rebuild switch --rollback` | Re-run Ansible with previous vars (git revert + apply) |
| Secrets | Agenix (age-encrypted in repo) | 1Password CLI (`op`) fetched at deploy time |
| Container management | NixOS module + systemd | Podman Quadlet `.container` files |
| Package management | Nix packages | apt + GitHub releases + pip/cargo |
| User management | `users.users` in Nix | `ansible.builtin.user` module |
| Firewall | NixOS firewall module | nftables (configured via Ansible template) |
| Ephemeral root | Btrfs subvolume wipe on boot | Persistent root, Ansible reconvergence |
| Build system | Hydra | **Dropped** -- not needed |

### Things that no longer exist

- **Impermanence** -- root is persistent, no wipe-on-boot
- **Hydra** -- NixOS CI, replaced by Woodpecker + Forgejo Actions
- **System76 Scheduler** -- NixOS-specific, no equivalent needed
- **nix-direnv** -- replaced by plain `direnv` from apt
- **Woodpecker exec agent** -- replaced by Docker/Podman-based agent

---

## Rollback Procedure

Ansible is idempotent. Rolling back means applying the previous known-good configuration:

### Configuration rollback

```bash
# See recent commits
git log --oneline -10

# Revert to previous known-good state
git revert HEAD
# or checkout a specific commit
git checkout <commit-sha> -- ansible/

# Re-apply
mise run deploy:configure
```

### Container rollback

If a container image update causes issues:

```bash
# SSH into the server
ssh antarctica@172.22.202.50

# Check current image
sudo podman inspect forgejo --format '{{.ImageName}}'

# Pull a specific version
sudo podman pull codeberg.org/forgejo/forgejo:8.0.3

# Pin the image tag in the Quadlet file
sudo systemctl restart forgejo
```

To permanently pin, update the `forgejo_image` variable in `ansible/inventory/group_vars/antarctica.yml` and re-run Ansible.

### Infrastructure rollback

```bash
# Destroy and recreate the VM
mise run deploy:destroy
mise run deploy
```

**Warning:** This destroys all data on the VM. Restore from backups afterward. See `docs/runbooks/disaster-recovery.md`.

---

## Service Management

SSH into the server and use standard systemd and podman commands:

### Systemd services

```bash
# Caddy (native systemd)
sudo systemctl status caddy
sudo systemctl restart caddy
sudo journalctl -u caddy -f

# nftables
sudo systemctl status nftables
```

### Podman containers (via Quadlet)

```bash
# List running containers
sudo podman ps

# Service status (Quadlet containers are systemd units)
sudo systemctl status forgejo
sudo systemctl status woodpecker-server
sudo systemctl status woodpecker-agent
sudo systemctl status postgresql

# Restart a service
sudo systemctl restart forgejo

# View logs
sudo journalctl -u forgejo -f
sudo podman logs -f forgejo

# Enter a container shell
sudo podman exec -it forgejo /bin/sh
sudo podman exec -it postgresql psql -U woodpecker
```

### Health checks

```bash
# Forgejo
curl -s http://127.0.0.1:3000/api/v1/version

# Woodpecker
curl -s http://127.0.0.1:3040/api/info

# PostgreSQL
sudo podman exec postgresql pg_isready -U woodpecker
```

---

## Server Specifications

| Spec | Value |
|---|---|
| RAM | 32 GB |
| CPUs | 16 |
| Hypervisor | Proxmox |
| OS | Debian 12 (Bookworm) |
| Container runtime | Podman with Quadlet |
| Storage | LVM, persistent `/data` directory |

### Future considerations

- **Worker nodes**: CI agents can be scaled to additional VMs by deploying only the `woodpecker-agent` role with Pulumi provisioning additional Proxmox VMs
- **Backups**: Configure automated backups of `/data` using restic or borgmatic
- **Monitoring**: Add Prometheus + Grafana stack as additional Ansible roles

---

## File Structure Reference

```
antarctica/
  mise.toml               # Tool versions and env vars
  .mise/tasks/            # mise task scripts
  .forgejo/workflows/      # CI workflow definitions
  docs/
    INVENTORY.md           # Full NixOS-to-Ansible migration inventory
    MIGRATION.md           # This file
    runbooks/              # Operational runbooks
  infra/                   # Pulumi Go infrastructure code
    main.go
    Pulumi.yaml
  ansible/
    ansible.cfg            # Ansible configuration
    playbooks/
      site.yml             # Full deployment playbook
      base.yml             # Base OS only
      forgejo.yml          # Forgejo only
      woodpecker.yml       # Woodpecker only
      caddy.yml            # Caddy only
      postgresql.yml       # PostgreSQL only
      openvscode.yml       # OpenVSCode Server only
      dev_tools.yml        # Dev tools only
      validate.yml         # Validation checks
    inventory/
      hosts.yml            # Host inventory
      group_vars/
        antarctica.yml     # All variables
    roles/
      base/                # OS config, users, SSH, firewall
      container_runtime/   # Podman installation
      caddy/               # Reverse proxy
      postgresql/          # Database container
      forgejo/             # Git forge
      woodpecker/          # CI server + agent
      openvscode/          # Browser-based IDE
      dev_tools/           # Developer packages
```
