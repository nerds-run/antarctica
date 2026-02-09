# Runbook: Update Forgejo

## Automatic updates (recommended)

Forgejo runs as a Podman Quadlet container with the `latest` tag by default. Podman auto-update pulls new images automatically when configured.

To trigger a manual auto-update check:

```bash
ssh deploy@antarctica.dev.nerds.run
sudo podman auto-update
```

## Manual update

### 1. Pull the new image

```bash
ssh deploy@antarctica.dev.nerds.run
sudo podman pull codeberg.org/forgejo/forgejo:latest
```

### 2. Restart the service

```bash
sudo systemctl restart forgejo
```

### 3. Verify

```bash
# Check container is running
sudo podman ps --filter name=forgejo

# Check Forgejo version
curl -s http://127.0.0.1:3000/api/v1/version

# Check logs for errors
sudo journalctl -u forgejo --since "5 minutes ago" --no-pager
```

## Pin a specific version

To pin Forgejo to a specific version instead of `latest`:

### 1. Edit the variable

In `ansible/inventory/group_vars/antarctica.yml`:

```yaml
forgejo_image: codeberg.org/forgejo/forgejo:8.0.3
```

### 2. Re-run Ansible

```bash
mise run deploy:forgejo
```

This updates the Quadlet file and restarts the container.

## Rollback

If a new version causes problems:

### Quick rollback (on the server)

```bash
ssh deploy@antarctica.dev.nerds.run

# Stop the current container
sudo systemctl stop forgejo

# Pull the previous version
sudo podman pull codeberg.org/forgejo/forgejo:8.0.2

# Update the Quadlet image reference temporarily
sudo sed -i 's|Image=.*|Image=codeberg.org/forgejo/forgejo:8.0.2|' \
  /etc/containers/systemd/forgejo.container

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl start forgejo
```

### Permanent rollback (via Ansible)

1. Set `forgejo_image` to the working version in `antarctica.yml`
2. Run `mise run deploy:forgejo`

## Pre-update checklist

- [ ] Check the [Forgejo release notes](https://codeberg.org/forgejo/forgejo/releases) for breaking changes
- [ ] Back up Forgejo data: `sudo podman exec forgejo forgejo dump -c /etc/forgejo/app.ini`
- [ ] Back up the database if Forgejo uses PostgreSQL
- [ ] Ensure `/data/forgejo` has sufficient disk space
