#!/bin/bash
# Migrate Existing Data Within Current NFS Mounts
# Run this on Docker host (192.168.10.13) after reorganize-existing-storage.sh
#
# This moves data from docker-configs subdirectories to the new organized structure

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOCKER_MOUNT="/home/dev/docker"
DOCKER_CONFIGS="$DOCKER_MOUNT/docker-configs"
DRY_RUN=false

# Parse arguments
if [ "$1" == "--dry-run" ]; then
    DRY_RUN=true
    echo -e "${YELLOW}DRY RUN MODE - No data will be moved${NC}"
    echo ""
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Migrate Existing Data${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

# Check if new structure exists
if [ ! -d "$DOCKER_MOUNT/appdata" ]; then
    echo -e "${RED}Error: New directory structure not found${NC}"
    echo "Run: bash reorganize-existing-storage.sh first"
    exit 1
fi

# Warning
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}IMPORTANT: Stop Docker services first${NC}"
echo -e "${YELLOW}========================================${NC}"
read -p "Have you stopped all Docker services? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Please stop services first:"
    echo "  cd $DOCKER_CONFIGS"
    echo "  docker compose -f traefik/docker-compose.yaml down"
    echo "  docker compose -f homepage/docker-compose.yaml down"
    echo "  docker compose -f jellyfin/compose.yaml down"
    echo "  docker compose -f servarr/compose.yaml down"
    echo "  docker compose -f rustdesk/docker-compose.yml down"
    echo ""
    exit 1
fi
echo ""

# Migration function
move_data() {
    local source=$1
    local dest=$2
    local description=$3

    if [ ! -e "$source" ]; then
        echo -e "${YELLOW}⊙${NC} $description: Source not found, skipping..."
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}⊙${NC} Would move: $source → $dest"
        du -sh "$source" 2>/dev/null | awk '{print "  Size: " $1}'
    else
        echo -e "${BLUE}Moving $description...${NC}"
        rsync -a --remove-source-files "$source/" "$dest/"
        # Remove empty source directory
        find "$source" -type d -empty -delete 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Moved $description"
    fi
}

echo -e "${BLUE}Starting migration...${NC}"
echo ""

# Traefik
echo -e "${YELLOW}[1/8] Traefik${NC}"
move_data "$DOCKER_CONFIGS/traefik/config" \
    "$DOCKER_MOUNT/appdata/traefik/config" \
    "Traefik config"

move_data "$DOCKER_CONFIGS/traefik/logs" \
    "$DOCKER_MOUNT/appdata/traefik/logs" \
    "Traefik logs"
echo ""

# Homepage
echo -e "${YELLOW}[2/8] Homepage${NC}"
move_data "$DOCKER_CONFIGS/homepage/config" \
    "$DOCKER_MOUNT/appdata/homepage" \
    "Homepage config"
echo ""

# Jellyfin
echo -e "${YELLOW}[3/8] Jellyfin${NC}"
move_data "$DOCKER_CONFIGS/jellyfin/config" \
    "$DOCKER_MOUNT/appdata/jellyfin" \
    "Jellyfin config"
echo ""

# Jellyseerr
echo -e "${YELLOW}[4/8] Jellyseerr${NC}"
move_data "$DOCKER_CONFIGS/jellyfin/jellyseerr" \
    "$DOCKER_MOUNT/appdata/jellyseerr" \
    "Jellyseerr config"
echo ""

# Jellystat
echo -e "${YELLOW}[5/8] Jellystat${NC}"
move_data "$DOCKER_CONFIGS/jellyfin/jellystat" \
    "$DOCKER_MOUNT/appdata/jellystat" \
    "Jellystat config"
echo ""

# Servarr services
echo -e "${YELLOW}[6/8] Servarr Stack${NC}"
for service in sonarr radarr prowlarr bazarr lidarr qbittorrent; do
    if [ -d "$DOCKER_CONFIGS/servarr/$service" ]; then
        move_data "$DOCKER_CONFIGS/servarr/$service" \
            "$DOCKER_MOUNT/appdata/$service" \
            "$service config"
    fi
done
echo ""

# Twingate
echo -e "${YELLOW}[7/8] Twingate${NC}"
if [ -d "$DOCKER_CONFIGS/twingate/data" ]; then
    move_data "$DOCKER_CONFIGS/twingate/data" \
        "$DOCKER_MOUNT/appdata/twingate" \
        "Twingate config"
fi
echo ""

# RustDesk
echo -e "${YELLOW}[8/8] RustDesk${NC}"
if [ -d "$DOCKER_CONFIGS/rustdesk/data" ]; then
    move_data "$DOCKER_CONFIGS/rustdesk/data" \
        "$DOCKER_MOUNT/appdata/rustdesk" \
        "RustDesk data"
fi
echo ""

# Fix permissions
if [ "$DRY_RUN" = false ]; then
    echo -e "${BLUE}Setting correct permissions...${NC}"
    chown -R 1000:1000 "$DOCKER_MOUNT/appdata"
    chown -R 1000:1000 "$DOCKER_MOUNT/databases"
    chmod -R 755 "$DOCKER_MOUNT/appdata"
    chmod -R 755 "$DOCKER_MOUNT/databases"
    echo -e "${GREEN}✓${NC} Permissions set"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Migration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}This was a DRY RUN. No data was moved.${NC}"
    echo -e "${YELLOW}Run without --dry-run to perform actual migration.${NC}"
else
    echo -e "${BLUE}Data Location:${NC}"
    echo "  Service configs: $DOCKER_MOUNT/appdata/"
    echo "  Databases:       $DOCKER_MOUNT/databases/"
    echo "  Downloads:       $DOCKER_MOUNT/downloads/"
    echo "  Media:           /media/"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Verify data was moved correctly:"
    echo "   ls -la $DOCKER_MOUNT/appdata/"
    echo ""
    echo "2. Update docker-compose files:"
    echo "   bash update-compose-files.sh"
    echo ""
    echo "3. Test services:"
    echo "   cd $DOCKER_CONFIGS"
    echo "   docker compose -f traefik/docker-compose.yaml up -d"
    echo "   docker compose logs -f traefik"
fi
