#!/bin/bash
# Update Docker Compose Files for New Storage Structure
# Run this on Docker host (192.168.10.13) after data migration
#
# This script updates volume paths in all docker-compose files

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
BACKUP_DIR="$HOME/compose-backup-$(date +%Y%m%d_%H%M%S)"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Update Docker Compose Files${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Create backup
echo -e "${BLUE}Creating backup of compose files...${NC}"
mkdir -p "$BACKUP_DIR"

find "$DOCKER_CONFIGS" -name "docker-compose.y*ml" -o -name "compose.y*ml" | while read -r file; do
    relative_path="${file#$DOCKER_CONFIGS/}"
    backup_file="$BACKUP_DIR/$relative_path"
    mkdir -p "$(dirname "$backup_file")"
    cp "$file" "$backup_file"
done

echo -e "${GREEN}✓${NC} Backup created at: $BACKUP_DIR"
echo ""

echo -e "${BLUE}Updating compose files...${NC}"
echo ""

# Function to update a compose file
update_compose() {
    local file=$1
    local service_name=$2

    echo -e "${YELLOW}Updating: $service_name${NC}"

    if [ ! -f "$file" ]; then
        echo -e "${RED}  File not found: $file${NC}"
        return 1
    fi

    # Create a temporary file
    local tmp_file="${file}.tmp"
    cp "$file" "$tmp_file"

    # Show what will change
    echo -e "${BLUE}  Changes:${NC}"

    # Apply updates based on service
    case "$service_name" in
        traefik)
            # Update Traefik paths
            sed -i 's|./config/traefik.yml:/etc/traefik/traefik.yml|'$DOCKER_MOUNT'/appdata/traefik/config/traefik.yml:/etc/traefik/traefik.yml|g' "$tmp_file"
            sed -i 's|./config/dynamic:/etc/traefik/dynamic|'$DOCKER_MOUNT'/appdata/traefik/config/dynamic:/etc/traefik/dynamic|g' "$tmp_file"
            sed -i 's|./config/acme.json:/acme.json|'$DOCKER_MOUNT'/appdata/traefik/config/acme.json:/acme.json|g' "$tmp_file"
            sed -i 's|./logs:/var/log/traefik|'$DOCKER_MOUNT'/appdata/traefik/logs:/var/log/traefik|g' "$tmp_file"
            echo -e "    ${GREEN}✓${NC} Traefik config → $DOCKER_MOUNT/appdata/traefik"
            ;;

        homepage)
            # Update Homepage paths
            sed -i 's|./config:/app/config|'$DOCKER_MOUNT'/appdata/homepage:/app/config|g' "$tmp_file"
            echo -e "    ${GREEN}✓${NC} Homepage config → $DOCKER_MOUNT/appdata/homepage"
            ;;

        jellyfin)
            # Update Jellyfin paths
            sed -i 's|./config:/config|'$DOCKER_MOUNT'/appdata/jellyfin:/config|g' "$tmp_file"
            sed -i 's|/media:/data|'$MEDIA_MOUNT':/data|g' "$tmp_file"

            # Update Jellyseerr
            sed -i 's|./jellyseerr:/app/config|'$DOCKER_MOUNT'/appdata/jellyseerr:/app/config|g' "$tmp_file"

            # Update Jellystat
            sed -i 's|./jellystat/backup-data:/app/backend/backup-data|'$DOCKER_MOUNT'/appdata/jellystat/backup-data:/app/backend/backup-data|g' "$tmp_file"
            sed -i 's|./jellystat\.db:/app/backend/data/jellystat\.db|'$DOCKER_MOUNT'/databases/jellystat/jellystat.db:/app/backend/data/jellystat.db|g' "$tmp_file"

            echo -e "    ${GREEN}✓${NC} Jellyfin → $DOCKER_MOUNT/appdata/jellyfin"
            echo -e "    ${GREEN}✓${NC} Media → $MEDIA_MOUNT"
            echo -e "    ${GREEN}✓${NC} Jellyseerr → $DOCKER_MOUNT/appdata/jellyseerr"
            echo -e "    ${GREEN}✓${NC} Jellystat → $DOCKER_MOUNT/appdata/jellystat"
            ;;

        servarr)
            # Update Servarr paths
            sed -i 's|./sonarr:/config|'$DOCKER_MOUNT'/appdata/sonarr:/config|g' "$tmp_file"
            sed -i 's|./radarr:/config|'$DOCKER_MOUNT'/appdata/radarr:/config|g' "$tmp_file"
            sed -i 's|./prowlarr:/config|'$DOCKER_MOUNT'/appdata/prowlarr:/config|g' "$tmp_file"
            sed -i 's|./bazarr:/config|'$DOCKER_MOUNT'/appdata/bazarr:/config|g' "$tmp_file"
            sed -i 's|./lidarr:/config|'$DOCKER_MOUNT'/appdata/lidarr:/config|g' "$tmp_file"
            sed -i 's|./qbittorrent:/config|'$DOCKER_MOUNT'/appdata/qbittorrent:/config|g' "$tmp_file"

            # Update media paths
            sed -i 's|/media:/media|'$MEDIA_MOUNT':/media|g' "$tmp_file"

            # Update downloads paths (if they exist)
            sed -i 's|/downloads:/downloads|'$DOCKER_MOUNT'/downloads:/downloads|g' "$tmp_file"

            echo -e "    ${GREEN}✓${NC} Servarr configs → $DOCKER_MOUNT/appdata/"
            echo -e "    ${GREEN}✓${NC} Media → $MEDIA_MOUNT"
            echo -e "    ${GREEN}✓${NC} Downloads → $DOCKER_MOUNT/downloads"
            ;;

        rustdesk)
            # Update RustDesk paths
            sed -i 's|./data:/root|'$DOCKER_MOUNT'/appdata/rustdesk:/root|g' "$tmp_file"
            echo -e "    ${GREEN}✓${NC} RustDesk → $DOCKER_MOUNT/appdata/rustdesk"
            ;;

        twingate)
            # Update Twingate paths (if it has any volumes)
            sed -i 's|./data:/etc/twingate|'$DOCKER_MOUNT'/appdata/twingate:/etc/twingate|g' "$tmp_file"
            echo -e "    ${GREEN}✓${NC} Twingate → $DOCKER_MOUNT/appdata/twingate"
            ;;
    esac

    # Check if file actually changed
    if ! diff -q "$file" "$tmp_file" > /dev/null 2>&1; then
        mv "$tmp_file" "$file"
        echo -e "  ${GREEN}✓${NC} File updated"
    else
        rm "$tmp_file"
        echo -e "  ${YELLOW}⊙${NC} No changes needed"
    fi

    echo ""
}

# Update each service
update_compose "$DOCKER_CONFIGS/traefik/docker-compose.yaml" "traefik"
update_compose "$DOCKER_CONFIGS/homepage/docker-compose.yaml" "homepage"
update_compose "$DOCKER_CONFIGS/jellyfin/compose.yaml" "jellyfin"
update_compose "$DOCKER_CONFIGS/servarr/compose.yaml" "servarr"
update_compose "$DOCKER_CONFIGS/rustdesk/docker-compose.yml" "rustdesk"
update_compose "$DOCKER_CONFIGS/twingate/docker-compose.yaml" "twingate"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Compose Files Updated!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Backup Location:${NC} $BACKUP_DIR"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Review the changes:"
echo "   cd $DOCKER_CONFIGS"
echo "   git diff"
echo ""
echo "2. Validate compose files:"
echo "   docker compose -f traefik/docker-compose.yaml config"
echo "   docker compose -f homepage/docker-compose.yaml config"
echo "   docker compose -f jellyfin/compose.yaml config"
echo ""
echo "3. Start services one by one:"
echo "   docker compose -f traefik/docker-compose.yaml up -d"
echo "   docker compose logs -f traefik"
echo ""
echo "4. Once verified, commit changes:"
echo "   git add -u"
echo "   git commit -m \"Update volume paths for organized TrueNAS storage\""
echo ""
echo -e "${YELLOW}If something goes wrong:${NC}"
echo "Restore from backup:"
echo "  cp -r $BACKUP_DIR/* $DOCKER_CONFIGS/"
