# Automated Deployment Setup Guide

This guide will help you set up automated deployment from GitHub to your homelab server.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Initial Setup](#initial-setup)
3. [GitHub Secrets Configuration](#github-secrets-configuration)
4. [Homelab Server Setup](#homelab-server-setup)
5. [Testing the Deployment](#testing-the-deployment)
6. [Manual Deployment](#manual-deployment)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### On Your Homelab Server

- Docker & Docker Compose installed
- Git installed
- SSH server running
- Sudo access for the deployment user

### On GitHub

- Repository with admin access
- Ability to configure GitHub Actions
- Ability to add repository secrets

---

## Initial Setup

### 1. Clone Repository on Homelab Server

```bash
# Choose your deployment location
cd /home/ubuntu  # or your preferred location

# Clone the repository
git clone https://github.com/YOUR_USERNAME/docker-configs.git
cd docker-configs

# Make scripts executable (if not already)
chmod +x deploy/*.sh
```

### 2. Set Up Secrets

**You have two options for managing secrets:**

#### Option A: Automated via GitHub Secrets (Recommended)

Secrets are stored in GitHub and automatically deployed:

1. **Skip manual .env creation** - they'll be created automatically
2. **Configure GitHub Secrets** (see [GITHUB-SECRETS.md](GITHUB-SECRETS.md))
3. **Push to trigger deployment** - secrets are automatically set up

✅ **Best for:** Production use, multiple servers, CI/CD workflows

#### Option B: Manual Setup (Simpler for testing)

Create .env files manually on the server once:

```bash
# Copy the example environment file
cp .env.example .env

# Edit with your actual values
nano .env

# For Traefik specifically
cd traefik
cp .env.example .env
nano .env

# Create Cloudflare token file
cp cf-token.example cf-token
nano cf-token
# Paste your Cloudflare API token and save

cd ..
```

✅ **Best for:** Local testing, single server, manual deployments

**For this guide, we'll use Option A (GitHub Secrets).** See [GITHUB-SECRETS.md](GITHUB-SECRETS.md) for complete setup instructions.

### 3. Create Docker Network

The deployment scripts expect a `proxy` network to exist:

```bash
docker network create proxy
```

---

## GitHub Secrets Configuration

**📖 See [GITHUB-SECRETS.md](GITHUB-SECRETS.md) for complete setup instructions.**

### Quick Summary

You need to configure these GitHub Secrets:

**Settings → Secrets and variables → Actions → New repository secret**

#### Required Secrets

**Deployment:**
- `DEPLOY_SSH_KEY` - Private SSH key for accessing homelab
- `DEPLOY_HOST` - Server IP (e.g., `192.168.1.100`)
- `DEPLOY_USER` - SSH username (e.g., `ubuntu`)
- `DEPLOY_PATH` - Path to repo (e.g., `/home/ubuntu/docker-configs`)

**Traefik & Services:**
- `CLOUDFLARE_API_TOKEN` - From Cloudflare dashboard
- `CLOUDFLARE_EMAIL` - Your Cloudflare email
- `TRAEFIK_DASHBOARD_USER` - Dashboard username (e.g., `admin`)
- `TRAEFIK_DASHBOARD_PASSWORD` - Dashboard password (htpasswd format recommended)
- `DOMAIN` - Your domain (e.g., `plexlab.site`)

**Optional Service Secrets:**
- `PIHOLE_PASSWORD` - Pi-hole admin password
- `CODE_SERVER_PASSWORD` - Code-server password
- `PIHOLE_DOMAIN`, `HOMEPAGE_DOMAIN`, `CODE_SERVER_DOMAIN`

### Quick SSH Key Setup

```bash
# On homelab server
ssh-keygen -t ed25519 -C "github-deploy" -f ~/.ssh/github_deploy
cat ~/.ssh/github_deploy.pub >> ~/.ssh/authorized_keys

# Copy private key to GitHub secret DEPLOY_SSH_KEY
cat ~/.ssh/github_deploy
```

**👉 For detailed instructions including Cloudflare token creation, password hashing, and troubleshooting, see [GITHUB-SECRETS.md](GITHUB-SECRETS.md)**

---

## Homelab Server Setup

### 1. Configure Git

Ensure git is configured for the deployment user:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Configure git to store credentials (if using HTTPS)
git config --global credential.helper store
```

### 2. Test Manual Deployment

Before setting up automation, test the deployment script manually:

```bash
cd /home/ubuntu/docker-configs

# Deploy all services
./deploy/deploy.sh all

# Or deploy specific service
./deploy/deploy.sh traefik
```

### 3. Check Service Health

```bash
# Check all services
./deploy/health-check.sh

# Check specific service
./deploy/health-check.sh traefik
```

### 4. (Optional) Set Up Cron for Automated Pulls

If you prefer cron-based deployment instead of GitHub Actions push:

```bash
# Edit crontab
crontab -e

# Add this line to pull and deploy every 5 minutes
*/5 * * * * cd /home/ubuntu/docker-configs && ./deploy/deploy.sh all >> /home/ubuntu/docker-configs/deploy/cron-deploy.log 2>&1
```

---

## Testing the Deployment

### Method 1: GitHub Actions (Recommended)

1. Make a small change to any file (e.g., update a comment)
2. Commit and push to the `main` branch
3. Go to **Actions** tab in GitHub
4. Watch the workflow run
5. Check your homelab server for updated services

### Method 2: Manual Workflow Trigger

1. Go to **Actions** tab in GitHub
2. Select "Homelab CI/CD" workflow
3. Click "Run workflow"
4. Choose service to deploy (or leave empty for all)
5. Click "Run workflow"

### Method 3: Manual Deployment

SSH into your homelab server and run:

```bash
cd /home/ubuntu/docker-configs
./deploy/deploy.sh all
```

---

## Manual Deployment

### Deploy All Services

```bash
cd /home/ubuntu/docker-configs
./deploy/deploy.sh all
```

### Deploy Specific Service

```bash
./deploy/deploy.sh traefik
./deploy/deploy.sh homepage
./deploy/deploy.sh pihole
./deploy/deploy.sh rustdesk
```

### Check Deployment Logs

```bash
# View deployment log
tail -f /home/ubuntu/docker-configs/deploy/deploy.log

# Check specific service logs
cd traefik
docker compose logs -f
```

### Health Check

```bash
# Check all services
./deploy/health-check.sh

# Check specific service
./deploy/health-check.sh traefik
```

### Rollback

If a deployment fails, you can rollback:

```bash
# List available backups
ls -lt .backups/

# Rollback to latest backup
./deploy/rollback.sh traefik

# Rollback to specific backup
./deploy/rollback.sh traefik 20250124_143022
```

---

## Troubleshooting

### GitHub Actions Fails to Connect

**Error:** `Permission denied (publickey)`

**Solution:**
1. Verify `DEPLOY_SSH_KEY` secret contains the **entire private key** including headers
2. Ensure public key is in `~/.ssh/authorized_keys` on server
3. Check SSH service is running: `sudo systemctl status ssh`

### Deployment Script Fails

**Error:** `docker compose: command not found`

**Solution:**
```bash
# Install docker compose v2
sudo apt-get update
sudo apt-get install docker-compose-plugin
```

**Error:** `Permission denied` when running docker

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER
# Log out and back in
```

### Service Won't Start

**Check logs:**
```bash
cd /path/to/service
docker compose logs
```

**Common issues:**
- Port already in use: `sudo lsof -i :PORT`
- Missing environment variables: Check `.env` file
- Volume permissions: `ls -la` and check ownership

### Network Issues

**Error:** `network proxy not found`

**Solution:**
```bash
docker network create proxy
```

**Check existing networks:**
```bash
docker network ls
```

### Backups Not Working

**Create backup directory:**
```bash
mkdir -p /home/ubuntu/docker-configs/.backups
```

**Check backup retention:**
```bash
ls -lt .backups/ | head -20
```

---

## Advanced Configuration

### Custom Deployment Hooks

You can add custom scripts to run before/after deployment:

**Create hooks directory:**
```bash
mkdir -p deploy/hooks
```

**Pre-deployment hook** (`deploy/hooks/pre-deploy.sh`):
```bash
#!/bin/bash
# Runs before deployment
echo "Running pre-deployment tasks..."
```

**Post-deployment hook** (`deploy/hooks/post-deploy.sh`):
```bash
#!/bin/bash
# Runs after deployment
echo "Running post-deployment tasks..."
./deploy/health-check.sh
```

### Notification Integration

Add webhook notifications to `deploy/deploy.sh`:

```bash
# At the end of successful deployment
curl -X POST $SLACK_WEBHOOK_URL \
  -H 'Content-Type: application/json' \
  -d '{"text":"Deployment completed successfully!"}'
```

---

## Security Best Practices

1. **Use dedicated SSH keys** for deployment (not your personal key)
2. **Restrict SSH key** with `command=` in authorized_keys
3. **Never commit secrets** - always use `.env` files (gitignored)
4. **Regularly rotate** API tokens and passwords
5. **Monitor deployment logs** for suspicious activity
6. **Use firewall rules** to restrict GitHub Actions IP ranges
7. **Enable 2FA** on your GitHub account

---

## Support

For issues or questions:

1. Check deployment logs: `tail -f deploy/deploy.log`
2. Run health check: `./deploy/health-check.sh`
3. Review service logs: `docker compose logs`
4. Check GitHub Actions output for CI/CD issues

---

## Quick Reference

```bash
# Deploy
./deploy/deploy.sh all              # Deploy all services
./deploy/deploy.sh traefik          # Deploy specific service

# Health Check
./deploy/health-check.sh            # Check all services
./deploy/health-check.sh traefik    # Check specific service

# Rollback
./deploy/rollback.sh traefik        # Rollback to latest backup

# Logs
tail -f deploy/deploy.log           # Deployment logs
docker compose logs -f              # Service logs

# Maintenance
docker system prune -a              # Clean up unused resources
docker volume prune                 # Clean up unused volumes
```
