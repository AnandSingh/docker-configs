#!/bin/bash
# TrueNAS Dataset Setup Script
# Run this on TrueNAS Scale (192.168.10.15)
# Usage: bash truenas-setup.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
POOL_NAME="nas-pool"
DOCKER_UID=1000
DOCKER_GID=1000
DOCKER_USER="dev"
DOCKER_HOST="192.168.10.13"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}TrueNAS Dataset Setup for Docker${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

# Check if pool exists
if ! zfs list "$POOL_NAME" >/dev/null 2>&1; then
    echo -e "${RED}Error: Pool '$POOL_NAME' not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Pool '$POOL_NAME' found"
echo ""

# Create main datasets
echo -e "${BLUE}Creating dataset structure...${NC}"

datasets=(
    # Main structure
    "$POOL_NAME/docker"
    "$POOL_NAME/docker/appdata"
    "$POOL_NAME/docker/databases"

    # Service-specific appdata
    "$POOL_NAME/docker/appdata/traefik"
    "$POOL_NAME/docker/appdata/homepage"
    "$POOL_NAME/docker/appdata/jellyfin"
    "$POOL_NAME/docker/appdata/jellyseerr"
    "$POOL_NAME/docker/appdata/jellystat"
    "$POOL_NAME/docker/appdata/sonarr"
    "$POOL_NAME/docker/appdata/radarr"
    "$POOL_NAME/docker/appdata/prowlarr"
    "$POOL_NAME/docker/appdata/bazarr"
    "$POOL_NAME/docker/appdata/lidarr"
    "$POOL_NAME/docker/appdata/qbittorrent"
    "$POOL_NAME/docker/appdata/twingate"
    "$POOL_NAME/docker/appdata/rustdesk"

    # Databases
    "$POOL_NAME/docker/databases/jellyfin"
    "$POOL_NAME/docker/databases/jellyseerr"
    "$POOL_NAME/docker/databases/jellystat"

    # Media structure
    "$POOL_NAME/media/movies"
    "$POOL_NAME/media/tv"
    "$POOL_NAME/media/music"
    "$POOL_NAME/media/books"
    "$POOL_NAME/media/photos"

    # Downloads
    "$POOL_NAME/downloads"
    "$POOL_NAME/downloads/incomplete"
    "$POOL_NAME/downloads/complete"
    "$POOL_NAME/downloads/torrents"
)

for dataset in "${datasets[@]}"; do
    if zfs list "$dataset" >/dev/null 2>&1; then
        echo -e "${YELLOW}⊙${NC} $dataset already exists, skipping..."
    else
        echo -e "${GREEN}+${NC} Creating $dataset"
        zfs create "$dataset"
    fi
done

echo ""
echo -e "${BLUE}Configuring dataset properties...${NC}"

# Configure appdata dataset
echo -e "${GREEN}⚙${NC} Configuring appdata..."
zfs set compression=lz4 "$POOL_NAME/docker/appdata"
zfs set recordsize=128K "$POOL_NAME/docker/appdata"
zfs set atime=off "$POOL_NAME/docker/appdata"

# Configure databases dataset
echo -e "${GREEN}⚙${NC} Configuring databases..."
zfs set compression=lz4 "$POOL_NAME/docker/databases"
zfs set recordsize=8K "$POOL_NAME/docker/databases"
zfs set sync=always "$POOL_NAME/docker/databases"
zfs set atime=off "$POOL_NAME/docker/databases"
zfs set logbias=throughput "$POOL_NAME/docker/databases"

# Configure media dataset
echo -e "${GREEN}⚙${NC} Configuring media..."
zfs set compression=lz4 "$POOL_NAME/media"
zfs set recordsize=1M "$POOL_NAME/media"
zfs set atime=off "$POOL_NAME/media"

# Configure downloads dataset
echo -e "${GREEN}⚙${NC} Configuring downloads..."
zfs set compression=lz4 "$POOL_NAME/downloads"
zfs set recordsize=1M "$POOL_NAME/downloads"
zfs set quota=500G "$POOL_NAME/downloads"
zfs set atime=off "$POOL_NAME/downloads"

echo ""
echo -e "${BLUE}Setting permissions...${NC}"

# Set ownership
chown -R $DOCKER_UID:$DOCKER_GID "/mnt/$POOL_NAME/docker"
chown -R $DOCKER_UID:$DOCKER_GID "/mnt/$POOL_NAME/media"
chown -R $DOCKER_UID:$DOCKER_GID "/mnt/$POOL_NAME/downloads"

# Set permissions
chmod -R 755 "/mnt/$POOL_NAME/docker"
chmod -R 755 "/mnt/$POOL_NAME/media"
chmod -R 755 "/mnt/$POOL_NAME/downloads"

echo -e "${GREEN}✓${NC} Permissions set (UID:GID = $DOCKER_UID:$DOCKER_GID)"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Dataset Creation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Configure NFS shares in TrueNAS Web UI:"
echo "   - Go to: Sharing → Unix Shares (NFS)"
echo "   - Or run: bash truenas-nfs-setup.sh"
echo ""
echo "2. Then on Docker host ($DOCKER_HOST):"
echo "   - Run: bash docker-host-setup.sh"
echo ""
echo -e "${BLUE}Dataset Summary:${NC}"
zfs list -r "$POOL_NAME/docker" "$POOL_NAME/media" "$POOL_NAME/downloads" | grep -E "NAME|docker|media|downloads"
