# Runbook: Update Woodpecker

## Overview

Woodpecker has two components that must be updated together:
- **woodpecker-server** -- the web UI and API
- **woodpecker-agent** -- the CI job runner

Both should run the same version. Always update them together.

## Automatic updates

Both containers use the `latest` tag by default. Podman auto-update handles pulling new images:

```bash
ssh antarctica@172.22.202.50
sudo podman auto-update
```

## Manual update

### 1. Pull new images

```bash
ssh antarctica@172.22.202.50
sudo podman pull docker.io/woodpeckerci/woodpecker-server:latest
sudo podman pull docker.io/woodpeckerci/woodpecker-agent:latest
```

### 2. Restart both services

```bash
# Restart server first, then agent
sudo systemctl restart woodpecker-server
sudo systemctl restart woodpecker-agent
```

### 3. Verify

```bash
# Check containers are running
sudo podman ps --filter name=woodpecker

# Check server health
curl -s http://127.0.0.1:3040/api/info

# Check agent is connected (in server logs)
sudo journalctl -u woodpecker-server --since "5 minutes ago" | grep -i agent

# Check agent logs
sudo journalctl -u woodpecker-agent --since "5 minutes ago" --no-pager
```

## Pin a specific version

Edit `ansible/inventory/group_vars/antarctica.yml`:

```yaml
woodpecker_server_image: docker.io/woodpeckerci/woodpecker-server:2.7.0
woodpecker_agent_image: docker.io/woodpeckerci/woodpecker-agent:2.7.0
```

Then apply:

```bash
mise run deploy:woodpecker
```

## Rollback

### Quick rollback (on the server)

```bash
ssh antarctica@172.22.202.50

sudo systemctl stop woodpecker-agent
sudo systemctl stop woodpecker-server

sudo podman pull docker.io/woodpeckerci/woodpecker-server:2.6.0
sudo podman pull docker.io/woodpeckerci/woodpecker-agent:2.6.0

# Update Quadlet files temporarily
sudo sed -i 's|Image=.*woodpecker-server.*|Image=docker.io/woodpeckerci/woodpecker-server:2.6.0|' \
  /etc/containers/systemd/woodpecker-server.container
sudo sed -i 's|Image=.*woodpecker-agent.*|Image=docker.io/woodpeckerci/woodpecker-agent:2.6.0|' \
  /etc/containers/systemd/woodpecker-agent.container

sudo systemctl daemon-reload
sudo systemctl start woodpecker-server
sudo systemctl start woodpecker-agent
```

### Permanent rollback (via Ansible)

1. Set both image variables to the working version in `antarctica.yml`
2. Run `mise run deploy:woodpecker`

## Pre-update checklist

- [ ] Check the [Woodpecker changelog](https://github.com/woodpecker-ci/woodpecker/releases) for breaking changes
- [ ] Ensure no CI jobs are currently running: check the Woodpecker UI or API
- [ ] Back up the Woodpecker database (stored in PostgreSQL): see `backup-restore.md`
- [ ] Verify server and agent versions match after update
