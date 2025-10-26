#!/bin/bash

# Traefik Testing Script for Homelab Server (192.168.10.13)
# Tests all configured domains and services

# Don't exit on errors - we want to run all tests
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HOMELAB_IP="192.168.10.13"
PRIMARY_DOMAIN="plexlab.site"
SECONDARY_DOMAIN="nexuswarrior.site"

# Service definitions: domain:description
declare -a SERVICES=(
    "plexlab.site:Homepage Dashboard (Root Domain)"
    "traefik.plexlab.site:Traefik Dashboard"
    "portainer.plexlab.site:Portainer"
    "proxmox.plexlab.site:Proxmox VE"
    "truenas.plexlab.site:TrueNAS Scale"
    "jellyfin.plexlab.site:Jellyfin Media Server"
    "jellyseerr.plexlab.site:Jellyseerr"
    "jellystat.plexlab.site:Jellystat"
    "sonarr.plexlab.site:Sonarr"
    "radarr.plexlab.site:Radarr"
    "lidarr.plexlab.site:Lidarr"
    "bazarr.plexlab.site:Bazarr"
    "piholev6.nexuswarrior.site:Pi-hole v6"
)

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Traefik Testing Script - Homelab Server${NC}"
echo -e "${BLUE}  IP: $HOMELAB_IP${NC}"
echo -e "${BLUE}  Domains: $PRIMARY_DOMAIN, $SECONDARY_DOMAIN${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Function to print test result
print_result() {
    local status=$1
    local message=$2

    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC} - $message"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}✗ FAIL${NC} - $message"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠ WARN${NC} - $message"
    else
        echo -e "${BLUE}ℹ INFO${NC} - $message"
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# 1. Check if Traefik container is running
echo -e "\n${YELLOW}[1/6] Checking Traefik Container Status...${NC}"
if docker ps 2>/dev/null | grep -q "traefik"; then
    TRAEFIK_STATUS=$(docker inspect -f '{{.State.Status}}' traefik 2>/dev/null)
    if [ "$TRAEFIK_STATUS" = "running" ]; then
        print_result "PASS" "Traefik container is running"
        TRAEFIK_UPTIME=$(docker inspect -f '{{.State.StartedAt}}' traefik 2>/dev/null)
        echo -e "  ${BLUE}Started: $TRAEFIK_UPTIME${NC}"
    else
        print_result "FAIL" "Traefik container status: $TRAEFIK_STATUS"
    fi
else
    print_result "FAIL" "Traefik container not found"
fi

# 2. Check Traefik network
echo -e "\n${YELLOW}[2/6] Checking Docker Network...${NC}"
if docker network ls 2>/dev/null | grep -q "proxy"; then
    print_result "PASS" "Traefik 'proxy' network exists"
    NETWORK_CONTAINERS=$(docker network inspect proxy 2>/dev/null | grep -c "\"Name\"" || echo "0")
    echo -e "  ${BLUE}Connected containers: $NETWORK_CONTAINERS${NC}"
else
    print_result "FAIL" "Traefik 'proxy' network not found"
fi

# 3. Check if ports are listening
echo -e "\n${YELLOW}[3/6] Checking Traefik Ports...${NC}"
if netstat -tuln 2>/dev/null | grep -q ":80 " || ss -tuln 2>/dev/null | grep -q ":80 "; then
    print_result "PASS" "Port 80 (HTTP) is listening"
else
    print_result "FAIL" "Port 80 (HTTP) not listening"
fi

if netstat -tuln 2>/dev/null | grep -q ":443 " || ss -tuln 2>/dev/null | grep -q ":443 "; then
    print_result "PASS" "Port 443 (HTTPS) is listening"
else
    print_result "FAIL" "Port 443 (HTTPS) not listening"
fi

# 4. Test HTTP to HTTPS redirect
echo -e "\n${YELLOW}[4/6] Testing HTTP to HTTPS Redirect...${NC}"
HTTP_REDIRECT=$(curl -s -o /dev/null -w "%{http_code}" -L --max-redirs 0 "http://traefik.$PRIMARY_DOMAIN" 2>/dev/null || echo "000")
if [ "$HTTP_REDIRECT" = "301" ] || [ "$HTTP_REDIRECT" = "308" ]; then
    print_result "PASS" "HTTP redirects to HTTPS (Status: $HTTP_REDIRECT)"
else
    print_result "WARN" "HTTP redirect status: $HTTP_REDIRECT (expected 301 or 308)"
fi

# 5. Test all configured domains
echo -e "\n${YELLOW}[5/6] Testing Service Domains (HTTPS + SSL)...${NC}"
for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r domain description <<< "$service_info"

    echo -e "\n${BLUE}Testing: $description${NC}"
    echo -e "  Domain: $domain"

    # Test HTTPS endpoint
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -k "https://$domain" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        print_result "PASS" "$description is accessible (HTTP $HTTP_CODE)"
    elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        print_result "PASS" "$description requires authentication (HTTP $HTTP_CODE)"
    elif [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "307" ] || [ "$HTTP_CODE" = "308" ]; then
        print_result "PASS" "$description redirects (HTTP $HTTP_CODE)"
    elif [ "$HTTP_CODE" = "000" ]; then
        print_result "FAIL" "$description connection failed/timeout"
    else
        print_result "WARN" "$description returned HTTP $HTTP_CODE"
    fi

    # Test SSL certificate
    SSL_CHECK=$(echo | timeout 5 openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | grep "Verify return code")
    if echo "$SSL_CHECK" | grep -q "0 (ok)"; then
        print_result "PASS" "$description SSL certificate is valid"
    else
        print_result "WARN" "$description SSL: $SSL_CHECK"
    fi
done

# 6. Check backend service containers
echo -e "\n${YELLOW}[6/6] Checking Backend Service Containers...${NC}"

# Media Services
if docker ps 2>/dev/null | grep -q "jellyfin"; then
    print_result "PASS" "Jellyfin container is running"
else
    print_result "WARN" "Jellyfin container is not running"
fi

if docker ps 2>/dev/null | grep -q "jellyseerr"; then
    print_result "PASS" "Jellyseerr container is running"
else
    print_result "WARN" "Jellyseerr container is not running"
fi

# Servarr Stack
for service in sonarr radarr lidarr bazarr; do
    if docker ps 2>/dev/null | grep -q "$service"; then
        print_result "PASS" "$(echo $service | sed 's/.*/\u&/') container is running"
    else
        print_result "WARN" "$(echo $service | sed 's/.*/\u&/') container is not running"
    fi
done

# Homepage
if docker ps 2>/dev/null | grep -q "homepage"; then
    print_result "PASS" "Homepage container is running"
else
    print_result "WARN" "Homepage container is not running"
fi

# Summary
echo -e "\n${BLUE}================================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "Total Tests:  $TOTAL_TESTS"
echo -e "${GREEN}Passed:       $PASSED_TESTS${NC}"
echo -e "${RED}Failed:       $FAILED_TESTS${NC}"
echo ""

if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "${BLUE}Success Rate: $SUCCESS_RATE%${NC}"
fi

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! Traefik is working correctly.${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some tests failed. Review the output above.${NC}"
    exit 1
fi
