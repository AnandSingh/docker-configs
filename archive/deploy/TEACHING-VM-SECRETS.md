# Teaching VM Secrets Management

## Overview

This guide explains how to manage secrets for the teaching VM (192.168.10.29) using GitHub Secrets and automated deployment.

## Required Secrets for Teaching VM

### 1. Traefik Secrets
```
TEACHING_CLOUDFLARE_API_TOKEN   - Cloudflare DNS API token for Let's Encrypt
TEACHING_CLOUDFLARE_EMAIL       - Cloudflare account email
TEACHING_TRAEFIK_DASH_USER      - Traefik dashboard username
TEACHING_TRAEFIK_DASH_PASSWORD  - Traefik dashboard password (hashed)
```

### 2. Coder Secrets
```
TEACHING_CODER_DB_PASSWORD      - PostgreSQL database password for Coder
```

### 3. SSH Deployment Secrets
```
TEACHING_DEPLOY_SSH_KEY         - SSH private key for deploying to teaching VM
TEACHING_DEPLOY_HOST            - Teaching VM IP (192.168.10.29)
TEACHING_DEPLOY_USER            - SSH username on teaching VM
TEACHING_DEPLOY_PATH            - Path to docker-configs on teaching VM
```

## Setting Up GitHub Secrets

### Step 1: Generate Secrets

**On Teaching VM (192.168.10.29):**

```bash
# 1. Generate Coder database password
openssl rand -base64 32
# Save this as TEACHING_CODER_DB_PASSWORD

# 2. Generate Traefik dashboard password hash
echo $(htpasswd -nB admin) | sed -e s/\\$/\\$\\$/g
# Save this as TEACHING_TRAEFIK_DASH_PASSWORD

# 3. Get Cloudflare API token
# Go to: https://dash.cloudflare.com/profile/api-tokens
# Create token with Zone:DNS:Edit permissions for lab.nexuswarrior.site
# Save as TEACHING_CLOUDFLARE_API_TOKEN

# 4. Generate SSH deployment key
ssh-keygen -t ed25519 -C "github-actions-teaching" -f ~/.ssh/github_deploy_teaching
# Add public key to ~/.ssh/authorized_keys on teaching VM
cat ~/.ssh/github_deploy_teaching.pub >> ~/.ssh/authorized_keys
# Save private key as TEACHING_DEPLOY_SSH_KEY
cat ~/.ssh/github_deploy_teaching
```

### Step 2: Add Secrets to GitHub

**Go to GitHub repository:**
1. Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each secret:

| Name | Value | Notes |
|------|-------|-------|
| `TEACHING_DEPLOY_SSH_KEY` | Contents of `~/.ssh/github_deploy_teaching` | Private key for SSH |
| `TEACHING_DEPLOY_HOST` | `192.168.10.29` | Teaching VM IP |
| `TEACHING_DEPLOY_USER` | `dev` or your username | SSH username |
| `TEACHING_DEPLOY_PATH` | `/home/dev/docker-configs` | Repo path on VM |
| `TEACHING_CLOUDFLARE_API_TOKEN` | From Cloudflare dashboard | DNS API token |
| `TEACHING_CLOUDFLARE_EMAIL` | `your-email@example.com` | Cloudflare email |
| `TEACHING_TRAEFIK_DASH_USER` | `admin` | Dashboard username |
| `TEACHING_TRAEFIK_DASH_PASSWORD` | Hashed password from htpasswd | Dashboard password |
| `TEACHING_CODER_DB_PASSWORD` | Generated password | Coder database |

## GitHub Actions Workflow

### Create `.github/workflows/deploy-teaching.yml`:

```yaml
name: Deploy Teaching VM

on:
  push:
    branches: [ main ]
    paths:
      - 'teaching/**'
      - 'deploy/deploy-teaching.sh'
      - '.github/workflows/deploy-teaching.yml'
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup SSH
        env:
          SSH_PRIVATE_KEY: ${{ secrets.TEACHING_DEPLOY_SSH_KEY }}
        run: |
          mkdir -p ~/.ssh
          echo "$SSH_PRIVATE_KEY" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
          ssh-keyscan -H ${{ secrets.TEACHING_DEPLOY_HOST }} >> ~/.ssh/known_hosts

      - name: Deploy to Teaching VM
        env:
          TEACHING_HOST: ${{ secrets.TEACHING_DEPLOY_HOST }}
          TEACHING_USER: ${{ secrets.TEACHING_DEPLOY_USER }}
          TEACHING_PATH: ${{ secrets.TEACHING_DEPLOY_PATH }}
          CLOUDFLARE_API_TOKEN: ${{ secrets.TEACHING_CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_EMAIL: ${{ secrets.TEACHING_CLOUDFLARE_EMAIL }}
          TRAEFIK_DASH_USER: ${{ secrets.TEACHING_TRAEFIK_DASH_USER }}
          TRAEFIK_DASH_PASSWORD: ${{ secrets.TEACHING_TRAEFIK_DASH_PASSWORD }}
          CODER_DB_PASSWORD: ${{ secrets.TEACHING_CODER_DB_PASSWORD }}
        run: |
          ssh -i ~/.ssh/id_ed25519 $TEACHING_USER@$TEACHING_HOST << 'ENDSSH'
            set -e

            # Navigate to repo
            cd ${{ secrets.TEACHING_DEPLOY_PATH }}

            # Pull latest changes
            git pull origin main

            # Create .env files with secrets

            # Traefik .env
            cat > teaching/traefik/.env << 'EOF'
          CLOUDFLARE_EMAIL=${{ secrets.TEACHING_CLOUDFLARE_EMAIL }}
          CLOUDFLARE_API_TOKEN=${{ secrets.TEACHING_CLOUDFLARE_API_TOKEN }}
          DOMAIN=lab.nexuswarrior.site
          TRAEFIK_DASHBOARD_USER=${{ secrets.TEACHING_TRAEFIK_DASH_USER }}
          TRAEFIK_DASHBOARD_PASSWORD=${{ secrets.TEACHING_TRAEFIK_DASH_PASSWORD }}
          EOF

            # Coder .env
            cat > teaching/coder/.env << 'EOF'
          CODER_DB_PASSWORD=${{ secrets.TEACHING_CODER_DB_PASSWORD }}
          EOF

            # Deploy services
            bash deploy/deploy.sh --server teaching all
          ENDSSH

      - name: Verify Deployment
        env:
          TEACHING_HOST: ${{ secrets.TEACHING_DEPLOY_HOST }}
          TEACHING_USER: ${{ secrets.TEACHING_DEPLOY_USER }}
          TEACHING_PATH: ${{ secrets.TEACHING_DEPLOY_PATH }}
        run: |
          ssh -i ~/.ssh/id_ed25519 $TEACHING_USER@$TEACHING_HOST << 'ENDSSH'
            cd ${{ secrets.TEACHING_DEPLOY_PATH }}/teaching

            echo "=== Traefik Status ==="
            docker compose -f traefik/docker-compose.yaml ps

            echo "=== Coder Status ==="
            docker compose -f coder/docker-compose.yaml ps
          ENDSSH
```

## Manual Deployment (First Time)

### On Your Local Machine:

```bash
# 1. SSH to teaching VM
ssh dev@192.168.10.29

# 2. Clone repository
cd ~
git clone git@github.com:YOUR_USERNAME/docker-configs.git
cd docker-configs

# 3. Create Traefik .env
cd teaching/traefik
cat > .env << 'EOF'
CLOUDFLARE_EMAIL=your-email@example.com
CLOUDFLARE_API_TOKEN=your-cloudflare-api-token
DOMAIN=lab.nexuswarrior.site
TRAEFIK_DASHBOARD_USER=admin
TRAEFIK_DASHBOARD_PASSWORD=$$apr1$$hashed$$password
EOF

# 4. Create Coder .env
cd ../coder
cat > .env << 'EOF'
CODER_DB_PASSWORD=your-generated-password
EOF

# 5. Create proxy network
docker network create proxy

# 6. Deploy Traefik first
cd ../traefik
docker compose up -d
docker compose logs -f

# 7. Deploy Coder
cd ../coder
docker compose up -d
docker compose logs -f

# 8. Access Coder
# Open: https://coder.lab.nexuswarrior.site
# Create admin account
```

## Security Best Practices

1. **Never commit secrets to git**
   - Always use `.env` files (ignored by git)
   - Use GitHub Secrets for CI/CD

2. **Rotate secrets regularly**
   - Update Cloudflare API tokens annually
   - Rotate database passwords quarterly

3. **Use strong passwords**
   - Minimum 32 characters for database passwords
   - Use `openssl rand -base64 32`

4. **SSH key management**
   - Use separate SSH keys for deployment
   - Restrict key to specific IP ranges if possible

5. **Monitor access**
   - Review GitHub Actions logs
   - Check Traefik access logs
   - Monitor Coder user activity

## Troubleshooting

### Issue: GitHub Actions can't SSH to teaching VM

**Solution:**
```bash
# On teaching VM, check SSH is running
sudo systemctl status sshd

# Verify authorized_keys
cat ~/.ssh/authorized_keys

# Check SSH logs
sudo tail -f /var/log/auth.log
```

### Issue: .env files not being created

**Solution:**
```bash
# Manually create .env files
cd /path/to/docker-configs/teaching/traefik
cp .env.example .env
nano .env  # Add your secrets

cd ../coder
cp .env.example .env
nano .env  # Add your secrets
```

### Issue: Coder can't start (database password error)

**Solution:**
```bash
# Check Coder logs
cd /path/to/docker-configs/teaching/coder
docker compose logs coder

# Verify .env file exists and has password
cat .env

# Regenerate password if needed
openssl rand -base64 32
# Update .env and restart
docker compose up -d --force-recreate
```

## Next Steps

1. [ ] Add all secrets to GitHub
2. [ ] Test deployment workflow
3. [ ] Setup automatic deployments
4. [ ] Create Coder workspace template
5. [ ] Migrate kids from code-server

---

**Created:** 2025-10-25
**Last Updated:** 2025-10-25
