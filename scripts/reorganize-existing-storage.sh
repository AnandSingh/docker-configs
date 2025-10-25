#!/bin/bash
# Storage Reorganization Script - Work with Existing NFS Mounts
# Run this on Docker host (192.168.10.13)
#
# Current mounts:
#   /home/dev/docker ← 192.168.10.15:/mnt/nas-pool/nfs-share/docker
#   /media           ← 192.168.10.15:/mnt/nas-pool/data/media
#
# This script reorganizes your existing NFS storage for better organization

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOCKER_MOUNT="/home/dev/docker"
MEDIA_MOUNT="/media"
DOCKER_CONFIGS="$DOCKER_MOUNT/docker-configs"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Storage Reorganization${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

echo -e "${BLUE}Current Setup:${NC}"
echo "  Docker mount: $DOCKER_MOUNT"
echo "  Media mount:  $MEDIA_MOUNT"
echo "  Config dir:   $DOCKER_CONFIGS"
echo ""

# Verify mounts
echo -e "${BLUE}Verifying mounts...${NC}"
if mountpoint -q "$DOCKER_MOUNT"; then
    echo -e "${GREEN}✓${NC} $DOCKER_MOUNT is mounted (NFS)"
else
    echo -e "${RED}Error: $DOCKER_MOUNT is not mounted${NC}"
    exit 1
fi

if mountpoint -q "$MEDIA_MOUNT"; then
    echo -e "${GREEN}✓${NC} $MEDIA_MOUNT is mounted (NFS)"
else
    echo -e "${RED}Error: $MEDIA_MOUNT is not mounted${NC}"
    exit 1
fi
echo ""

echo -e "${YELLOW}Good news: Your data is already on TrueNAS!${NC}"
echo ""
echo -e "${BLUE}Proposed Reorganization:${NC}"
echo ""
echo "Within $DOCKER_MOUNT (nas-pool/nfs-share/docker):"
echo "  docker-configs/           # Git repository (current)"
echo "  appdata/                  # Service configs (NEW)"
echo "    ├── traefik/"
echo "    ├── homepage/"
echo "    ├── jellyfin/"
echo "    └── ..."
echo "  databases/                # Databases (NEW)"
echo "  downloads/                # Download staging (NEW)"
echo ""
echo "Within $MEDIA_MOUNT (nas-pool/data/media):"
echo "  movies/                   # Organized media"
echo "  tv/"
echo "  music/"
echo "  books/"
echo "  photos/"
echo ""

read -p "Proceed with reorganization? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Create new directory structure
echo -e "${BLUE}Creating directory structure...${NC}"

# Docker mount structure
mkdir -p "$DOCKER_MOUNT"/{appdata,databases,downloads}
mkdir -p "$DOCKER_MOUNT/downloads"/{incomplete,complete,torrents}

# Service-specific directories
for service in traefik homepage jellyfin jellyseerr jellystat sonarr radarr prowlarr bazarr lidarr qbittorrent twingate rustdesk; do
    mkdir -p "$DOCKER_MOUNT/appdata/$service"
done

mkdir -p "$DOCKER_MOUNT/databases"/{jellyfin,jellyseerr,jellystat}

# Media structure
for category in movies tv music books photos; do
    mkdir -p "$MEDIA_MOUNT/$category"
done

echo -e "${GREEN}✓${NC} Directory structure created"

# Set permissions
echo -e "${BLUE}Setting permissions...${NC}"
chown -R 1000:1000 "$DOCKER_MOUNT/appdata"
chown -R 1000:1000 "$DOCKER_MOUNT/databases"
chown -R 1000:1000 "$DOCKER_MOUNT/downloads"
chown -R 1000:1000 "$MEDIA_MOUNT"

chmod -R 755 "$DOCKER_MOUNT/appdata"
chmod -R 755 "$DOCKER_MOUNT/databases"
chmod -R 755 "$DOCKER_MOUNT/downloads"
chmod -R 755 "$MEDIA_MOUNT"

echo -e "${GREEN}✓${NC} Permissions set"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Reorganization Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}New Structure:${NC}"
tree -L 2 "$DOCKER_MOUNT" 2>/dev/null || ls -la "$DOCKER_MOUNT"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Move existing service data to new locations:"
echo "   bash migrate-existing-data.sh"
echo ""
echo "2. Update docker-compose files to use new paths:"
echo "   bash update-compose-files.sh"
echo ""
echo "3. Configure TrueNAS snapshots for new structure"
echo ""
echo -e "${BLUE}Benefits of this structure:${NC}"
echo "  ✓ Separation of configs, databases, and downloads"
echo "  ✓ Better snapshot strategies per data type"
echo "  ✓ Easier to manage and backup"
echo "  ✓ Organized media library"
