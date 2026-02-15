# Runbook: Add a New SSH User

## When to use

When a new team member needs SSH access to the Antarctica server.

## Steps

### 1. Get the user's SSH public key

Ask the user for their **ed25519** public key:

```bash
# They should run on their machine:
cat ~/.ssh/id_ed25519.pub
```

### 2. Edit the group vars

Open `ansible/inventory/group_vars/antarctica.yml` and add the user to the `base_users` list:

```yaml
base_users:
  # ... existing users ...
  - name: newuser
    groups: "sudo,libvirt,kvm"
    shell: /usr/bin/bash    # or /usr/bin/nu for nushell
    ssh_keys:
      - "ssh-ed25519 AAAA... newuser@hostname"
```

If the user should also have root SSH access, add their key to `base_root_ssh_keys`:

```yaml
base_root_ssh_keys:
  # ... existing keys ...
  - "ssh-ed25519 AAAA... newuser@hostname"
```

### 3. Deploy

```bash
mise run deploy:base
```

This runs the base playbook which creates the user account, sets their shell, adds them to the specified groups, and deploys their SSH authorized keys.

### 4. Verify

```bash
# Test SSH access as the new user
ssh newuser@antarctica.dev.nerds.run

# Or run the validation playbook
mise run deploy:validate
```

## Removing a user

1. Remove the user entry from `base_users` in `antarctica.yml`
2. Remove their key from `base_root_ssh_keys` if present
3. Run `mise run deploy:base`
4. Optionally SSH in and remove their home directory: `sudo userdel -r newuser`

Note: Ansible's `user` module does not automatically remove users that are absent from the list. To fully remove a user, either add a removal task or handle it manually.
