#!/bin/bash
# Master Migration Script - Complete TrueNAS Storage Reorganization
# Run this on Docker host (192.168.10.13)
#
# This script orchestrates the entire migration process

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_CONFIGS="/home/dev/docker/docker-configs"

echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  TrueNAS Storage Reorganization Master    ║${NC}"
echo -e "${CYAN}║  Automated Migration Script                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root: sudo bash master-migration.sh${NC}"
    exit 1
fi

# Pre-flight checks
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}Pre-flight Checks${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo ""

# Check if scripts exist
required_scripts=(
    "reorganize-existing-storage.sh"
    "migrate-existing-data.sh"
    "update-compose-files.sh"
)

for script in "${required_scripts[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$script" ]; then
        echo -e "${RED}✗ Missing script: $script${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Found: $script"
    chmod +x "$SCRIPT_DIR/$script"
done

echo ""

# Check NFS mounts
echo -e "${BLUE}Checking NFS mounts...${NC}"
if mountpoint -q /home/dev/docker; then
    echo -e "${GREEN}✓${NC} /home/dev/docker is mounted"
else
    echo -e "${RED}✗ /home/dev/docker is not mounted${NC}"
    exit 1
fi

if mountpoint -q /media; then
    echo -e "${GREEN}✓${NC} /media is mounted"
else
    echo -e "${RED}✗ /media is not mounted${NC}"
    exit 1
fi

echo ""

# Show current setup
echo -e "${BLUE}Current Setup:${NC}"
echo -e "  Docker mount: /home/dev/docker (NFS)"
echo -e "  Media mount:  /media (NFS)"
echo -e "  Config dir:   $DOCKER_CONFIGS"
echo ""

# Migration overview
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Migration Overview${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""
echo "This script will:"
echo "  1. Create organized directory structure"
echo "  2. Stop Docker services"
echo "  3. Migrate data to new structure"
echo "  4. Update docker-compose files"
echo "  5. Validate configurations"
echo "  6. Provide testing instructions"
echo ""
echo -e "${YELLOW}⚠  This will modify your Docker configuration${NC}"
echo -e "${YELLOW}⚠  Backups will be created automatically${NC}"
echo ""
read -p "Continue with migration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 0
fi

echo ""

# Step 1: Reorganize storage
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 1: Reorganize Storage Structure${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

bash "$SCRIPT_DIR/reorganize-existing-storage.sh" || {
    echo -e "${RED}Failed to reorganize storage${NC}"
    exit 1
}

echo ""
read -p "Press Enter to continue to Step 2..."
echo ""

# Step 2: Stop services
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 2: Stop Docker Services${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

cd "$DOCKER_CONFIGS"

services=(
    "traefik/docker-compose.yaml"
    "homepage/docker-compose.yaml"
    "jellyfin/compose.yaml"
    "servarr/compose.yaml"
    "rustdesk/docker-compose.yml"
    "twingate/docker-compose.yaml"
)

for service in "${services[@]}"; do
    if [ -f "$service" ]; then
        service_name=$(dirname "$service")
        echo -e "${BLUE}Stopping $service_name...${NC}"
        docker compose -f "$service" down 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Stopped $service_name"
    fi
done

echo ""
echo -e "${GREEN}All services stopped${NC}"
echo ""
read -p "Press Enter to continue to Step 3..."
echo ""

# Step 3: Migrate data
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 3: Migrate Data${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

# First do a dry run
echo -e "${YELLOW}Running dry run first...${NC}"
echo ""
bash "$SCRIPT_DIR/migrate-existing-data.sh" --dry-run

echo ""
read -p "Dry run complete. Proceed with actual migration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Migration cancelled. Services are stopped.${NC}"
    echo "To restart services, run:"
    echo "  cd $DOCKER_CONFIGS"
    echo "  docker compose -f traefik/docker-compose.yaml up -d"
    exit 0
fi

echo ""
bash "$SCRIPT_DIR/migrate-existing-data.sh" || {
    echo -e "${RED}Failed to migrate data${NC}"
    echo -e "${YELLOW}Services are stopped. To restart:${NC}"
    echo "  cd $DOCKER_CONFIGS"
    echo "  docker compose -f traefik/docker-compose.yaml up -d"
    exit 1
}

echo ""
read -p "Press Enter to continue to Step 4..."
echo ""

# Step 4: Update compose files
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 4: Update Docker Compose Files${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

cd "$SCRIPT_DIR"
bash "$SCRIPT_DIR/update-compose-files.sh" || {
    echo -e "${RED}Failed to update compose files${NC}"
    exit 1
}

echo ""
read -p "Press Enter to continue to Step 5..."
echo ""

# Step 5: Validate configurations
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}Step 5: Validate Configurations${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo ""

cd "$DOCKER_CONFIGS"

validation_failed=false

for service in "${services[@]}"; do
    if [ -f "$service" ]; then
        service_name=$(dirname "$service")
        echo -e "${BLUE}Validating $service_name...${NC}"
        if docker compose -f "$service" config > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} $service_name configuration is valid"
        else
            echo -e "${RED}✗${NC} $service_name configuration has errors"
            validation_failed=true
        fi
    fi
done

echo ""

if [ "$validation_failed" = true ]; then
    echo -e "${RED}Some configurations have errors. Please review.${NC}"
    echo "Services are stopped. Do not start them until errors are fixed."
    exit 1
fi

echo -e "${GREEN}All configurations are valid!${NC}"
echo ""

# Final summary
echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         Migration Complete!                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}New Storage Structure:${NC}"
echo "  📁 /home/dev/docker/appdata/     ← Service configs"
echo "  📁 /home/dev/docker/databases/   ← Databases"
echo "  📁 /home/dev/docker/downloads/   ← Downloads"
echo "  📁 /media/                       ← Media library"
echo ""

echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}Next Steps (Important!)${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}1. Test Services${NC}"
echo "   Start services one by one and verify:"
echo ""
echo "   cd $DOCKER_CONFIGS"
echo "   docker compose -f traefik/docker-compose.yaml up -d"
echo "   docker compose logs -f traefik"
echo ""
echo "   If Traefik works, test others:"
echo "   docker compose -f homepage/docker-compose.yaml up -d"
echo "   docker compose -f jellyfin/compose.yaml up -d"
echo ""

echo -e "${BLUE}2. Verify Data${NC}"
echo "   Check that services can access their data:"
echo "   ls -la /home/dev/docker/appdata/traefik/config/"
echo "   ls -la /home/dev/docker/appdata/jellyfin/"
echo ""

echo -e "${BLUE}3. Commit Changes${NC}"
echo "   cd $DOCKER_CONFIGS"
echo "   git status"
echo "   git diff"
echo "   git add -u"
echo "   git commit -m \"Reorganize storage: centralized appdata structure\""
echo "   git push origin main"
echo ""

echo -e "${BLUE}4. Configure TrueNAS Snapshots${NC}"
echo "   Go to TrueNAS Web UI (http://192.168.10.15)"
echo "   Data Protection → Periodic Snapshot Tasks"
echo ""
echo "   Create snapshot tasks:"
echo "   - Appdata: Hourly, keep 24"
echo "   - Databases: Every 15 min, keep 8"
echo "   - Media: Daily, keep 7"
echo ""

echo -e "${BLUE}5. Test Snapshot Restore${NC}"
echo "   Verify you can restore from snapshots:"
echo "   ls /home/dev/docker/.zfs/snapshot/"
echo ""

echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✓ Migration script completed successfully${NC}"
echo ""
echo -e "${CYAN}For detailed documentation, see:${NC}"
echo "  scripts/README.md"
echo "  docs/TRUENAS-STORAGE-DESIGN.md"
echo ""
