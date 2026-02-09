# Runbook: Rotate Secrets

## Overview

Antarctica secrets are stored in 1Password (Antarctica vault) and referenced via `op://` URIs in the Ansible group vars. Rotating a secret means updating it in 1Password and re-running Ansible to propagate the new value.

## Secret inventory

| Secret | 1Password reference | Affected service |
|---|---|---|
| PostgreSQL password | `op://Antarctica/postgresql/password` | PostgreSQL, Woodpecker Server |
| Woodpecker agent secret | `op://Antarctica/woodpecker/agent-secret` | Woodpecker Server, Woodpecker Agent |
| Woodpecker Gitea client ID | `op://Antarctica/woodpecker/gitea-client` | Woodpecker Server |
| Woodpecker Gitea client secret | `op://Antarctica/woodpecker/gitea-secret` | Woodpecker Server |
| Forgejo secret key | `op://Antarctica/forgejo/secret-key` | Forgejo |
| Forgejo internal token | `op://Antarctica/forgejo/internal-token` | Forgejo |
| Forgejo OAuth2 JWT secret | `op://Antarctica/forgejo/oauth2-jwt-secret` | Forgejo |
| Forgejo LFS JWT secret | `op://Antarctica/forgejo/lfs-jwt-secret` | Forgejo |
| Actions runner token | `op://Antarctica/forgejo/action-runner-token` | Forgejo Actions Runner |

## Rotate a secret

### 1. Generate a new value

```bash
# Generate a random 64-character hex string
openssl rand -hex 32

# Or a base64 token
openssl rand -base64 32
```

### 2. Update in 1Password

```bash
# Example: rotate the PostgreSQL password
op item edit postgresql --vault Antarctica password="$(openssl rand -hex 32)"

# Example: rotate the Woodpecker agent secret
op item edit woodpecker --vault Antarctica agent-secret="$(openssl rand -hex 32)"
```

Or update via the 1Password desktop/web app.

### 3. Re-run Ansible

```bash
# For PostgreSQL password (affects PostgreSQL + Woodpecker)
mise run deploy:configure

# For Forgejo secrets only
mise run deploy:forgejo

# For Woodpecker secrets only
mise run deploy:woodpecker
```

### 4. Verify services restarted correctly

```bash
ssh deploy@antarctica.dev.nerds.run

# Check all services
sudo podman ps
sudo systemctl status forgejo woodpecker-server woodpecker-agent postgresql

# Test connectivity
curl -s http://127.0.0.1:3000/api/v1/version
curl -s http://127.0.0.1:3040/api/info
```

## Special cases

### PostgreSQL password rotation

The PostgreSQL password is used by both the PostgreSQL container and Woodpecker. When rotating:

1. Update in 1Password
2. Run the full `deploy:configure` to update both services
3. Verify Woodpecker can still connect to PostgreSQL:

```bash
sudo journalctl -u woodpecker-server --since "2 minutes ago" | grep -i "database\|postgres"
```

### Woodpecker agent secret rotation

This secret authenticates the agent to the server. Both must be updated simultaneously:

1. Update in 1Password
2. Run `mise run deploy:woodpecker`
3. Verify the agent reconnects:

```bash
sudo journalctl -u woodpecker-agent --since "2 minutes ago" | grep -i "connect\|register"
```

### Forgejo OAuth2 secrets (Woodpecker integration)

If you rotate the Gitea/Forgejo OAuth2 client ID or secret:

1. Update in Forgejo admin UI (Site Administration > Applications)
2. Update the corresponding values in 1Password
3. Run `mise run deploy:woodpecker`

## Emergency rotation

If a secret is compromised, rotate immediately:

```bash
# 1. Generate and update in 1Password
op item edit <item-name> --vault Antarctica <field>="$(openssl rand -hex 32)"

# 2. Apply immediately
mise run deploy:configure

# 3. Validate
mise run deploy:validate
```
