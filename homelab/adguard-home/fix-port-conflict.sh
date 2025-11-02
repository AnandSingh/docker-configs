#!/bin/bash
# Fix Port 53 Conflict - Stop existing DNS services before starting AdGuard Home

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================"
echo "AdGuard Home - Port 53 Conflict Fix"
echo -e "======================================${NC}\n"

# Step 1: Identify what's using port 53
echo -e "${BLUE}[1/4] Checking what's using port 53...${NC}"
echo ""

# Check with lsof
if command -v lsof &> /dev/null; then
    echo "Using lsof:"
    sudo lsof -i :53 || echo "No processes found with lsof"
    echo ""
fi

# Check with netstat
if command -v netstat &> /dev/null; then
    echo "Using netstat:"
    sudo netstat -tlnp | grep :53 || echo "No processes found with netstat"
    echo ""
fi

# Check for Docker containers using port 53
echo "Checking Docker containers:"
CONFLICTING_CONTAINERS=$(docker ps --format "{{.Names}}" --filter "publish=53" 2>/dev/null || true)

if [ -n "$CONFLICTING_CONTAINERS" ]; then
    echo -e "${YELLOW}Found containers using port 53:${NC}"
    echo "$CONFLICTING_CONTAINERS"
    echo ""
else
    echo "No Docker containers explicitly using port 53"
    echo ""
fi

# Step 2: Check for Pi-hole specifically
echo -e "${BLUE}[2/4] Checking for Pi-hole...${NC}"
PIHOLE_CONTAINER=$(docker ps -a --format "{{.Names}}" | grep -i pihole || true)

if [ -n "$PIHOLE_CONTAINER" ]; then
    echo -e "${YELLOW}Found Pi-hole container: $PIHOLE_CONTAINER${NC}"

    # Check if it's running
    PIHOLE_STATUS=$(docker ps --filter "name=$PIHOLE_CONTAINER" --format "{{.Status}}" || true)

    if [ -n "$PIHOLE_STATUS" ]; then
        echo -e "${YELLOW}Status: Running${NC}"
        echo ""

        read -p "Do you want to stop Pi-hole? (yes/no): " STOP_PIHOLE

        if [ "$STOP_PIHOLE" = "yes" ] || [ "$STOP_PIHOLE" = "y" ]; then
            echo -e "${BLUE}Stopping Pi-hole...${NC}"

            # Find Pi-hole compose file
            PIHOLE_DIR=$(docker inspect "$PIHOLE_CONTAINER" --format '{{.Config.Labels}}' | grep -o 'com.docker.compose.project.working_dir=[^,]*' | cut -d= -f2 || echo "")

            if [ -n "$PIHOLE_DIR" ] && [ -f "$PIHOLE_DIR/docker-compose.yaml" ]; then
                echo "Found Pi-hole compose file at: $PIHOLE_DIR"
                cd "$PIHOLE_DIR"
                docker compose down
                echo -e "${GREEN}✓ Pi-hole stopped using docker compose${NC}"
            else
                echo "Compose file not found, stopping container directly"
                docker stop "$PIHOLE_CONTAINER"
                echo -e "${GREEN}✓ Pi-hole container stopped${NC}"
            fi
            echo ""
        else
            echo -e "${RED}Cannot proceed with Pi-hole running on port 53${NC}"
            echo "Please stop Pi-hole manually and try again."
            exit 1
        fi
    else
        echo "Pi-hole container exists but is not running"
        echo ""
    fi
else
    echo "No Pi-hole container found"
    echo ""
fi

# Step 3: Check for systemd-resolved (common on Ubuntu)
echo -e "${BLUE}[3/4] Checking for systemd-resolved...${NC}"
if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    echo -e "${YELLOW}systemd-resolved is running on port 53${NC}"
    echo ""

    read -p "Do you want to disable systemd-resolved? (yes/no): " DISABLE_RESOLVED

    if [ "$DISABLE_RESOLVED" = "yes" ] || [ "$DISABLE_RESOLVED" = "y" ]; then
        echo -e "${BLUE}Disabling systemd-resolved...${NC}"
        sudo systemctl stop systemd-resolved
        sudo systemctl disable systemd-resolved

        # Update /etc/resolv.conf
        echo -e "${BLUE}Updating /etc/resolv.conf...${NC}"
        sudo rm -f /etc/resolv.conf
        echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
        echo "nameserver 1.0.0.1" | sudo tee -a /etc/resolv.conf

        echo -e "${GREEN}✓ systemd-resolved disabled${NC}"
        echo ""
    else
        echo -e "${RED}Cannot proceed with systemd-resolved running${NC}"
        exit 1
    fi
else
    echo "systemd-resolved is not running"
    echo ""
fi

# Step 4: Final check
echo -e "${BLUE}[4/4] Final port check...${NC}"
if sudo lsof -i :53 >/dev/null 2>&1; then
    echo -e "${RED}⚠ Port 53 is still in use:${NC}"
    sudo lsof -i :53
    echo ""
    echo "Please manually stop the service above and try again."
    exit 1
else
    echo -e "${GREEN}✓ Port 53 is now free!${NC}"
    echo ""
fi

# Ready to start AdGuard
echo -e "${GREEN}======================================"
echo "✓ Ready to start AdGuard Home!"
echo -e "======================================${NC}\n"

echo "Next step: Run 'docker compose up -d' to start AdGuard Home"
