#!/bin/bash
# TrueNAS NFS Share Setup Script
# Run this on TrueNAS Scale (192.168.10.15) after truenas-setup.sh
# Usage: bash truenas-nfs-setup.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
POOL_NAME="nas-pool"
DOCKER_HOST="192.168.10.13"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}TrueNAS NFS Share Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo)${NC}"
    exit 1
fi

echo -e "${YELLOW}Note: This script configures NFS using CLI.${NC}"
echo -e "${YELLOW}For TrueNAS Scale, you may prefer using the Web UI:${NC}"
echo -e "${YELLOW}  Sharing → Unix Shares (NFS) → Add${NC}"
echo ""
read -p "Continue with CLI configuration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Please configure NFS shares manually in Web UI:${NC}"
    echo ""
    echo "Share 1: Appdata"
    echo "  Path: /mnt/$POOL_NAME/docker/appdata"
    echo "  Authorized Networks: $DOCKER_HOST/32"
    echo "  Maproot User: dev"
    echo "  Maproot Group: dev"
    echo ""
    echo "Share 2: Databases"
    echo "  Path: /mnt/$POOL_NAME/docker/databases"
    echo "  Authorized Networks: $DOCKER_HOST/32"
    echo "  Maproot User: dev"
    echo "  Maproot Group: dev"
    echo ""
    echo "Share 3: Media"
    echo "  Path: /mnt/$POOL_NAME/media"
    echo "  Authorized Networks: $DOCKER_HOST/32"
    echo "  Maproot User: dev"
    echo "  Maproot Group: dev"
    echo ""
    echo "Share 4: Downloads"
    echo "  Path: /mnt/$POOL_NAME/downloads"
    echo "  Authorized Networks: $DOCKER_HOST/32"
    echo "  Maproot User: dev"
    echo "  Maproot Group: dev"
    echo ""
    exit 0
fi

# Check if NFS service is installed
if ! command -v exportfs &> /dev/null; then
    echo -e "${RED}NFS server not found. Please install nfs-kernel-server.${NC}"
    exit 1
fi

echo -e "${BLUE}Configuring NFS exports...${NC}"

# Backup existing exports
if [ -f /etc/exports ]; then
    cp /etc/exports /etc/exports.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}✓${NC} Backed up existing /etc/exports"
fi

# Create exports configuration
cat >> /etc/exports << EOF

# Docker Services NFS Exports (Added $(date))
/mnt/$POOL_NAME/docker/appdata   $DOCKER_HOST(rw,sync,no_subtree_check,no_root_squash,anonuid=1000,anongid=1000)
/mnt/$POOL_NAME/docker/databases $DOCKER_HOST(rw,sync,no_subtree_check,no_root_squash,anonuid=1000,anongid=1000)
/mnt/$POOL_NAME/media            $DOCKER_HOST(rw,async,no_subtree_check,no_root_squash,anonuid=1000,anongid=1000)
/mnt/$POOL_NAME/downloads        $DOCKER_HOST(rw,async,no_subtree_check,no_root_squash,anonuid=1000,anongid=1000)
EOF

echo -e "${GREEN}✓${NC} Added NFS exports to /etc/exports"

# Export the shares
echo -e "${BLUE}Applying NFS exports...${NC}"
exportfs -ra

# Enable and start NFS service
echo -e "${BLUE}Ensuring NFS service is running...${NC}"
systemctl enable nfs-server 2>/dev/null || systemctl enable nfs-kernel-server 2>/dev/null || true
systemctl restart nfs-server 2>/dev/null || systemctl restart nfs-kernel-server 2>/dev/null || true

# Verify exports
echo ""
echo -e "${BLUE}Current NFS Exports:${NC}"
exportfs -v | grep "$POOL_NAME"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}NFS Configuration Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Test NFS from Docker host:"
echo "   showmount -e 192.168.10.15"
echo ""
echo "2. Run setup script on Docker host ($DOCKER_HOST):"
echo "   bash docker-host-setup.sh"
echo ""
echo -e "${YELLOW}Firewall Note:${NC}"
echo "Ensure NFS ports are open on TrueNAS firewall:"
echo "  - TCP/UDP 2049 (NFS)"
echo "  - TCP/UDP 111 (Portmapper)"
echo "  - TCP/UDP 20048 (mountd)"
