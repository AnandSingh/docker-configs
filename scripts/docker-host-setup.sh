#!/bin/bash
# Docker Host NFS Mount Setup Script
# Run this on Docker host (192.168.10.13) after TrueNAS setup is complete
# Usage: bash docker-host-setup.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
TRUENAS_IP="192.168.10.15"
POOL_NAME="nas-pool"
MOUNT_BASE="/mnt/nas"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Docker Host NFS Mount Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

# Install NFS client if not present
echo -e "${BLUE}Checking NFS client...${NC}"
if ! command -v mount.nfs4 &> /dev/null; then
    echo -e "${YELLOW}Installing NFS client...${NC}"
    apt-get update -qq
    apt-get install -y nfs-common
    echo -e "${GREEN}✓${NC} NFS client installed"
else
    echo -e "${GREEN}✓${NC} NFS client already installed"
fi

# Test NFS server availability
echo -e "${BLUE}Testing NFS server connectivity...${NC}"
if ! showmount -e $TRUENAS_IP >/dev/null 2>&1; then
    echo -e "${RED}Error: Cannot reach NFS server at $TRUENAS_IP${NC}"
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo "  1. Check TrueNAS NFS service is running"
    echo "  2. Check firewall allows NFS (ports 111, 2049, 20048)"
    echo "  3. Verify NFS shares are configured"
    echo "  4. Test: showmount -e $TRUENAS_IP"
    exit 1
fi
echo -e "${GREEN}✓${NC} NFS server is reachable"

# Show available exports
echo -e "${BLUE}Available NFS exports:${NC}"
showmount -e $TRUENAS_IP | grep "$POOL_NAME" || echo -e "${YELLOW}No exports found for $POOL_NAME${NC}"
echo ""

# Create mount points
echo -e "${BLUE}Creating mount points...${NC}"
mkdir -p "$MOUNT_BASE"/{appdata,databases,media,downloads}
echo -e "${GREEN}✓${NC} Mount points created at $MOUNT_BASE"

# Test mount one share first
echo -e "${BLUE}Testing NFS mount...${NC}"
if mount -t nfs4 -o ro $TRUENAS_IP:/mnt/$POOL_NAME/docker/appdata "$MOUNT_BASE/appdata" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Test mount successful"
    umount "$MOUNT_BASE/appdata"
else
    echo -e "${RED}Error: Failed to mount NFS share${NC}"
    echo -e "${YELLOW}Please check:${NC}"
    echo "  1. NFS shares are configured on TrueNAS"
    echo "  2. Path is correct: /mnt/$POOL_NAME/docker/appdata"
    echo "  3. Host $HOSTNAME is authorized"
    exit 1
fi

# Backup fstab
echo -e "${BLUE}Backing up /etc/fstab...${NC}"
cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)
echo -e "${GREEN}✓${NC} Backed up /etc/fstab"

# Check if entries already exist
if grep -q "# TrueNAS Docker Storage" /etc/fstab; then
    echo -e "${YELLOW}⊙${NC} NFS mounts already in /etc/fstab, skipping..."
else
    echo -e "${BLUE}Adding NFS mounts to /etc/fstab...${NC}"
    cat >> /etc/fstab << EOF

# TrueNAS Docker Storage (Added $(date))
$TRUENAS_IP:/mnt/$POOL_NAME/docker/appdata   $MOUNT_BASE/appdata   nfs4  rw,hard,intr,rsize=131072,wsize=131072,timeo=600  0  0
$TRUENAS_IP:/mnt/$POOL_NAME/docker/databases $MOUNT_BASE/databases nfs4  rw,hard,intr,rsize=131072,wsize=131072,timeo=600  0  0
$TRUENAS_IP:/mnt/$POOL_NAME/media            $MOUNT_BASE/media     nfs4  rw,hard,intr,rsize=131072,wsize=131072,timeo=600  0  0
$TRUENAS_IP:/mnt/$POOL_NAME/downloads        $MOUNT_BASE/downloads nfs4  rw,hard,intr,rsize=131072,wsize=131072,timeo=600  0  0
EOF
    echo -e "${GREEN}✓${NC} Added NFS mounts to /etc/fstab"
fi

# Mount all NFS shares
echo -e "${BLUE}Mounting NFS shares...${NC}"
if mount -a; then
    echo -e "${GREEN}✓${NC} All NFS shares mounted successfully"
else
    echo -e "${RED}Error mounting shares. Check mount output above.${NC}"
    exit 1
fi

# Verify mounts
echo ""
echo -e "${BLUE}Verifying mounts:${NC}"
df -h | grep "$MOUNT_BASE" || echo -e "${YELLOW}No mounts found${NC}"

# Test write access
echo -e "${BLUE}Testing write access...${NC}"
test_file="$MOUNT_BASE/appdata/.test_$(date +%s)"
if touch "$test_file" 2>/dev/null; then
    rm "$test_file"
    echo -e "${GREEN}✓${NC} Write access verified"
else
    echo -e "${RED}Warning: Cannot write to $MOUNT_BASE/appdata${NC}"
    echo -e "${YELLOW}Check permissions on TrueNAS${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}NFS Mount Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Mount Status:${NC}"
mount | grep "$TRUENAS_IP" | sed 's/^/  /'
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Run migration script to copy data:"
echo "   bash migrate-to-truenas.sh"
echo ""
echo "2. Update docker-compose files:"
echo "   bash update-compose-files.sh"
echo ""
echo "3. Test services with new storage"
echo ""
echo -e "${YELLOW}Optional: Enable NFS performance monitoring${NC}"
echo "  apt-get install nfs-utils"
echo "  nfsiostat 5  # Monitor NFS I/O"
