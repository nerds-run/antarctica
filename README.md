<div align="center">
    <img src="./assets/antarctica_logo_temp.png" alt="antarctica logo" width="200rem"/>
    <h1 style="font-size: 48px; margin-left: 0.1em; text-align: center;">Antarctica</h1>
</div>

Shared development server for NerdsRun, running **Debian 12** on **Proxmox**, managed with **Ansible** and **Pulumi (Go)**.

## Architecture

- **Infrastructure**: Proxmox VM provisioned with Pulumi (`pulumi-proxmoxve`)
- **Configuration**: Ansible (8 roles) for declarative server setup
- **Containers**: Podman 5.x with Quadlet (systemd-native container management)
- **Reverse proxy**: Caddy (native systemd, automatic HTTPS)
- **CI**: Woodpecker CI + Forgejo Actions runners
- **Secrets**: 1Password (`op` CLI, referenced via `op://` URIs)

### Services

| Service | Port | Domain |
|---|---|---|
| Forgejo (git forge) | 3000 | forgejo.dev.nerds.run |
| Woodpecker CI | 3040 | woodpecker.dev.nerds.run |
| OpenVSCode Server | 3100 | vscode.dev.nerds.run |
| Caddy (reverse proxy) | 80/443 | *.dev.nerds.run |
| PostgreSQL (Woodpecker) | 5432 | -- |
| PostgreSQL (Forgejo) | 5433 | -- |
| Cockpit | 9090 | cockpit.dev.nerds.run |

### Server Specs

| Spec | Value |
|---|---|
| OS | Debian 12 (Bookworm) |
| RAM | 32 GB |
| CPUs | 16 |
| Data disk | 180 GB (`/data`) |
| IP | 172.22.202.50 |

## Quick Start

### Prerequisites

- [mise](https://mise.jdx.dev) -- task runner and tool version manager
- [1Password CLI](https://developer.1password.com/docs/cli/) (`op`) -- secrets access
- SSH key added to the server (or use the deploy key from 1Password)

### Setup

```bash
git clone <repo-url> antarctica
cd antarctica

# Install tool versions (Go, Pulumi, Python, Node)
mise install

# Install Python dependencies (Ansible, Molecule, linters)
mise run setup
```

### First Deploy

```bash
# Full bootstrap: extract SSH key, provision VM, configure, validate
mise run bootstrap
```

### Update an Existing Server

```bash
# Deploy everything
mise run deploy:configure

# Deploy a specific service
mise run deploy:forgejo
mise run deploy:woodpecker
mise run deploy:caddy
mise run deploy:postgresql
mise run deploy:openvscode
mise run deploy:base
mise run deploy:dev-tools
```

## Development

### Linting

```bash
mise run lint:all      # Run all linters (yamllint, ansible-lint, golangci-lint)
mise run lint:ansible  # Ansible-lint only
mise run lint:yaml     # yamllint only
mise run lint:go       # Go linting only
```

### Testing with Molecule

```bash
mise run test:all        # Run all role tests
mise run test:role base  # Test a specific role
mise run test:converge   # Converge without destroying
mise run test:verify     # Run verification only
```

## Mise Task Reference

| Task | Description |
|---|---|
| `setup` | Install Python dependencies and Ansible collections |
| `bootstrap` | First-time deployment from scratch |
| **Deploy** | |
| `deploy:all` | Full deployment: Pulumi infra + Ansible config |
| `deploy:infra` | Provision infrastructure with Pulumi |
| `deploy:configure` | Configure server with Ansible (full site.yml) |
| `deploy:validate` | Run validation checks |
| `deploy:ssh-key` | Extract deploy SSH key from 1Password |
| `deploy:base` | Deploy only base OS changes |
| `deploy:caddy` | Deploy only Caddy changes |
| `deploy:forgejo` | Deploy only Forgejo changes |
| `deploy:woodpecker` | Deploy only Woodpecker changes |
| `deploy:postgresql` | Deploy only PostgreSQL changes |
| `deploy:openvscode` | Deploy only OpenVSCode Server changes |
| `deploy:dev-tools` | Deploy only dev tools changes |
| `deploy:check` | Dry-run deployment (check mode) |
| `deploy:destroy` | Destroy Pulumi infrastructure |
| **Ops** | |
| `ops:ssh` | SSH into the Antarctica server |
| `ops:status` | Show status of all services |
| `ops:logs` | View logs for a service |
| `ops:restart` | Restart a service |
| `ops:health` | Check health endpoints |
| **Lint** | |
| `lint:all` | Run all linters |
| `lint:yaml` | Run yamllint |
| `lint:ansible` | Run ansible-lint |
| `lint:go` | Run Go linting |
| `lint:fix` | Auto-fix lint issues |
| **Test** | |
| `test:all` | Run all Molecule role tests |
| `test:role` | Test a specific role |
| `test:converge` | Converge without destroying |
| `test:verify` | Run verification only |
| `test:destroy` | Destroy test instances |
| `test:idempotence` | Run idempotence test |
| `test:integration` | Run integration tests |
| `test:login` | Log into test instance |

## CI

CI runs via a **Forgejo Actions** workflow (`.forgejo/workflows/`) that lints and tests roles in dependency order on every push and pull request.

## Documentation

- [Migration Guide](docs/MIGRATION.md) -- NixOS to Debian migration details
- [NixOS Inventory](docs/INVENTORY.md) -- Historical reference from the NixOS era
- [Runbooks](docs/runbooks/) -- Operational procedures:
  - [Backup & Restore](docs/runbooks/backup-restore.md)
  - [Disaster Recovery](docs/runbooks/disaster-recovery.md)
  - [Rotate Secrets](docs/runbooks/rotate-secrets.md)
  - [Update Forgejo](docs/runbooks/update-forgejo.md)
  - [Update Woodpecker](docs/runbooks/update-woodpecker.md)
  - [Add User](docs/runbooks/add-user.md)

## File Structure

```
antarctica/
  mise.toml                  # Tool versions and env vars
  .mise/tasks/               # mise task scripts
    deploy/                  # Deployment tasks
    ops/                     # Operational helper tasks
    lint/                    # Linting tasks
    test/                    # Testing tasks
  .forgejo/workflows/        # CI workflow definitions
  docs/
    INVENTORY.md             # NixOS migration inventory (historical)
    MIGRATION.md             # Migration guide
    runbooks/                # Operational runbooks
  infra/                     # Pulumi Go infrastructure code
    main.go
    Pulumi.yaml
  ansible/
    ansible.cfg
    playbooks/
      site.yml               # Full deployment
      base.yml               # Base OS
      forgejo.yml            # Forgejo + deps
      woodpecker.yml         # Woodpecker + deps
      caddy.yml              # Caddy reverse proxy
      postgresql.yml         # PostgreSQL
      openvscode.yml         # OpenVSCode Server
      dev_tools.yml          # Dev tools
      validate.yml           # Validation checks
    inventory/
      hosts.yml
      group_vars/
        antarctica.yml       # All variables
    roles/
      base/                  # OS config, users, SSH, firewall
      container_runtime/     # Podman installation
      caddy/                 # Reverse proxy
      postgresql/            # Database container
      forgejo/               # Git forge
      woodpecker/            # CI server + agent
      openvscode/            # Browser-based IDE
      dev_tools/             # Developer packages
```
