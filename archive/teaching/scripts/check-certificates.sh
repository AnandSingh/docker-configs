#!/bin/bash

# Certificate Status Checker
# Diagnoses Let's Encrypt certificate issues

set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Certificate Status Checker${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# 1. Check acme.json
echo -e "${YELLOW}[1] Checking acme.json...${NC}"
ACME_FILE="../traefik/config/acme.json"

if [ -f "$ACME_FILE" ]; then
    SIZE=$(stat -f%z "$ACME_FILE" 2>/dev/null || stat -c%s "$ACME_FILE" 2>/dev/null)
    PERMS=$(stat -f%A "$ACME_FILE" 2>/dev/null || stat -c%a "$ACME_FILE" 2>/dev/null)

    echo -e "  File: ${GREEN}Found${NC}"
    echo -e "  Size: $SIZE bytes"
    echo -e "  Permissions: $PERMS"

    if [ "$PERMS" != "600" ]; then
        echo -e "  ${RED}WARNING: Permissions should be 600${NC}"
    fi

    if [ "$SIZE" -lt 10 ]; then
        echo -e "  ${YELLOW}WARNING: File is empty or very small - no certificates yet${NC}"
    else
        echo -e "  ${GREEN}File contains data (likely has certificates)${NC}"
    fi
else
    echo -e "  ${RED}NOT FOUND${NC}"
fi

echo ""

# 2. Check Traefik logs for ACME errors
echo -e "${YELLOW}[2] Checking Traefik logs for ACME/certificate errors...${NC}"
echo ""

docker logs traefik 2>&1 | grep -iE "(acme|certificate|letsencrypt)" | tail -20

echo ""

# 3. Check environment variables
echo -e "${YELLOW}[3] Checking environment variables...${NC}"
echo ""

ENV_FILE="../traefik/.env"
if [ -f "$ENV_FILE" ]; then
    echo -e "  .env file: ${GREEN}Found${NC}"

    if grep -q "CLOUDFLARE_API_TOKEN" "$ENV_FILE"; then
        TOKEN_VALUE=$(grep "CLOUDFLARE_API_TOKEN" "$ENV_FILE" | cut -d= -f2)
        if [ -n "$TOKEN_VALUE" ] && [ "$TOKEN_VALUE" != "your_token_here" ]; then
            echo -e "  CLOUDFLARE_API_TOKEN: ${GREEN}Set${NC}"
        else
            echo -e "  CLOUDFLARE_API_TOKEN: ${RED}NOT SET or placeholder${NC}"
        fi
    else
        echo -e "  CLOUDFLARE_API_TOKEN: ${RED}NOT FOUND in .env${NC}"
    fi

    if grep -q "CLOUDFLARE_EMAIL" "$ENV_FILE"; then
        echo -e "  CLOUDFLARE_EMAIL: ${GREEN}Set${NC}"
    else
        echo -e "  CLOUDFLARE_EMAIL: ${RED}NOT SET${NC}"
    fi
else
    echo -e "  ${RED}.env file NOT FOUND${NC}"
fi

echo ""

# 4. Check Traefik container environment
echo -e "${YELLOW}[4] Checking Traefik container environment...${NC}"
echo ""

CF_EMAIL=$(docker exec traefik env 2>/dev/null | grep "CF_API_EMAIL=" | cut -d= -f2)
CF_TOKEN=$(docker exec traefik env 2>/dev/null | grep "CF_DNS_API_TOKEN=" | cut -d= -f2)

if [ -n "$CF_EMAIL" ]; then
    echo -e "  CF_API_EMAIL: ${GREEN}$CF_EMAIL${NC}"
else
    echo -e "  CF_API_EMAIL: ${RED}NOT SET in container${NC}"
fi

if [ -n "$CF_TOKEN" ] && [ ${#CF_TOKEN} -gt 10 ]; then
    echo -e "  CF_DNS_API_TOKEN: ${GREEN}Set (${#CF_TOKEN} chars)${NC}"
elif [ -n "$CF_TOKEN" ]; then
    echo -e "  CF_DNS_API_TOKEN: ${YELLOW}Set but seems too short (${#CF_TOKEN} chars)${NC}"
else
    echo -e "  CF_DNS_API_TOKEN: ${RED}NOT SET in container${NC}"
fi

echo ""

# 5. Check Traefik config
echo -e "${YELLOW}[5] Checking Traefik configuration...${NC}"
echo ""

if [ -f "../traefik/config/traefik.yml" ]; then
    echo -e "  Static config: ${GREEN}Found${NC}"

    # Check for certificatesResolvers
    if grep -q "certificatesResolvers:" "../traefik/config/traefik.yml"; then
        echo -e "  certificatesResolvers: ${GREEN}Configured${NC}"
    else
        echo -e "  certificatesResolvers: ${RED}NOT FOUND${NC}"
    fi

    # Check for dnsChallenge
    if grep -q "dnsChallenge:" "../traefik/config/traefik.yml"; then
        echo -e "  dnsChallenge: ${GREEN}Configured${NC}"
        PROVIDER=$(grep "provider:" "../traefik/config/traefik.yml" | grep -v "#" | awk '{print $2}')
        echo -e "  Provider: $PROVIDER"
    else
        echo -e "  dnsChallenge: ${RED}NOT FOUND${NC}"
    fi
else
    echo -e "  ${RED}traefik.yml NOT FOUND${NC}"
fi

echo ""

# 6. Recommendations
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Diagnosis & Recommendations${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Analyze and provide recommendations
HAS_ERRORS=0

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}1. Create .env file with Cloudflare credentials${NC}"
    echo "   cd ../traefik"
    echo "   ./scripts/setup-traefik-secrets.sh"
    echo ""
    HAS_ERRORS=1
elif ! grep -q "CLOUDFLARE_API_TOKEN" "$ENV_FILE"; then
    echo -e "${RED}2. CLOUDFLARE_API_TOKEN is missing from .env${NC}"
    echo "   Add your Cloudflare API token to ../traefik/.env"
    echo ""
    HAS_ERRORS=1
fi

if [ -z "$CF_TOKEN" ]; then
    echo -e "${RED}3. Traefik container doesn't have Cloudflare token${NC}"
    echo "   Restart Traefik after setting credentials:"
    echo "   cd ../traefik && docker compose restart"
    echo ""
    HAS_ERRORS=1
fi

if [ "$PERMS" != "600" ] && [ -f "$ACME_FILE" ]; then
    echo -e "${YELLOW}4. Fix acme.json permissions${NC}"
    echo "   chmod 600 ../traefik/config/acme.json"
    echo ""
fi

if [ $HAS_ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Configuration looks good!${NC}"
    echo ""
    echo "If certificates still aren't generating:"
    echo "1. Check Traefik logs: docker logs traefik -f"
    echo "2. Wait 1-2 minutes for Let's Encrypt to issue certificates"
    echo "3. Verify Cloudflare DNS records exist for *.lab.nexuswarrior.site"
    echo "4. Check Cloudflare API token has DNS:Edit permissions"
    echo ""
fi

echo -e "${BLUE}======================================${NC}"
echo ""
