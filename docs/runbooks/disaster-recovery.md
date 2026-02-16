# Runbook: Disaster Recovery

## Overview

This runbook covers recovering from a total loss of the Antarctica server. The recovery strategy relies on:

- **Pulumi state** -- recreate the VM from infrastructure code
- **Ansible playbooks** -- reconverge all configuration
- **Backups of `/data`** -- restore persistent application data

## Recovery steps

### 1. Provision a new VM

```bash
cd antarctica

# Destroy leftover Pulumi state if the VM is gone
mise run deploy:destroy

# Provision a fresh VM
mise run deploy:infra
```

This creates a new Debian 12 VM on Proxmox with the correct specs (32 GB RAM, 16 CPUs).

### 2. Run Ansible to reconverge

```bash
mise run deploy:configure
```

This installs all packages, creates users, configures the firewall, deploys Caddy, and creates all Podman Quadlet containers. The Forgejo admin user (`abanna`) is created automatically on first run using the password from 1Password (`op://Infrastructure/antiarctica_forgejo/admin_password`). Services will start but will have empty data.

### 3. Restore data from backups

Data directories to restore:

| Directory | Contents |
|---|---|
| `/data/forgejo` | Git repositories, LFS objects, Forgejo config |
| `/data/forgejo-postgresql` | Forgejo PostgreSQL database files |
| `/data/postgresql` | PostgreSQL database files |
| `/data/woodpecker` | Woodpecker server data |
| `/data/caddy` | Caddy TLS certificates and state |
| `/data/openvscode` | OpenVSCode Server data |

#### If using restic

```bash
ssh antarctica@172.22.202.50

# Restore all data directories
sudo restic -r <repo-url> restore latest --target /

# Or restore specific paths
sudo restic -r <repo-url> restore latest --target / --include /data/forgejo
sudo restic -r <repo-url> restore latest --target / --include /data/postgresql
```

#### If using manual backups

```bash
# Copy backup archive to server
scp backup-YYYY-MM-DD.tar.gz antarctica@172.22.202.50:/tmp/

# SSH in and extract
ssh antarctica@172.22.202.50
sudo tar xzf /tmp/backup-YYYY-MM-DD.tar.gz -C /
rm /tmp/backup-YYYY-MM-DD.tar.gz
```

### 4. Restore PostgreSQL database

If restoring from a `pg_dump` SQL file instead of a filesystem backup:

```bash
ssh antarctica@172.22.202.50

# Copy the dump into the container
sudo podman cp woodpecker.sql postgresql:/tmp/woodpecker.sql

# Restore
sudo podman exec -it postgresql psql -U woodpecker -d woodpecker -f /tmp/woodpecker.sql
```

### 5. Restart all services

```bash
ssh antarctica@172.22.202.50

sudo systemctl restart postgresql
sudo systemctl restart forgejo
sudo systemctl restart woodpecker-server
sudo systemctl restart woodpecker-agent
sudo systemctl restart caddy
```

### 6. Validate

From your local workstation:

```bash
mise run deploy:validate
```

Or manually check on the server:

```bash
ssh antarctica@172.22.202.50

sudo podman ps
curl -s http://127.0.0.1:3000/api/v1/version
curl -s http://127.0.0.1:3040/api/info
sudo podman exec postgresql pg_isready -U woodpecker
```

### 7. Verify DNS

Ensure DNS records point to the new VM's IP:

- `forgejo.dev.nerds.run` -> new IP
- `woodpecker.dev.nerds.run` -> new IP
- `antarctica.dev.nerds.run` -> new IP

### 8. Verify HTTPS certificates

Caddy will automatically provision new TLS certificates via Let's Encrypt. If you restored `/data/caddy`, existing certificates will be reused. Check:

```bash
curl -vI https://forgejo.dev.nerds.run 2>&1 | grep "SSL certificate"
```

## Recovery time estimate

| Step | Approximate time |
|---|---|
| Pulumi VM provisioning | 5-10 minutes |
| Ansible reconvergence | 10-15 minutes |
| Data restore (depends on size) | 10-60 minutes |
| DNS propagation | 0-30 minutes |
| TLS certificate issuance | 1-5 minutes |
| **Total** | **30-120 minutes** |

## Prevention

To minimize recovery time:

- Set up automated backups (see `backup-restore.md`)
- Test recovery in a staging environment periodically
- Keep Pulumi state backed up (use Pulumi Cloud or S3 backend)
- Document any manual changes made outside of Ansible
