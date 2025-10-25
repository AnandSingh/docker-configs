#!/bin/bash

# Health Check Script for Homelab Services
# Usage: ./health-check.sh [service_name]
# Example: ./health-check.sh traefik
#          ./health-check.sh (checks all)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SERVICE="${1:-all}"

# Service health check configurations
declare -A HEALTH_CHECKS=(
    ["traefik"]="https://traefik.plexlab.site:443"
    ["homepage"]="https://list.plexlab.site:443"
    ["pihole"]="http://localhost:80/admin"
    ["rustdesk"]="tcp://localhost:21116"
)

declare -A SERVICE_DIRS=(
    ["traefik"]="traefik"
    ["homepage"]="homepage"
    ["pihole"]="Piholev6"
    ["rustdesk"]="rustdesk"
)

check_container_health() {
    local service=$1
    local service_dir="${SERVICE_DIRS[$service]}"
    local compose_file=$(ls "$REPO_DIR/$service_dir/docker-compose.y"*"ml" 2>/dev/null | head -1)

    if [ ! -f "$compose_file" ]; then
        echo -e "${RED}❌${NC} $service: compose file not found"
        return 1
    fi

    # Get container status
    local running_containers=$(docker compose -f "$compose_file" ps --services --filter "status=running" 2>/dev/null | wc -l)
    local total_containers=$(docker compose -f "$compose_file" ps --services 2>/dev/null | wc -l)

    if [ "$running_containers" -eq "$total_containers" ] && [ "$total_containers" -gt 0 ]; then
        echo -e "${GREEN}✅${NC} $service: All containers running ($running_containers/$total_containers)"

        # Show individual container status
        docker compose -f "$compose_file" ps --format "table {{.Service}}\t{{.Status}}" 2>/dev/null | tail -n +2 | while read line; do
            echo -e "   ${BLUE}↳${NC} $line"
        done
        return 0
    else
        echo -e "${RED}❌${NC} $service: Containers not healthy ($running_containers/$total_containers running)"
        docker compose -f "$compose_file" ps 2>/dev/null
        return 1
    fi
}

check_http_endpoint() {
    local service=$1
    local url=$2

    if command -v curl &> /dev/null; then
        if curl -s -o /dev/null -w "%{http_code}" -k --connect-timeout 5 "$url" | grep -q "^[23]"; then
            echo -e "   ${GREEN}↳${NC} HTTP endpoint accessible: $url"
            return 0
        else
            echo -e "   ${YELLOW}↳${NC} HTTP endpoint not accessible: $url"
            return 1
        fi
    fi
}

check_tcp_port() {
    local service=$1
    local host_port=$2

    local host=$(echo "$host_port" | cut -d: -f2 | tr -d '/')
    local port=$(echo "$host_port" | cut -d: -f3)

    if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        echo -e "   ${GREEN}↳${NC} TCP port accessible: $host:$port"
        return 0
    else
        echo -e "   ${YELLOW}↳${NC} TCP port not accessible: $host:$port"
        return 1
    fi
}

check_service() {
    local service=$1

    echo -e "\n${BLUE}Checking $service...${NC}"

    # Check container health
    if ! check_container_health "$service"; then
        return 1
    fi

    # Check specific endpoints if configured
    if [ -n "${HEALTH_CHECKS[$service]}" ]; then
        local endpoint="${HEALTH_CHECKS[$service]}"
        if [[ $endpoint == http* ]]; then
            check_http_endpoint "$service" "$endpoint"
        elif [[ $endpoint == tcp://* ]]; then
            check_tcp_port "$service" "$endpoint"
        fi
    fi

    return 0
}

main() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}Homelab Service Health Check${NC}"
    echo -e "${BLUE}Time: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BLUE}=========================================${NC}"

    local failed_services=()

    if [ "$SERVICE" == "all" ]; then
        for service in "${!SERVICE_DIRS[@]}"; do
            if ! check_service "$service"; then
                failed_services+=("$service")
            fi
        done
    else
        if ! check_service "$SERVICE"; then
            failed_services+=("$SERVICE")
        fi
    fi

    echo -e "\n${BLUE}=========================================${NC}"

    if [ ${#failed_services[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ All services healthy!${NC}"
        exit 0
    else
        echo -e "${RED}❌ Failed services: ${failed_services[*]}${NC}"
        exit 1
    fi
}

main
