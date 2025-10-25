# TrueNAS Integration Scripts

Automated scripts for reorganizing your Docker homelab storage on existing TrueNAS NFS mounts.

## Current Setup

Your homelab already uses TrueNAS storage:
- `/home/dev/docker` ← `192.168.10.15:/mnt/nas-pool/nfs-share/docker`
- `/media` ← `192.168.10.15:/mnt/nas-pool/data/media`

These scripts reorganize your existing NFS-mounted storage for better organization, snapshot management, and scalability.

## Scripts Overview

### 1. `reorganize-existing-storage.sh`
**Run on:** Docker host (192.168.10.13)
**Purpose:** Creates organized directory structure within existing NFS mounts

```bash
bash reorganize-existing-storage.sh  # No sudo needed with proper NFS mapping
```

Creates:
```
/home/dev/docker/
├── docker-configs/      # Git repo (existing)
├── appdata/            # Service configs (NEW)
│   ├── traefik/
│   ├── homepage/
│   ├── jellyfin/
│   └── ...
├── databases/          # Databases (NEW)
└── downloads/          # Downloads (NEW)

/media/
├── movies/
├── tv/
├── music/
├── books/
└── photos/
```

### 2. `migrate-existing-data.sh`
**Run on:** Docker host (192.168.10.13)
**Purpose:** Moves service data from docker-configs to new organized structure

**IMPORTANT:** Stop all Docker services first!

```bash
# Dry run first to see what will happen
bash migrate-existing-data.sh --dry-run

# Actual migration
bash migrate-existing-data.sh
```

### 3. `update-compose-files.sh`
**Run on:** Docker host (192.168.10.13)
**Purpose:** Updates docker-compose files with new volume paths

```bash
bash update-compose-files.sh
```

Automatically updates:
- Traefik: Config, logs, acme.json
- Homepage: Config directory
- Jellyfin: Config, media paths
- Servarr: All service configs, media, downloads
- RustDesk: Data directory
- Twingate: Config

### 4. `master-migration.sh`
**Run on:** Docker host (192.168.10.13)
**Purpose:** Runs the entire migration process in order

```bash
bash master-migration.sh  # No sudo needed!
```

Executes:
1. Reorganize storage
2. Migrate data
3. Update compose files
4. Validate configurations
5. Provide next steps

## Quick Start (Recommended)

### Option 1: Automated (All-in-One)

```bash
cd /home/dev/docker/docker-configs/scripts

# Make scripts executable
chmod +x *.sh

# Run master migration script (no sudo needed!)
bash master-migration.sh
```

### Option 2: Manual (Step-by-Step)

```bash
cd /home/dev/docker/docker-configs/scripts

# Step 1: Reorganize storage
bash reorganize-existing-storage.sh

# Step 2: Stop all services
cd /home/dev/docker/docker-configs
docker compose -f traefik/docker-compose.yaml down
docker compose -f homepage/docker-compose.yaml down
docker compose -f jellyfin/compose.yaml down
docker compose -f servarr/compose.yaml down
docker compose -f rustdesk/docker-compose.yml down

# Step 3: Migrate data (dry run first)
cd /home/dev/docker/docker-configs/scripts
bash migrate-existing-data.sh --dry-run
bash migrate-existing-data.sh

# Step 4: Update compose files
bash update-compose-files.sh

# Step 5: Validate and test
cd /home/dev/docker/docker-configs
docker compose -f traefik/docker-compose.yaml config
docker compose -f traefik/docker-compose.yaml up -d
docker compose logs -f traefik
```

## TrueNAS Scripts (Optional)

These scripts are for creating a fresh TrueNAS structure. **You don't need these** since you already have NFS mounts configured, but they're included for reference.

### `truenas-setup.sh`
**Run on:** TrueNAS (192.168.10.15)
**Purpose:** Creates ZFS datasets with optimized properties

### `truenas-nfs-setup.sh`
**Run on:** TrueNAS (192.168.10.15)
**Purpose:** Configures NFS exports

## After Migration

### 1. Configure TrueNAS Snapshots

Go to TrueNAS Web UI → **Data Protection → Periodic Snapshot Tasks**

**Appdata Snapshots:**
- Dataset: `nas-pool/nfs-share/docker` (or create child dataset `nas-pool/nfs-share/docker/appdata`)
- Schedule: Hourly
- Lifetime: 24 hours
- Recursive: Yes

**Database Snapshots:**
- Dataset: `nas-pool/nfs-share/docker/databases` (if created as separate dataset)
- Schedule: Every 15 minutes
- Lifetime: 2 hours

**Media Snapshots:**
- Dataset: `nas-pool/data/media`
- Schedule: Daily at 2 AM
- Lifetime: 7 days

### 2. Test Snapshot Restore

```bash
# List snapshots
ssh root@192.168.10.15 "zfs list -t snapshot | grep docker"

# Restore a file from snapshot
cp /home/dev/docker/.zfs/snapshot/auto-2024-01-25-14:00/appdata/traefik/config/traefik.yml ~/restored-file.yml
```

### 3. Commit Changes to Git

```bash
cd /home/dev/docker/docker-configs

# Review changes
git status
git diff

# Commit
git add -u
git commit -m "Reorganize storage: use centralized appdata structure

- Move service configs to /home/dev/docker/appdata/
- Separate databases for granular snapshots
- Organize media library structure
- Update all docker-compose volume paths"

git push origin main
```

## Troubleshooting

### Services won't start after migration

**Check paths:**
```bash
ls -la /home/dev/docker/appdata/traefik/config/
ls -la /media/
```

**Check permissions:**
```bash
ls -ld /home/dev/docker/appdata/
# Should show: drwxr-xr-x dev dev
```

**Fix permissions:**
```bash
sudo chown -R 1000:1000 /home/dev/docker/appdata
sudo chown -R 1000:1000 /home/dev/docker/databases
sudo chmod -R 755 /home/dev/docker/appdata
```

### File not found errors

**Verify data was copied:**
```bash
find /home/dev/docker/appdata -type f | head -20
```

**Check docker-compose paths:**
```bash
cd /home/dev/docker/docker-configs
docker compose -f traefik/docker-compose.yaml config | grep volumes -A 5
```

### NFS mount issues

**Check mount status:**
```bash
df -h | grep 192.168.10.15
mount | grep nfs
```

**Remount if needed:**
```bash
sudo mount -a
```

**Check NFS exports on TrueNAS:**
```bash
showmount -e 192.168.10.15
```

## Rollback Procedure

If something goes wrong, you can rollback:

### 1. Restore compose files from backup
```bash
# Backup location is printed by update-compose-files.sh
cp -r ~/compose-backup-YYYYMMDD_HHMMSS/* /home/dev/docker/docker-configs/
```

### 2. Restore data (if needed)
```bash
# Use ZFS snapshots on TrueNAS
ssh root@192.168.10.15 "zfs rollback nas-pool/nfs-share/docker@snapshot-name"
```

### 3. Restart services
```bash
cd /home/dev/docker/docker-configs
docker compose -f traefik/docker-compose.yaml up -d
```

## Benefits

After this reorganization:

✓ **Better organization** - Configs, databases, and downloads separated
✓ **Granular snapshots** - Different snapshot schedules for different data types
✓ **Easier backups** - Clear structure for backup strategies
✓ **Scalability** - Easy to add new services
✓ **Maintainability** - Clear separation of concerns
✓ **Already on NFS** - Data persists on TrueNAS (redundant, backed up)

## Next Steps

After successful migration:

1. **Configure TrueNAS snapshots** (see above)
2. **Test snapshot restore procedure**
3. **Set up replication** (if you have second storage)
4. **Monitor performance** with `nfsiostat`
5. **Consider separate datasets** on TrueNAS for even more granular control

## Support

If you encounter issues:

1. Check script output and error messages
2. Verify file permissions and ownership
3. Check Docker logs: `docker compose logs <service>`
4. Verify NFS mounts: `mount | grep nfs`
5. Review backup files before making changes

All scripts create backups before making changes, so rollback is always possible.
