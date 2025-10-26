#!/bin/bash
# Data Migration Script - Local Storage to TrueNAS
# Run this on Docker host (192.168.10.13) after NFS mounts are configured
# Usage: bash migrate-to-truenas.sh [--dry-run]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOCKER_CONFIGS_DIR="/home/dev/docker/docker-configs"
MOUNT_BASE="/mnt/nas"
DRY_RUN=false

# Parse arguments
if [ "$1" == "--dry-run" ]; then
    DRY_RUN=true
    echo -e "${YELLOW}DRY RUN MODE - No data will be copied${NC}"
    echo ""
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Data Migration to TrueNAS${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

# Verify NFS mounts
echo -e "${BLUE}Verifying NFS mounts...${NC}"
for mount in appdata databases media downloads; do
    if mountpoint -q "$MOUNT_BASE/$mount"; then
        echo -e "${GREEN}✓${NC} $MOUNT_BASE/$mount is mounted"
    else
        echo -e "${RED}Error: $MOUNT_BASE/$mount is not mounted${NC}"
        echo "Run: bash docker-host-setup.sh first"
        exit 1
    fi
done
echo ""

# Create backup before migration
echo -e "${BLUE}Creating backup of current state...${NC}"
BACKUP_DIR="$HOME/docker-backup-$(date +%Y%m%d_%H%M%S)"
if [ "$DRY_RUN" = false ]; then
    mkdir -p "$BACKUP_DIR"
    cd "$DOCKER_CONFIGS_DIR"
    tar -czf "$BACKUP_DIR/docker-configs-backup.tar.gz" \
        traefik/config traefik/logs \
        homepage/config \
        jellyfin/config \
        2>/dev/null || true
    echo -e "${GREEN}✓${NC} Backup created at $BACKUP_DIR"
else
    echo -e "${YELLOW}⊙${NC} Skipping backup (dry run)"
fi
echo ""

# Stop Docker services
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}IMPORTANT: Stop Docker services first${NC}"
echo -e "${YELLOW}========================================${NC}"
read -p "Have you stopped all Docker services? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Please stop services first:"
    echo "  cd $DOCKER_CONFIGS_DIR"
    echo "  docker compose -f traefik/docker-compose.yaml down"
    echo "  docker compose -f homepage/docker-compose.yaml down"
    echo "  docker compose -f jellyfin/compose.yaml down"
    echo "  docker compose -f servarr/compose.yaml down"
    echo ""
    exit 1
fi
echo ""

# Migration functions
migrate_service() {
    local service_name=$1
    local source_path=$2
    local dest_path=$3
    local description=$4

    echo -e "${BLUE}Migrating ${description}...${NC}"

    if [ ! -d "$source_path" ] && [ ! -f "$source_path" ]; then
        echo -e "${YELLOW}⊙${NC} Source not found: $source_path, skipping..."
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}⊙${NC} Would copy: $source_path → $dest_path"
        if [ -d "$source_path" ]; then
            du -sh "$source_path" 2>/dev/null || echo "  (size unknown)"
        fi
    else
        mkdir -p "$(dirname "$dest_path")"
        rsync -av --progress "$source_path/" "$dest_path/" 2>/dev/null || rsync -av --progress "$source_path" "$dest_path" 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Migrated $description"
    fi
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Starting Migration${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Traefik
echo -e "${YELLOW}[1/8] Traefik${NC}"
migrate_service "traefik" \
    "$DOCKER_CONFIGS_DIR/traefik/config" \
    "$MOUNT_BASE/appdata/traefik/config" \
    "Traefik config"

migrate_service "traefik" \
    "$DOCKER_CONFIGS_DIR/traefik/logs" \
    "$MOUNT_BASE/appdata/traefik/logs" \
    "Traefik logs"

# Copy acme.json separately (important file)
if [ -f "$DOCKER_CONFIGS_DIR/traefik/config/acme.json" ]; then
    if [ "$DRY_RUN" = false ]; then
        cp -p "$DOCKER_CONFIGS_DIR/traefik/config/acme.json" "$MOUNT_BASE/appdata/traefik/config/"
        chmod 600 "$MOUNT_BASE/appdata/traefik/config/acme.json"
    fi
    echo -e "${GREEN}✓${NC} Copied acme.json with permissions"
fi
echo ""

# Homepage
echo -e "${YELLOW}[2/8] Homepage${NC}"
migrate_service "homepage" \
    "$DOCKER_CONFIGS_DIR/homepage/config" \
    "$MOUNT_BASE/appdata/homepage" \
    "Homepage config"
echo ""

# Jellyfin
echo -e "${YELLOW}[3/8] Jellyfin${NC}"
migrate_service "jellyfin" \
    "$DOCKER_CONFIGS_DIR/jellyfin/config" \
    "$MOUNT_BASE/appdata/jellyfin" \
    "Jellyfin config"
echo ""

# Jellyseerr
echo -e "${YELLOW}[4/8] Jellyseerr${NC}"
migrate_service "jellyseerr" \
    "$DOCKER_CONFIGS_DIR/jellyfin/jellyseerr" \
    "$MOUNT_BASE/appdata/jellyseerr" \
    "Jellyseerr config"
echo ""

# Jellystat
echo -e "${YELLOW}[5/8] Jellystat${NC}"
migrate_service "jellystat" \
    "$DOCKER_CONFIGS_DIR/jellyfin/jellystat" \
    "$MOUNT_BASE/appdata/jellystat" \
    "Jellystat config"
echo ""

# Servarr services
echo -e "${YELLOW}[6/8] Servarr Stack${NC}"
for service in sonarr radarr prowlarr bazarr lidarr qbittorrent; do
    if [ -d "$DOCKER_CONFIGS_DIR/servarr/$service" ]; then
        migrate_service "$service" \
            "$DOCKER_CONFIGS_DIR/servarr/$service" \
            "$MOUNT_BASE/appdata/$service" \
            "$service config"
    fi
done
echo ""

# Twingate
echo -e "${YELLOW}[7/8] Twingate${NC}"
migrate_service "twingate" \
    "$DOCKER_CONFIGS_DIR/twingate/data" \
    "$MOUNT_BASE/appdata/twingate" \
    "Twingate config"
echo ""

# RustDesk
echo -e "${YELLOW}[8/8] RustDesk${NC}"
migrate_service "rustdesk" \
    "$DOCKER_CONFIGS_DIR/rustdesk/data" \
    "$MOUNT_BASE/appdata/rustdesk" \
    "RustDesk data"
echo ""

# Set correct permissions
if [ "$DRY_RUN" = false ]; then
    echo -e "${BLUE}Setting correct permissions...${NC}"
    chown -R 1000:1000 "$MOUNT_BASE/appdata"
    chown -R 1000:1000 "$MOUNT_BASE/databases"
    echo -e "${GREEN}✓${NC} Permissions set"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Migration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}This was a DRY RUN. No data was copied.${NC}"
    echo -e "${YELLOW}Run without --dry-run to perform actual migration.${NC}"
    echo ""
else
    echo -e "${BLUE}Migration Summary:${NC}"
    echo "  Backup: $BACKUP_DIR"
    echo "  Data migrated to: $MOUNT_BASE/appdata"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Verify data was copied correctly:"
    echo "   ls -la $MOUNT_BASE/appdata/"
    echo ""
    echo "2. Update docker-compose files:"
    echo "   bash update-compose-files.sh"
    echo ""
    echo "3. Start services with new storage:"
    echo "   cd $DOCKER_CONFIGS_DIR"
    echo "   docker compose -f traefik/docker-compose.yaml up -d"
    echo ""
    echo "4. If everything works, you can delete old local data"
    echo "   (Keep backup for a few days first!)"
fi
