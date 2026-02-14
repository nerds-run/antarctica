# Runbook: Backup and Restore

## What to back up

| Directory | Contents | Priority |
|---|---|---|
| `/data/forgejo` | Git repos, LFS objects, avatars, attachments | Critical |
| `/data/forgejo-postgresql` | Forgejo PostgreSQL database files | Critical |
| `/data/postgresql` | PostgreSQL database (Woodpecker data) | Critical |
| `/data/woodpecker` | Woodpecker server state | High |
| `/data/caddy` | TLS certificates, OCSP staples | Medium (auto-regenerated) |
| `/data/registry` | Docker registry layers | Medium (can be rebuilt) |
| `/data/openvscode` | OpenVSCode Server data | Low |

## Backup methods

### Forgejo dump (application-level)

Creates a complete Forgejo backup including repos, database, and config:

```bash
ssh antarctica@172.22.202.50

# Run Forgejo dump
sudo podman exec forgejo forgejo dump \
  -c /etc/forgejo/app.ini \
  --tempdir /tmp

# Copy the dump file out
sudo podman cp forgejo:/tmp/forgejo-dump-*.zip /data/backups/
```

### PostgreSQL dump

```bash
ssh antarctica@172.22.202.50

# SQL dump
sudo podman exec postgresql pg_dump \
  -U woodpecker \
  -d woodpecker \
  --format=custom \
  -f /tmp/woodpecker.pgdump

# Copy out of container
sudo podman cp postgresql:/tmp/woodpecker.pgdump /data/backups/

# Or plain SQL for readability
sudo podman exec postgresql pg_dumpall -U woodpecker > /data/backups/all-databases.sql
```

### Filesystem-level backup with restic

Recommended for automated, incremental backups:

```bash
# Install restic
sudo apt install restic

# Initialize a backup repository (one-time)
sudo restic init --repo /backup/antarctica
# Or use remote storage:
# sudo restic init --repo s3:s3.amazonaws.com/bucket/antarctica

# Run backup
sudo restic backup \
  --repo /backup/antarctica \
  /data/forgejo \
  /data/forgejo-postgresql \
  /data/postgresql \
  /data/woodpecker \
  /data/caddy \
  /data/registry \
  /data/openvscode

# List snapshots
sudo restic snapshots --repo /backup/antarctica
```

### Filesystem-level backup with borgmatic

Alternative to restic with a YAML config:

```bash
# Install
sudo apt install borgbackup
sudo pip install borgmatic

# Create config at /etc/borgmatic/config.yaml
sudo borgmatic init --encryption repokey

# Run backup
sudo borgmatic create --verbosity 1
```

Example `/etc/borgmatic/config.yaml`:

```yaml
source_directories:
  - /data/forgejo
  - /data/forgejo-postgresql
  - /data/postgresql
  - /data/woodpecker
  - /data/caddy
  - /data/registry
  - /data/openvscode

repositories:
  - path: /backup/antarctica
    label: antarctica

retention:
  keep_daily: 7
  keep_weekly: 4
  keep_monthly: 6

hooks:
  before_backup:
    - podman exec postgresql pg_dump -U woodpecker -d woodpecker -f /tmp/pre-backup.sql
  after_backup:
    - podman exec postgresql rm -f /tmp/pre-backup.sql
```

## Suggested backup schedule

| Backup type | Frequency | Retention |
|---|---|---|
| PostgreSQL dump | Every 6 hours | 7 days |
| Forgejo dump | Daily | 30 days |
| Filesystem (restic/borg) | Daily | 7 daily, 4 weekly, 6 monthly |

### Cron example

```bash
# /etc/cron.d/antarctica-backups

# PostgreSQL dump every 6 hours
0 */6 * * * root podman exec postgresql pg_dump -U woodpecker -d woodpecker --format=custom -f /data/backups/woodpecker-$(date +\%Y\%m\%d-\%H\%M).pgdump

# Restic filesystem backup at 2 AM daily
0 2 * * * root restic backup --repo /backup/antarctica /data/forgejo /data/forgejo-postgresql /data/postgresql /data/woodpecker /data/caddy /data/registry /data/openvscode --quiet

# Cleanup old PostgreSQL dumps (keep 7 days)
0 3 * * * root find /data/backups -name '*.pgdump' -mtime +7 -delete

# Restic prune old snapshots weekly
0 4 * * 0 root restic forget --repo /backup/antarctica --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
```

## Restore procedures

### Restore PostgreSQL from dump

```bash
ssh antarctica@172.22.202.50

# Stop services that use the database
sudo systemctl stop woodpecker-server

# Copy dump into container
sudo podman cp /data/backups/woodpecker-YYYYMMDD-HHMM.pgdump postgresql:/tmp/

# Drop and recreate database
sudo podman exec postgresql dropdb -U woodpecker woodpecker
sudo podman exec postgresql createdb -U woodpecker woodpecker

# Restore
sudo podman exec postgresql pg_restore \
  -U woodpecker \
  -d woodpecker \
  /tmp/woodpecker-YYYYMMDD-HHMM.pgdump

# Restart services
sudo systemctl start woodpecker-server
```

### Restore Forgejo from dump

```bash
ssh antarctica@172.22.202.50

# Stop Forgejo
sudo systemctl stop forgejo

# Extract the dump
sudo mkdir -p /tmp/forgejo-restore
sudo unzip /data/backups/forgejo-dump-*.zip -d /tmp/forgejo-restore

# Restore data directory
sudo rsync -av /tmp/forgejo-restore/data/ /data/forgejo/

# Restart
sudo systemctl start forgejo
```

### Restore from restic

```bash
ssh antarctica@172.22.202.50

# List available snapshots
sudo restic snapshots --repo /backup/antarctica

# Restore latest snapshot
sudo restic restore latest --repo /backup/antarctica --target /

# Or restore a specific snapshot
sudo restic restore abc1234 --repo /backup/antarctica --target /

# Or restore specific paths
sudo restic restore latest --repo /backup/antarctica --target / --include /data/forgejo

# Restart all services
sudo systemctl restart postgresql forgejo woodpecker-server woodpecker-agent caddy
```

## Verifying backups

Periodically test that backups are restorable:

```bash
# Check restic repository integrity
sudo restic check --repo /backup/antarctica

# Test restore to a temporary directory
sudo restic restore latest --repo /backup/antarctica --target /tmp/backup-test/
ls -la /tmp/backup-test/data/
rm -rf /tmp/backup-test/
```
