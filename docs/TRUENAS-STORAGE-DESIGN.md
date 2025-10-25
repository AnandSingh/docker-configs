# TrueNAS Storage Architecture for Docker Services

## Overview

This document outlines the recommended dataset structure for hosting Docker services on TrueNAS Scale.

**TrueNAS Details:**
- IP: 192.168.10.15
- Pool: `nas-pool`
- Version: TrueNAS Scale

**Docker Host:**
- IP: 192.168.10.13
- User: dev (UID: 1000, GID: 1000)

---

## Dataset Structure

### Recommended Hierarchy

```
nas-pool/
├── docker/                          # Main Docker services root
│   ├── appdata/                     # Application configurations
│   │   ├── traefik/                 # Traefik config, acme.json, logs
│   │   ├── homepage/                # Homepage dashboard config
│   │   ├── jellyfin/                # Jellyfin config only
│   │   ├── jellyseerr/              # Jellyseerr config
│   │   ├── jellystat/               # Jellystat config & DB
│   │   ├── sonarr/                  # Sonarr config
│   │   ├── radarr/                  # Radarr config
│   │   ├── prowlarr/                # Prowlarr config
│   │   ├── bazarr/                  # Bazarr config
│   │   ├── lidarr/                  # Lidarr config
│   │   ├── qbittorrent/             # qBittorrent config
│   │   ├── twingate/                # Twingate connector config
│   │   └── rustdesk/                # RustDesk server data
│   │
│   └── databases/                   # Databases (frequent snapshots)
│       ├── jellyfin/                # Jellyfin library database
│       ├── jellyseerr/              # Jellyseerr database
│       └── jellystat/               # Jellystat database
│
├── media/                           # Media files
│   ├── movies/                      # Movie library
│   ├── tv/                          # TV show library
│   ├── music/                       # Music library
│   ├── books/                       # Audiobooks/ebooks
│   └── photos/                      # Photo library
│
└── downloads/                       # Download staging area
    ├── incomplete/                  # In-progress downloads
    ├── complete/                    # Finished downloads
    └── torrents/                    # Torrent files
```

---

## Migration from Existing Structure

### Current State
- `nas-pool/data/media` (existing)
- `nas-pool/nfs-share/docker` (existing)

### Migration Strategy

**Option 1: Clean restructure (Recommended)**
- Create new `nas-pool/docker/` and `nas-pool/media/` datasets
- Use existing datasets as temporary staging
- Migrate data in phases
- Delete old structure once verified

**Option 2: Reorganize existing**
- Rename `nas-pool/data/media` → `nas-pool/media`
- Rename `nas-pool/nfs-share/docker` → `nas-pool/docker`
- Create child datasets under reorganized parents

---

## Dataset Configuration

### 1. Application Data (nas-pool/docker/appdata)

**Purpose:** Docker service configurations, settings, small databases

**Settings:**
- Compression: `lz4` (fast, good for configs)
- Record Size: `128K` (default, good for mixed workloads)
- Sync: `standard`
- Deduplication: `off`
- ACL Type: `POSIX`
- Case Sensitivity: `sensitive`

**Permissions:**
- Owner: `dev:dev` (1000:1000)
- Mode: `755` (rwxr-xr-x)

**Snapshot Schedule:**
- Hourly: Keep 24
- Daily: Keep 7
- Weekly: Keep 4
- Monthly: Keep 3

**NFS Export:**
```
Path: /mnt/nas-pool/docker/appdata
Hosts: 192.168.10.13
Options: rw,sync,no_subtree_check,no_root_squash
```

---

### 2. Databases (nas-pool/docker/databases)

**Purpose:** Database files requiring frequent snapshots

**Settings:**
- Compression: `lz4`
- Record Size: `8K` (optimized for databases)
- Sync: `always` (data integrity)
- Deduplication: `off`
- ACL Type: `POSIX`
- Atime: `off` (performance)

**Permissions:**
- Owner: `dev:dev` (1000:1000)
- Mode: `755`

**Snapshot Schedule:** (More aggressive)
- Every 15 minutes: Keep 8
- Hourly: Keep 24
- Daily: Keep 7
- Weekly: Keep 4

**NFS Export:**
```
Path: /mnt/nas-pool/docker/databases
Hosts: 192.168.10.13
Options: rw,sync,no_subtree_check,no_root_squash
```

---

### 3. Media Library (nas-pool/media)

**Purpose:** Movies, TV shows, music - mostly read-only after initial write

**Settings:**
- Compression: `lz4` (space savings for video)
- Record Size: `1M` (optimized for large files)
- Sync: `standard`
- Deduplication: `off` (not useful for media)
- ACL Type: `POSIX`

**Permissions:**
- Owner: `dev:dev` (1000:1000)
- Mode: `755`

**Snapshot Schedule:** (Less frequent - media doesn't change often)
- Daily: Keep 7
- Weekly: Keep 4
- Monthly: Keep 6

**NFS Export:**
```
Path: /mnt/nas-pool/media
Hosts: 192.168.10.13
Options: rw,async,no_subtree_check,no_root_squash
```

---

### 4. Downloads (nas-pool/downloads)

**Purpose:** Temporary download staging area

**Settings:**
- Compression: `lz4`
- Record Size: `1M` (large files)
- Sync: `disabled` (performance, data not critical)
- Deduplication: `off`
- Quota: `500G` (prevent runaway downloads)

**Permissions:**
- Owner: `dev:dev` (1000:1000)
- Mode: `755`

**Snapshot Schedule:** (Minimal - temporary data)
- Daily: Keep 2

**NFS Export:**
```
Path: /mnt/nas-pool/downloads
Hosts: 192.168.10.13
Options: rw,async,no_subtree_check,no_root_squash
```

---

## Mount Points on Docker Host (192.168.10.13)

### Create Mount Points
```bash
sudo mkdir -p /mnt/nas/{appdata,databases,media,downloads}
```

### NFS Mounts Configuration

**Add to `/etc/fstab`:**
```fstab
# TrueNAS Docker Storage
192.168.10.15:/mnt/nas-pool/docker/appdata   /mnt/nas/appdata   nfs4  rw,hard,intr,rsize=131072,wsize=131072,timeo=600  0  0
192.168.10.15:/mnt/nas-pool/docker/databases /mnt/nas/databases nfs4  rw,hard,intr,rsize=131072,wsize=131072,timeo=600  0  0
192.168.10.15:/mnt/nas-pool/media            /mnt/nas/media     nfs4  rw,hard,intr,rsize=131072,wsize=131072,timeo=600  0  0
192.168.10.15:/mnt/nas-pool/downloads        /mnt/nas/downloads nfs4  rw,hard,intr,rsize=131072,wsize=131072,timeo=600  0  0
```

**Mount Options Explained:**
- `rw` - Read/write access
- `hard` - Retry NFS operations if server unavailable
- `intr` - Allow interruption of NFS operations
- `rsize=131072` - 128KB read buffer (performance)
- `wsize=131072` - 128KB write buffer (performance)
- `timeo=600` - 60 second timeout before retry

---

## Docker Compose Volume Mappings

### Example: Jellyfin Stack

**Before (Local storage):**
```yaml
volumes:
  - ./config:/config
  - /media:/data
```

**After (TrueNAS storage):**
```yaml
volumes:
  - /mnt/nas/appdata/jellyfin:/config
  - /mnt/nas/media:/data
  - /mnt/nas/databases/jellyfin:/database
```

### Example: Servarr Stack

**After (TrueNAS storage):**
```yaml
sonarr:
  volumes:
    - /mnt/nas/appdata/sonarr:/config
    - /mnt/nas/media/tv:/tv
    - /mnt/nas/downloads:/downloads

radarr:
  volumes:
    - /mnt/nas/appdata/radarr:/config
    - /mnt/nas/media/movies:/movies
    - /mnt/nas/downloads:/downloads

qbittorrent:
  volumes:
    - /mnt/nas/appdata/qbittorrent:/config
    - /mnt/nas/downloads:/downloads
```

### Example: Traefik

**After (TrueNAS storage):**
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro
  - /etc/localtime:/etc/localtime:ro
  - /mnt/nas/appdata/traefik/config/traefik.yml:/etc/traefik/traefik.yml:ro
  - /mnt/nas/appdata/traefik/config/dynamic:/etc/traefik/dynamic:ro
  - /mnt/nas/appdata/traefik/acme.json:/acme.json
  - /mnt/nas/appdata/traefik/logs:/var/log/traefik
```

---

## Replication & Backup Strategy

### Local Snapshots (On nas-pool)

**Retention Policy:**
- Critical data (appdata, databases): Aggressive snapshots
- Media: Less frequent snapshots
- Downloads: Minimal snapshots (2 days)

### Optional: Replication to Second Pool/Server

If you have a second TrueNAS or external storage:

```
nas-pool/docker/appdata    → backup-pool/docker/appdata    (Hourly)
nas-pool/docker/databases  → backup-pool/docker/databases  (Every 15 min)
nas-pool/media             → backup-pool/media             (Daily)
```

### Cloud Backup (Optional)

Consider backing up critical configs to cloud storage:
- Use `rclone` or TrueNAS Cloud Sync
- Encrypt before uploading
- Target: `appdata` and `databases` only (not media - too large)

---

## Implementation Steps

### Phase 1: Create Dataset Structure

```bash
# SSH into TrueNAS or use web UI

# Main datasets
zfs create nas-pool/docker
zfs create nas-pool/docker/appdata
zfs create nas-pool/docker/databases

zfs create nas-pool/media
zfs create nas-pool/media/movies
zfs create nas-pool/media/tv
zfs create nas-pool/media/music
zfs create nas-pool/media/books
zfs create nas-pool/media/photos

zfs create nas-pool/downloads
zfs create nas-pool/downloads/incomplete
zfs create nas-pool/downloads/complete
zfs create nas-pool/downloads/torrents
```

### Phase 2: Configure Dataset Properties

```bash
# Application data
zfs set compression=lz4 nas-pool/docker/appdata
zfs set recordsize=128K nas-pool/docker/appdata

# Databases
zfs set compression=lz4 nas-pool/docker/databases
zfs set recordsize=8K nas-pool/docker/databases
zfs set sync=always nas-pool/docker/databases
zfs set atime=off nas-pool/docker/databases

# Media
zfs set compression=lz4 nas-pool/media
zfs set recordsize=1M nas-pool/media

# Downloads
zfs set compression=lz4 nas-pool/downloads
zfs set recordsize=1M nas-pool/downloads
zfs set quota=500G nas-pool/downloads
```

### Phase 3: Set Permissions

```bash
# Set ownership (adjust UID/GID if needed)
chown -R 1000:1000 /mnt/nas-pool/docker
chown -R 1000:1000 /mnt/nas-pool/media
chown -R 1000:1000 /mnt/nas-pool/downloads

# Set permissions
chmod -R 755 /mnt/nas-pool/docker
chmod -R 755 /mnt/nas-pool/media
chmod -R 755 /mnt/nas-pool/downloads
```

### Phase 4: Create NFS Shares (TrueNAS Web UI)

Navigate to **Sharing → NFS** and create:

1. **Appdata Share**
   - Path: `/mnt/nas-pool/docker/appdata`
   - Authorized Networks: `192.168.10.13`
   - Maproot User: `dev`
   - Maproot Group: `dev`

2. **Databases Share**
   - Path: `/mnt/nas-pool/docker/databases`
   - Authorized Networks: `192.168.10.13`
   - Maproot User: `dev`
   - Maproot Group: `dev`

3. **Media Share**
   - Path: `/mnt/nas-pool/media`
   - Authorized Networks: `192.168.10.13`
   - Maproot User: `dev`
   - Maproot Group: `dev`

4. **Downloads Share**
   - Path: `/mnt/nas-pool/downloads`
   - Authorized Networks: `192.168.10.13`
   - Maproot User: `dev`
   - Maproot Group: `dev`

### Phase 5: Configure Snapshots (TrueNAS Web UI)

Navigate to **Data Protection → Periodic Snapshot Tasks**:

**Appdata Snapshots:**
- Dataset: `nas-pool/docker/appdata`
- Recursive: Yes
- Schedule: Hourly
- Lifetime: 24 hours

**Database Snapshots:**
- Dataset: `nas-pool/docker/databases`
- Recursive: Yes
- Schedule: Every 15 minutes
- Lifetime: 2 hours

**Media Snapshots:**
- Dataset: `nas-pool/media`
- Recursive: Yes
- Schedule: Daily at 2 AM
- Lifetime: 7 days

---

## Data Migration Plan

### Step 1: Backup Current State
```bash
# On Docker host (192.168.10.13)
cd /home/dev/docker/docker-configs
sudo tar -czf ~/docker-backup-$(date +%Y%m%d).tar.gz traefik/ homepage/ jellyfin/ servarr/ rustdesk/
```

### Step 2: Stop Services
```bash
cd /home/dev/docker/docker-configs
docker compose -f traefik/docker-compose.yaml down
docker compose -f homepage/docker-compose.yaml down
docker compose -f jellyfin/compose.yaml down
docker compose -f servarr/compose.yaml down
```

### Step 3: Mount NFS Shares
```bash
# Test mount first
sudo mount -t nfs4 192.168.10.15:/mnt/nas-pool/docker/appdata /mnt/nas/appdata

# If successful, add to /etc/fstab and mount all
sudo mount -a
```

### Step 4: Copy Data to TrueNAS
```bash
# Copy Traefik config
sudo rsync -av /home/dev/docker/docker-configs/traefik/config/ /mnt/nas/appdata/traefik/config/
sudo rsync -av /home/dev/docker/docker-configs/traefik/logs/ /mnt/nas/appdata/traefik/logs/

# Copy Homepage config
sudo rsync -av /home/dev/docker/docker-configs/homepage/config/ /mnt/nas/appdata/homepage/

# Copy Jellyfin config
sudo rsync -av /home/dev/docker/docker-configs/jellyfin/config/ /mnt/nas/appdata/jellyfin/

# Copy Servarr configs
sudo rsync -av /home/dev/docker/docker-configs/servarr/sonarr/ /mnt/nas/appdata/sonarr/
sudo rsync -av /home/dev/docker/docker-configs/servarr/radarr/ /mnt/nas/appdata/radarr/
# ... repeat for other Servarr services
```

### Step 5: Update Docker Compose Files

Update all volume paths in docker-compose files (covered in next phase).

### Step 6: Test Services
```bash
# Start services one by one and verify
docker compose -f traefik/docker-compose.yaml up -d
docker compose logs -f traefik

# Once verified, start remaining services
```

---

## Verification Checklist

- [ ] All datasets created on TrueNAS
- [ ] Dataset properties configured (compression, recordsize, etc.)
- [ ] Permissions set correctly (1000:1000)
- [ ] NFS shares created and accessible
- [ ] NFS mounts working on Docker host
- [ ] Mounts added to /etc/fstab for persistence
- [ ] Data migrated successfully
- [ ] Docker compose files updated
- [ ] All services start and function correctly
- [ ] Snapshot tasks configured
- [ ] Test snapshot restore procedure

---

## Troubleshooting

### Issue: NFS mount fails with "access denied"
**Solution:** Check TrueNAS NFS service is running and shares are configured with correct network/host.

### Issue: Permission denied when writing to NFS mount
**Solution:** Verify maproot user/group matches Docker host UID/GID (1000:1000).

### Issue: Poor NFS performance
**Solution:**
- Increase rsize/wsize in mount options
- Enable jumbo frames on network (MTU 9000)
- Use direct network connection (1Gbps minimum, 10Gbps recommended)

### Issue: Services fail to start after migration
**Solution:**
- Check file paths in docker-compose files
- Verify files copied completely with `rsync -av --dry-run`
- Check Docker container logs for specific errors

---

## Performance Optimization

### Network Configuration
- Use dedicated NIC for NFS traffic if possible
- Enable jumbo frames (MTU 9000) on both TrueNAS and Docker host
- Consider 10Gbps network for large media library

### TrueNAS Tuning
- Add more RAM for ARC cache (improves read performance)
- Use L2ARC (SSD cache) for frequently accessed data
- Consider special vdev (metadata SSD) for improved small file performance

### Docker Host Tuning
- Install `nfs-common` package
- Tune NFS mount options based on workload
- Monitor NFS stats with `nfsstat` and `nfsiostat`

---

## Next Steps

1. **Review this design** - Make sure it fits your needs
2. **Create datasets on TrueNAS** - Follow Phase 1-5 implementation steps
3. **Test NFS mounts** - Verify connectivity and permissions
4. **Update docker-compose files** - Change volume paths
5. **Migrate data** - Copy existing data to TrueNAS
6. **Test services** - Verify everything works
7. **Configure snapshots** - Set up automated backups
8. **Document restore procedure** - Test recovering from snapshots
