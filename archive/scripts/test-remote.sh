#!/bin/bash

# Remote Traefik Testing Script
# Run this from ANY computer on the network to test Traefik services
# Usage: ./test-remote.sh [homelab|teaching]

set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SERVER_TYPE="${1:-teaching}"

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Server configurations
if [ "$SERVER_TYPE" = "homelab" ]; then
    SERVER_NAME="Homelab Server"
    SERVER_IP="192.168.10.13"
    PRIMARY_DOMAIN="plexlab.site"

    # Homelab services
    declare -a SERVICES=(
        "plexlab.site:Homepage Dashboard"
        "traefik.plexlab.site:Traefik Dashboard"
        "portainer.plexlab.site:Portainer"
        "proxmox.plexlab.site:Proxmox VE"
        "truenas.plexlab.site:TrueNAS Scale"
        "jellyfin.plexlab.site:Jellyfin"
        "jellyseerr.plexlab.site:Jellyseerr"
        "jellystat.plexlab.site:Jellystat"
        "sonarr.plexlab.site:Sonarr"
        "radarr.plexlab.site:Radarr"
        "lidarr.plexlab.site:Lidarr"
        "bazarr.plexlab.site:Bazarr"
    )
elif [ "$SERVER_TYPE" = "teaching" ]; then
    SERVER_NAME="Teaching VM"
    SERVER_IP="192.168.10.29"
    PRIMARY_DOMAIN="lab.nexuswarrior.site"

    # Teaching VM services
    declare -a SERVICES=(
        "traefik.lab.nexuswarrior.site:Traefik Dashboard"
        "portainer.lab.nexuswarrior.site:Portainer"
        "coder.lab.nexuswarrior.site:Coder Platform"
        "gautham.lab.nexuswarrior.site:Gautham Code Server"
        "nihita.lab.nexuswarrior.site:Nihita Code Server"
        "dhruv.lab.nexuswarrior.site:Dhruv Code Server"
        "farish.lab.nexuswarrior.site:Farish Code Server"
    )
else
    echo -e "${RED}Invalid server type. Use: homelab or teaching${NC}"
    exit 1
fi

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Remote Traefik Testing - $SERVER_NAME${NC}"
echo -e "${BLUE}  IP: $SERVER_IP${NC}"
echo -e "${BLUE}  Primary Domain: $PRIMARY_DOMAIN${NC}"
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

# 1. Test network connectivity
echo -e "${YELLOW}[1/5] Testing Network Connectivity...${NC}"
echo ""

echo -n "  Ping test ($SERVER_IP): "
if ping -c 2 -W 2 $SERVER_IP >/dev/null 2>&1; then
    echo -e "${GREEN}Reachable${NC}"
    print_result "PASS" "Server is reachable on network"
else
    echo -e "${RED}Failed${NC}"
    print_result "FAIL" "Cannot reach server at $SERVER_IP"
    echo ""
    echo -e "${RED}Cannot continue - server is not reachable${NC}"
    exit 1
fi

echo ""

# 2. Test port connectivity
echo -e "${YELLOW}[2/5] Testing Port Connectivity...${NC}"
echo ""

echo -n "  Port 80 (HTTP): "
if nc -z -w 2 $SERVER_IP 80 2>/dev/null || timeout 2 bash -c "echo >/dev/tcp/$SERVER_IP/80" 2>/dev/null; then
    echo -e "${GREEN}Open${NC}"
    print_result "PASS" "HTTP port is accessible"
else
    echo -e "${RED}Closed/Filtered${NC}"
    print_result "FAIL" "HTTP port not accessible"
fi

echo -n "  Port 443 (HTTPS): "
if nc -z -w 2 $SERVER_IP 443 2>/dev/null || timeout 2 bash -c "echo >/dev/tcp/$SERVER_IP/443" 2>/dev/null; then
    echo -e "${GREEN}Open${NC}"
    print_result "PASS" "HTTPS port is accessible"
else
    echo -e "${RED}Closed/Filtered${NC}"
    print_result "FAIL" "HTTPS port not accessible"
fi

echo ""

# 3. Test DNS resolution
echo -e "${YELLOW}[3/5] Testing DNS Resolution...${NC}"
echo ""

DNS_WORKING=true
for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r domain description <<< "$service_info"

    echo -n "  $domain: "
    RESOLVED_IP=$(nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}')

    if [ -z "$RESOLVED_IP" ]; then
        RESOLVED_IP=$(host "$domain" 2>/dev/null | grep "has address" | awk '{print $4}' | head -1)
    fi

    if [ -z "$RESOLVED_IP" ]; then
        echo -e "${RED}DNS Failed${NC}"
        DNS_WORKING=false
    elif [ "$RESOLVED_IP" = "$SERVER_IP" ]; then
        echo -e "${GREEN}$RESOLVED_IP ✓${NC}"
    else
        echo -e "${YELLOW}$RESOLVED_IP (expected $SERVER_IP)${NC}"
        DNS_WORKING=false
    fi
done

if [ "$DNS_WORKING" = true ]; then
    print_result "PASS" "DNS resolution working correctly"
else
    print_result "WARN" "DNS resolution issues detected"
fi

echo ""

# 4. Test HTTP to HTTPS redirect
echo -e "${YELLOW}[4/5] Testing HTTP to HTTPS Redirect...${NC}"
echo ""

FIRST_DOMAIN=$(echo "${SERVICES[0]}" | cut -d: -f1)
HTTP_REDIRECT=$(curl -s -o /dev/null -w "%{http_code}" -I "http://$FIRST_DOMAIN" 2>/dev/null || echo "000")

if [ "$HTTP_REDIRECT" = "301" ] || [ "$HTTP_REDIRECT" = "308" ]; then
    print_result "PASS" "HTTP redirects to HTTPS (Status: $HTTP_REDIRECT)"
elif [ "$HTTP_REDIRECT" = "000" ]; then
    print_result "FAIL" "Connection failed (DNS issue?)"
else
    print_result "WARN" "Unexpected redirect status: $HTTP_REDIRECT"
fi

echo ""

# 5. Test all services
echo -e "${YELLOW}[5/5] Testing Services (HTTPS + SSL Certificates)...${NC}"
echo ""

for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r domain description <<< "$service_info"

    echo -e "${BLUE}Testing: $description${NC}"
    echo -e "  Domain: $domain"

    # Test HTTPS accessibility
    echo -n "  HTTPS: "
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$domain" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}$HTTP_CODE (OK)${NC}"
        print_result "PASS" "$description is accessible"
    elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        echo -e "${GREEN}$HTTP_CODE (Auth Required)${NC}"
        print_result "PASS" "$description requires authentication"
    elif [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "307" ] || [ "$HTTP_CODE" = "308" ]; then
        echo -e "${GREEN}$HTTP_CODE (Redirect)${NC}"
        print_result "PASS" "$description redirects"
    elif [ "$HTTP_CODE" = "000" ]; then
        echo -e "${RED}$HTTP_CODE (Connection Failed)${NC}"
        print_result "FAIL" "$description connection failed"
    else
        echo -e "${YELLOW}$HTTP_CODE${NC}"
        print_result "WARN" "$description returned $HTTP_CODE"
    fi

    # Test SSL certificate
    echo -n "  SSL Certificate: "
    SSL_INFO=$(echo | timeout 5 openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null)

    if echo "$SSL_INFO" | grep -q "Let's Encrypt"; then
        echo -e "${GREEN}Let's Encrypt ✓${NC}"
        print_result "PASS" "$description has valid Let's Encrypt certificate"
    elif echo "$SSL_INFO" | grep -q "Traefik"; then
        echo -e "${YELLOW}Traefik Default${NC}"
        print_result "WARN" "$description using Traefik default certificate"
    elif [ -n "$SSL_INFO" ]; then
        ISSUER=$(echo "$SSL_INFO" | sed 's/issuer=//')
        echo -e "${YELLOW}$ISSUER${NC}"
        print_result "WARN" "$description has certificate from: $ISSUER"
    else
        echo -e "${RED}Failed to retrieve${NC}"
        print_result "FAIL" "$description SSL check failed"
    fi

    echo ""
done

# Summary
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Test Summary - $SERVER_NAME${NC}"
echo -e "${BLUE}================================================${NC}"
echo -e "Total Tests:  $TOTAL_TESTS"
echo -e "${GREEN}Passed:       $PASSED_TESTS${NC}"
echo -e "${RED}Failed:       $FAILED_TESTS${NC}"
echo ""

if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "${BLUE}Success Rate: $SUCCESS_RATE%${NC}"
    echo ""
fi

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! $SERVER_NAME is working correctly.${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some tests failed. Review the output above.${NC}"

    # Provide helpful suggestions
    if [ "$DNS_WORKING" = false ]; then
        echo ""
        echo -e "${YELLOW}Suggestion: DNS issues detected.${NC}"
        echo "  - Verify DNS records point to $SERVER_IP"
        echo "  - Or add entries to /etc/hosts for testing"
    fi

    exit 1
fi
