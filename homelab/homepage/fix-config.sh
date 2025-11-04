#!/bin/bash
# Fix homepage configuration on server
# Run this on the homelab server to verify and fix config

set -e

echo "🔍 Checking homepage configuration..."

# Check if config directory exists
if [ ! -d "config" ]; then
    echo "❌ Config directory not found!"
    echo "Creating config directory..."
    mkdir -p config
fi

# Check if config files exist
echo ""
echo "📁 Checking config files:"
for file in bookmarks.yaml docker.yaml services.yaml settings.yaml widgets.yaml; do
    if [ -f "config/$file" ]; then
        echo "  ✅ config/$file exists ($(wc -l < config/$file) lines)"
    else
        echo "  ❌ config/$file is missing!"
    fi
done

# Check container status
echo ""
echo "🐳 Checking homepage container:"
docker compose ps homepage

# Show container logs (last 20 lines)
echo ""
echo "📋 Recent homepage logs:"
docker compose logs --tail=20 homepage

# Check if volume is mounted correctly
echo ""
echo "🔗 Checking volume mounts:"
docker inspect homepage | grep -A10 "Mounts"

echo ""
echo "===== DIAGNOSIS COMPLETE ====="
echo ""
echo "If config files are missing, run:"
echo "  git pull origin main"
echo "  docker compose restart"
