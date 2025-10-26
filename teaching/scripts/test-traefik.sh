#!/bin/bash

# Traefik Testing Script for Teaching VM (192.168.10.29)
# Tests all configured domains and services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TEACHING_VM_IP="192.168.10.29"
DOMAIN_BASE="lab.nexuswarrior.site"

# Service definitions: domain:description
declare -a SERVICES=(
    "traefik:Traefik Dashboard"
    "portainer:Portainer"
    "coder:Coder Platform"
    "gautham:Gautham Code Server"
    "nihita:Nihita Code Server"
    "dhruv:Dhruv Code Server"
    "farish:Farish Code Server"
    "proxmox:Proxmox VE (proxy)"
)

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Traefik Testing Script - Teaching VM${NC}"
echo -e "${BLUE}  IP: $TEACHING_VM_IP${NC}"
echo -e "${BLUE}  Domain: *.$DOMAIN_BASE${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to print test result
print_result() {
    local status=$1
    local message=$2

    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC} - $message"
        ((PASSED_TESTS++))
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}✗ FAIL${NC} - $message"
        ((FAILED_TESTS++))
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠ WARN${NC} - $message"
    else
        echo -e "${BLUE}ℹ INFO${NC} - $message"
    fi
    ((TOTAL_TESTS++))
}

# 1. Check if Traefik container is running
echo -e "\n${YELLOW}[1/6] Checking Traefik Container Status...${NC}"
if docker ps 2>/dev/null | grep -q "traefik"; then
    TRAEFIK_STATUS=$(docker inspect -f '{{.State.Status}}' traefik 2>/dev/null)
    if [ "$TRAEFIK_STATUS" = "running" ]; then
        print_result "PASS" "Traefik container is running"
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
HTTP_REDIRECT=$(curl -s -o /dev/null -w "%{http_code}" -L --max-redirs 0 "http://traefik.$DOMAIN_BASE" 2>/dev/null || echo "000")
if [ "$HTTP_REDIRECT" = "301" ] || [ "$HTTP_REDIRECT" = "308" ]; then
    print_result "PASS" "HTTP redirects to HTTPS (Status: $HTTP_REDIRECT)"
else
    print_result "WARN" "HTTP redirect status: $HTTP_REDIRECT (expected 301 or 308)"
fi

# 5. Test all configured domains
echo -e "\n${YELLOW}[5/6] Testing Service Domains (HTTPS + SSL)...${NC}"
for service_info in "${SERVICES[@]}"; do
    IFS=':' read -r subdomain description <<< "$service_info"
    FULL_DOMAIN="${subdomain}.${DOMAIN_BASE}"

    echo -e "\n${BLUE}Testing: $description ($FULL_DOMAIN)${NC}"

    # Test HTTPS endpoint
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 -k "https://$FULL_DOMAIN" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        print_result "PASS" "$description is accessible (HTTP $HTTP_CODE)"
    elif [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        print_result "PASS" "$description requires authentication (HTTP $HTTP_CODE)"
    elif [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "307" ] || [ "$HTTP_CODE" = "308" ]; then
        print_result "PASS" "$description redirects (HTTP $HTTP_CODE)"
    else
        print_result "FAIL" "$description returned HTTP $HTTP_CODE"
    fi

    # Test SSL certificate
    SSL_CHECK=$(echo | timeout 5 openssl s_client -servername "$FULL_DOMAIN" -connect "$FULL_DOMAIN:443" 2>/dev/null | grep "Verify return code")
    if echo "$SSL_CHECK" | grep -q "0 (ok)"; then
        print_result "PASS" "$description SSL certificate is valid"
    else
        print_result "WARN" "$description SSL: $SSL_CHECK"
    fi
done

# 6. Check backend service containers
echo -e "\n${YELLOW}[6/6] Checking Backend Service Containers...${NC}"

# Check Coder
if docker ps 2>/dev/null | grep -q "coder"; then
    print_result "PASS" "Coder container is running"
else
    print_result "WARN" "Coder container is not running"
fi

# Check Coder Postgres
if docker ps 2>/dev/null | grep -q "coder-postgres"; then
    print_result "PASS" "Coder PostgreSQL container is running"
else
    print_result "WARN" "Coder PostgreSQL container is not running"
fi

# Check RustDesk containers
if docker ps 2>/dev/null | grep -q "hbbs"; then
    print_result "PASS" "RustDesk hbbs container is running"
else
    print_result "WARN" "RustDesk hbbs container is not running"
fi

if docker ps 2>/dev/null | grep -q "hbbr"; then
    print_result "PASS" "RustDesk hbbr container is running"
else
    print_result "WARN" "RustDesk hbbr container is not running"
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Total Tests:  $TOTAL_TESTS"
echo -e "${GREEN}Passed:       $PASSED_TESTS${NC}"
echo -e "${RED}Failed:       $FAILED_TESTS${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed! Traefik is working correctly.${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed. Please check the output above.${NC}"
    exit 1
fi
