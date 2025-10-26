#!/bin/bash

# Teaching VM Secrets Generation Script
# Run this ON the teaching VM (192.168.10.29)
# This script will generate all the secrets you need for GitHub

set -e

echo "=================================================="
echo "Teaching VM Secrets Generation"
echo "=================================================="
echo ""
echo "This script will generate secrets for:"
echo "  1. Coder database password"
echo "  2. Traefik dashboard password"
echo "  3. SSH deployment key"
echo ""
echo "You'll need:"
echo "  - Cloudflare API token (from dashboard)"
echo "  - Cloudflare email"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

echo ""
echo "=================================================="
echo "1. Generating Coder Database Password"
echo "=================================================="
CODER_DB_PASSWORD=$(openssl rand -base64 32)
echo "✅ Generated Coder database password"
echo ""

echo "=================================================="
echo "2. Generating Traefik Dashboard Password"
echo "=================================================="
echo "Enter username for Traefik dashboard (default: admin):"
read -p "Username: " TRAEFIK_USER
TRAEFIK_USER=${TRAEFIK_USER:-admin}

echo "Enter password for Traefik dashboard:"
read -sp "Password: " TRAEFIK_PASSWORD
echo ""

# Generate hashed password (double escape $ for docker-compose)
TRAEFIK_HASHED=$(echo $(htpasswd -nB "$TRAEFIK_USER" <<< "$TRAEFIK_PASSWORD") | sed -e s/\\$/\\$\\$/g)
echo "✅ Generated Traefik hashed password"
echo ""

echo "=================================================="
echo "3. Generating SSH Deployment Key"
echo "=================================================="
SSH_KEY_PATH="$HOME/.ssh/github_deploy_teaching"

if [ -f "$SSH_KEY_PATH" ]; then
    echo "⚠️  SSH key already exists at $SSH_KEY_PATH"
    read -p "Overwrite? (y/N): " overwrite
    if [ "$overwrite" != "y" ]; then
        echo "Using existing key..."
    else
        rm -f "$SSH_KEY_PATH" "$SSH_KEY_PATH.pub"
        ssh-keygen -t ed25519 -C "github-actions-teaching" -f "$SSH_KEY_PATH" -N ""
        echo "✅ Generated new SSH key"
    fi
else
    ssh-keygen -t ed25519 -C "github-actions-teaching" -f "$SSH_KEY_PATH" -N ""
    echo "✅ Generated new SSH key"
fi

# Add public key to authorized_keys
if ! grep -q "github-actions-teaching" "$HOME/.ssh/authorized_keys" 2>/dev/null; then
    cat "$SSH_KEY_PATH.pub" >> "$HOME/.ssh/authorized_keys"
    echo "✅ Added public key to authorized_keys"
else
    echo "ℹ️  Public key already in authorized_keys"
fi

chmod 600 "$SSH_KEY_PATH"
chmod 644 "$SSH_KEY_PATH.pub"
chmod 600 "$HOME/.ssh/authorized_keys"

echo ""
echo "=================================================="
echo "4. Cloudflare Configuration"
echo "=================================================="
echo "Get your Cloudflare API token from:"
echo "https://dash.cloudflare.com/profile/api-tokens"
echo ""
echo "Token Permissions needed:"
echo "  - Zone / DNS / Edit"
echo "  - Include / Specific zone / lab.nexuswarrior.site"
echo ""
read -p "Enter Cloudflare email: " CLOUDFLARE_EMAIL
read -p "Enter Cloudflare API token: " CLOUDFLARE_API_TOKEN
echo ""

echo "=================================================="
echo "5. Deployment Configuration"
echo "=================================================="
DEPLOY_HOST=$(hostname -I | awk '{print $1}')
DEPLOY_USER=$(whoami)
DEPLOY_PATH="$HOME/docker-configs"

echo "Detected configuration:"
echo "  Host: $DEPLOY_HOST"
echo "  User: $DEPLOY_USER"
echo "  Path: $DEPLOY_PATH"
echo ""
read -p "Is this correct? (Y/n): " confirm
if [ "$confirm" == "n" ]; then
    read -p "Enter deploy host IP: " DEPLOY_HOST
    read -p "Enter deploy user: " DEPLOY_USER
    read -p "Enter deploy path: " DEPLOY_PATH
fi

echo ""
echo "=================================================="
echo "✅ All secrets generated!"
echo "=================================================="
echo ""

# Save to a temporary file
SECRETS_FILE="/tmp/teaching-vm-secrets.txt"
cat > "$SECRETS_FILE" << EOF
================================================
GitHub Secrets for Teaching VM
================================================

Add these to GitHub:
  Settings → Secrets and variables → Actions → New repository secret

------------------------------------------------
1. TEACHING_DEPLOY_SSH_KEY
------------------------------------------------
$(cat "$SSH_KEY_PATH")

------------------------------------------------
2. TEACHING_DEPLOY_HOST
------------------------------------------------
$DEPLOY_HOST

------------------------------------------------
3. TEACHING_DEPLOY_USER
------------------------------------------------
$DEPLOY_USER

------------------------------------------------
4. TEACHING_DEPLOY_PATH
------------------------------------------------
$DEPLOY_PATH

------------------------------------------------
5. TEACHING_CLOUDFLARE_EMAIL
------------------------------------------------
$CLOUDFLARE_EMAIL

------------------------------------------------
6. TEACHING_CLOUDFLARE_API_TOKEN
------------------------------------------------
$CLOUDFLARE_API_TOKEN

------------------------------------------------
7. TEACHING_TRAEFIK_DASH_USER
------------------------------------------------
$TRAEFIK_USER

------------------------------------------------
8. TEACHING_TRAEFIK_DASH_PASSWORD
------------------------------------------------
$TRAEFIK_HASHED

------------------------------------------------
9. TEACHING_CODER_DB_PASSWORD
------------------------------------------------
$CODER_DB_PASSWORD

================================================
Quick Reference
================================================

Traefik Dashboard:
  https://traefik.lab.nexuswarrior.site
  Username: $TRAEFIK_USER
  Password: [the password you entered]

Coder Dashboard:
  https://coder.lab.nexuswarrior.site

SSH Test:
  ssh -i ~/.ssh/github_deploy_teaching $DEPLOY_USER@$DEPLOY_HOST

================================================
SECURITY WARNING
================================================

This file contains sensitive secrets!
  Location: $SECRETS_FILE

After adding to GitHub:
  rm $SECRETS_FILE

DO NOT commit this file to git!
EOF

echo "✅ Secrets saved to: $SECRETS_FILE"
echo ""
echo "📋 Next steps:"
echo "   1. Open this file: cat $SECRETS_FILE"
echo "   2. Copy each secret to GitHub"
echo "   3. Delete the file: rm $SECRETS_FILE"
echo ""
echo "🔗 Add secrets here:"
echo "   https://github.com/YOUR_USERNAME/docker-configs/settings/secrets/actions"
echo ""

# Also create .env files for local testing
echo "=================================================="
echo "Creating local .env files for testing..."
echo "=================================================="

# Traefik .env
TRAEFIK_ENV="$DEPLOY_PATH/teaching/traefik/.env"
mkdir -p "$(dirname "$TRAEFIK_ENV")"
cat > "$TRAEFIK_ENV" << EOF
CLOUDFLARE_EMAIL=$CLOUDFLARE_EMAIL
CLOUDFLARE_API_TOKEN=$CLOUDFLARE_API_TOKEN
DOMAIN=lab.nexuswarrior.site
TRAEFIK_DASHBOARD_USER=$TRAEFIK_USER
TRAEFIK_DASHBOARD_PASSWORD=$TRAEFIK_HASHED
EOF
echo "✅ Created: $TRAEFIK_ENV"

# Coder .env
CODER_ENV="$DEPLOY_PATH/teaching/coder/.env"
mkdir -p "$(dirname "$CODER_ENV")"
cat > "$CODER_ENV" << EOF
CODER_DB_PASSWORD=$CODER_DB_PASSWORD
EOF
echo "✅ Created: $CODER_ENV"

echo ""
echo "=================================================="
echo "✅ Setup Complete!"
echo "=================================================="
echo ""
echo "Secrets file: $SECRETS_FILE"
echo "View it with: cat $SECRETS_FILE"
echo ""
