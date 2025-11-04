#!/bin/bash
# Manually sync homepage config files to server
# Run this from your local machine to immediately fix the homepage

set -e

SERVER_USER="dev"
SERVER_IP="192.168.10.13"
SERVER_PATH="/home/dev/docker/docker-configs/homelab/homepage"

echo "🔄 Syncing homepage config to server..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure we're in the homepage directory
cd "$SCRIPT_DIR"

# Check if config directory exists locally
if [ ! -d "config" ]; then
    echo "❌ Config directory not found locally!"
    exit 1
fi

echo "📁 Local config files:"
ls -lh config/*.yaml

# Create config directory on server if it doesn't exist
echo ""
echo "📤 Creating config directory on server..."
ssh ${SERVER_USER}@${SERVER_IP} "mkdir -p ${SERVER_PATH}/config"

# Sync only the YAML config files
echo "📤 Syncing config files to server..."
rsync -avz --progress \
    --include='*.yaml' \
    --include='*.yml' \
    --exclude='*' \
    config/ ${SERVER_USER}@${SERVER_IP}:${SERVER_PATH}/config/

echo ""
echo "✅ Config files synced!"

# Verify on server
echo ""
echo "🔍 Verifying files on server:"
ssh ${SERVER_USER}@${SERVER_IP} "ls -lh ${SERVER_PATH}/config/*.yaml"

# Restart homepage container
echo ""
echo "🔄 Restarting homepage container..."
ssh ${SERVER_USER}@${SERVER_IP} "cd ${SERVER_PATH} && docker compose restart"

echo ""
echo "✅ Done! Homepage should now show your custom config."
echo "🌐 Visit https://plexlab.site to verify"
