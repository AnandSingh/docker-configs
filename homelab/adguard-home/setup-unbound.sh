#!/bin/bash
# Setup Unbound DNS - Download root hints and initialize DNSSEC trust anchor

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}======================================"
echo "Unbound DNS Setup"
echo -e "======================================${NC}\n"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config/unbound"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Step 1: Download root hints
echo -e "${BLUE}[1/3] Downloading DNS root hints...${NC}"
curl -fsSL -o "$CONFIG_DIR/root.hints" https://www.internic.net/domain/named.root

if [ -f "$CONFIG_DIR/root.hints" ]; then
    SIZE=$(stat -f%z "$CONFIG_DIR/root.hints" 2>/dev/null || stat -c%s "$CONFIG_DIR/root.hints" 2>/dev/null)
    echo -e "${GREEN}✓ Downloaded root hints (${SIZE} bytes)${NC}\n"
else
    echo "Error: Failed to download root hints"
    exit 1
fi

# Step 2: Initialize DNSSEC root key
echo -e "${BLUE}[2/3] Initializing DNSSEC root key...${NC}"

# Create initial root.key file with current trust anchor
# This is the ICANN root KSK-2024 (current as of 2024)
cat > "$CONFIG_DIR/root.key" << 'EOF'
; autotrust trust anchor file
;;id: . 1
;;last_queried: 1609459200 ;;Fri Jan  1 00:00:00 2021
;;last_success: 1609459200 ;;Fri Jan  1 00:00:00 2021
;;next_probe_time: 1609545600 ;;next probe
;;query_failed: 0
;;query_interval: 43200 ;;12 hours
;;retry_time: 900 ;;15 minutes
.   172800  IN  DNSKEY  257 3 8 AwEAAaz/tAm8yTn4Mfeh5eyI96WSVexTBAvkMgJzkKTOiW1vkIbzxeF3+/4RgWOq7HrxRixHlFlExOLAJr5emLvN7SWXgnLh4+B5xQlNVz8Og8kvArMtNROxVQuCaSnIDdD5LKyWbRd2n9WGe2R8PzgCmr3EgVLrjyBxWezF0jLHwVN8efS3rCj/EWgvIWgb9tarpVUDK/b58Da+sqqls3eNbuv7pr+eoZG+SrDK6nWeL3c6H5Apxz7LjVc1uTIdsIXxuOLYA4/ilBmSVIzuDWfdRUfhHdY6+cn8HFRm+2hM8AnXGXws9555KrUB5qihylGa8subX2Nn6UwNR1AkUTV74bU=
EOF

chmod 644 "$CONFIG_DIR/root.key"
echo -e "${GREEN}✓ Created DNSSEC root key${NC}\n"

# Step 3: Set permissions
echo -e "${BLUE}[3/3] Setting permissions...${NC}"
chmod 755 "$CONFIG_DIR"
chmod 644 "$CONFIG_DIR/root.hints"
chmod 644 "$CONFIG_DIR/root.key"

echo -e "${GREEN}✓ Permissions set${NC}\n"

# Summary
echo -e "${GREEN}======================================"
echo "✓ Unbound setup complete!"
echo -e "======================================${NC}\n"

echo "Files created:"
echo "  - $CONFIG_DIR/root.hints (DNS root servers)"
echo "  - $CONFIG_DIR/root.key (DNSSEC trust anchor)"
echo ""
echo "Next: docker compose restart unbound"
