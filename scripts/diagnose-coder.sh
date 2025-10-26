#!/bin/bash

# Coder Diagnostic Script
# Diagnoses issues with Coder deployment on teaching VM
# Usage: ./diagnose-coder.sh [REMOTE_IP]

set -e

# Configuration
REMOTE_IP="${1:-192.168.10.29}"
REMOTE_USER="${REMOTE_USER:-dev}"
COMPOSE_PATH="/home/dev/docker-configs/teaching/coder"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Coder Diagnostic Tool - Teaching VM${NC}"
echo -e "${BLUE}  IP: ${REMOTE_IP}${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if we can SSH
echo -e "${YELLOW}[1/6] Testing SSH Connection...${NC}"
if ssh -o ConnectTimeout=5 "${REMOTE_USER}@${REMOTE_IP}" "echo 'SSH OK'" &>/dev/null; then
    echo -e "${GREEN}✓ SSH connection successful${NC}"
else
    echo -e "${RED}✗ Cannot connect via SSH${NC}"
    exit 1
fi
echo ""

# Check container status
echo -e "${YELLOW}[2/6] Checking Container Status...${NC}"
ssh "${REMOTE_USER}@${REMOTE_IP}" << 'ENDSSH'
cd /home/dev/docker-configs/teaching/coder
echo "Container Status:"
docker compose ps
echo ""
echo "Container Health:"
docker ps --filter "name=coder" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
ENDSSH
echo ""

# Check .env file
echo -e "${YELLOW}[3/6] Checking .env File...${NC}"
ssh "${REMOTE_USER}@${REMOTE_IP}" << 'ENDSSH'
cd /home/dev/docker-configs/teaching/coder
if [ -f .env ]; then
    echo "✓ .env file exists"
    echo "Contents (secrets masked):"
    sed 's/=.*/=***MASKED***/g' .env
else
    echo "✗ .env file NOT FOUND"
fi
ENDSSH
echo ""

# Check PostgreSQL
echo -e "${YELLOW}[4/6] Checking PostgreSQL...${NC}"
ssh "${REMOTE_USER}@${REMOTE_IP}" << 'ENDSSH'
cd /home/dev/docker-configs/teaching/coder
echo "PostgreSQL Container Status:"
docker compose ps postgres

echo ""
echo "PostgreSQL Health Check:"
docker compose exec -T postgres pg_isready -U coder || echo "PostgreSQL not ready"

echo ""
echo "PostgreSQL Logs (last 10 lines):"
docker compose logs --tail=10 postgres
ENDSSH
echo ""

# Check Coder logs
echo -e "${YELLOW}[5/6] Checking Coder Logs...${NC}"
ssh "${REMOTE_USER}@${REMOTE_IP}" << 'ENDSSH'
cd /home/dev/docker-configs/teaching/coder
echo "Coder Container Logs (last 30 lines):"
docker compose logs --tail=30 coder
ENDSSH
echo ""

# Check network connectivity
echo -e "${YELLOW}[6/6] Checking Network Connectivity...${NC}"
ssh "${REMOTE_USER}@${REMOTE_IP}" << 'ENDSSH'
cd /home/dev/docker-configs/teaching/coder
echo "Docker Networks:"
docker network ls | grep -E "(proxy|coder)"

echo ""
echo "Coder Container Networks:"
docker inspect coder --format='{{range $net,$v := .NetworkSettings.Networks}}{{$net}} {{end}}'

echo ""
echo "Testing Internal Connectivity:"
docker compose exec -T coder curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:3000 || echo "Cannot reach Coder on port 3000"
ENDSSH
echo ""

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Diagnostic Complete${NC}"
echo -e "${BLUE}================================================${NC}"
