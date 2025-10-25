# TrueNAS Storage Reorganization - Quick Start

## Overview

Your homelab already uses TrueNAS storage via NFS. These scripts will reorganize your existing storage for better organization, snapshots, and maintainability.

## Current Setup ✓

Already configured (no changes needed):
- `/home/dev/docker` ← NFS from `192.168.10.15:/mnt/nas-pool/nfs-share/docker`
- `/media` ← NFS from `192.168.10.15:/mnt/nas-pool/data/media`

## What This Does

Reorganizes your existing NFS storage from:

```
/home/dev/docker/
└── docker-configs/
    ├── traefik/config/
    ├── homepage/config/
    ├── jellyfin/config/
    └── ...
```

To this better structure:

```
/home/dev/docker/
├── docker-configs/      # Git repo
├── appdata/            # All service configs
│   ├── traefik/
│   ├── homepage/
│   ├── jellyfin/
│   └── ...
├── databases/          # Databases (frequent snapshots)
└── downloads/          # Download staging

/media/
├── movies/
├── tv/
├── music/
└── ...
```

## One-Command Migration

```bash
cd /home/dev/docker/docker-configs/scripts
sudo bash master-migration.sh
```

This runs everything automatically:
1. ✓ Creates organized directory structure
2. ✓ Stops Docker services
3. ✓ Migrates data to new locations
4. ✓ Updates docker-compose files
5. ✓ Validates configurations
6. ✓ Provides testing instructions

## What to Expect

**Time:** 15-30 minutes total
**Downtime:** Services stopped during migration
**Safety:** Automatic backups created
**Rollback:** Easy to revert if needed

## After Migration

### 1. Test Services (5 minutes)

```bash
cd /home/dev/docker/docker-configs

# Test Traefik first
docker compose -f traefik/docker-compose.yaml up -d
docker compose logs -f traefik

# If Traefik works, start others
docker compose -f homepage/docker-compose.yaml up -d
docker compose -f jellyfin/compose.yaml up -d
```

### 2. Commit Changes (2 minutes)

```bash
cd /home/dev/docker/docker-configs
git status
git add -u
git commit -m "Reorganize storage: centralized appdata structure"
git push origin main
```

### 3. Configure TrueNAS Snapshots (10 minutes)

Go to TrueNAS Web UI: `http://192.168.10.15`

**Navigation:** Data Protection → Periodic Snapshot Tasks

Create 3 snapshot tasks:

| Dataset | Schedule | Keep | Purpose |
|---------|----------|------|---------|
| `nas-pool/nfs-share/docker` | Hourly | 24 | Service configs |
| `nas-pool/data/media` | Daily 2AM | 7 | Media files |

**Optional:** Create separate datasets for even more granular control:
- `nas-pool/nfs-share/docker/databases` - Every 15 min, keep 8

## Troubleshooting

### Services won't start

```bash
# Check data was copied
ls -la /home/dev/docker/appdata/traefik/config/

# Check permissions
sudo chown -R 1000:1000 /home/dev/docker/appdata
sudo chmod -R 755 /home/dev/docker/appdata
```

### Restore from backup

```bash
# Compose files backup
cp -r ~/compose-backup-YYYYMMDD_HHMMSS/* /home/dev/docker/docker-configs/

# Data backup (use TrueNAS snapshots)
ssh root@192.168.10.15 "zfs list -t snapshot | grep docker"
```

## Benefits

After reorganization:

✓ **Better organization** - Clear separation of configs, databases, downloads
✓ **Granular snapshots** - Different schedules for different data types
✓ **Easier management** - All configs in one place
✓ **Scalable** - Easy to add new services
✓ **Already on TrueNAS** - Data is already redundant and backed up

## Need Help?

Detailed guides:
- `scripts/README.md` - Detailed script documentation
- `docs/TRUENAS-STORAGE-DESIGN.md` - Architecture and design decisions
- `PROGRESS.md` - Project progress tracker

## Step-by-Step Alternative

If you prefer manual control over automated:

```bash
cd /home/dev/docker/docker-configs/scripts

# Step 1: Create directory structure
sudo bash reorganize-existing-storage.sh

# Step 2: Stop all services manually
cd /home/dev/docker/docker-configs
docker compose -f traefik/docker-compose.yaml down
docker compose -f homepage/docker-compose.yaml down
docker compose -f jellyfin/compose.yaml down
docker compose -f servarr/compose.yaml down
docker compose -f rustdesk/docker-compose.yml down

# Step 3: Migrate data (dry run first)
cd /home/dev/docker/docker-configs/scripts
sudo bash migrate-existing-data.sh --dry-run
sudo bash migrate-existing-data.sh

# Step 4: Update compose files
bash update-compose-files.sh

# Step 5: Test
cd /home/dev/docker/docker-configs
docker compose -f traefik/docker-compose.yaml config
docker compose -f traefik/docker-compose.yaml up -d
```

## Ready?

Just run:

```bash
cd /home/dev/docker/docker-configs/scripts
sudo bash master-migration.sh
```

The script will guide you through each step with clear prompts and confirmations.
