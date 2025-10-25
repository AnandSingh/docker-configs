# GitHub Secrets Configuration Guide

This guide explains all GitHub Secrets needed for automated deployment.

## Overview

GitHub Secrets are encrypted environment variables that are securely passed to your homelab server during deployment. The `setup-secrets.sh` script automatically creates `.env` files from these secrets.

## How It Works

```
GitHub Secrets
    ↓
GitHub Actions Workflow
    ↓
SSH to Homelab (secrets passed as env vars)
    ↓
setup-secrets.sh creates .env files
    ↓
Docker Compose uses .env files
```

## Required GitHub Secrets

Go to: **Your Repository → Settings → Secrets and variables → Actions → New repository secret**

### 🔐 Deployment Secrets (Required)

| Secret Name | Description | Example | Required |
|-------------|-------------|---------|----------|
| `DEPLOY_SSH_KEY` | Private SSH key for accessing homelab | Contents of `~/.ssh/id_ed25519` | ✅ Yes |
| `DEPLOY_HOST` | Homelab server IP or hostname | `192.168.1.100` or `homelab.local` | ✅ Yes |
| `DEPLOY_USER` | SSH username on homelab server | `ubuntu` or `anand` | ✅ Yes |
| `DEPLOY_PATH` | Absolute path to docker-configs | `/home/ubuntu/docker-configs` | ✅ Yes |

### 🌐 Traefik Secrets (Required for Traefik)

| Secret Name | Description | Example | Required |
|-------------|-------------|---------|----------|
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token for DNS challenge | `abc123...` | ✅ Yes |
| `CLOUDFLARE_EMAIL` | Your Cloudflare account email | `you@example.com` | ✅ Yes |
| `TRAEFIK_DASHBOARD_USER` | Username for Traefik dashboard | `admin` | ✅ Yes |
| `TRAEFIK_DASHBOARD_PASSWORD` | Password for Traefik dashboard | `SecurePassword123!` | ✅ Yes |
| `DOMAIN` | Your primary domain | `plexlab.site` | ✅ Yes |

### 🛡️ Service Secrets (Optional but Recommended)

| Secret Name | Description | Example | Required |
|-------------|-------------|---------|----------|
| `PIHOLE_PASSWORD` | Pi-hole admin interface password | `MyPiholePass123` | Recommended |
| `PIHOLE_DOMAIN` | Pi-hole domain | `nexuswarrior.site` | Optional |
| `CODE_SERVER_PASSWORD` | Code-server login password | `CodePass123` | Optional |
| `HOMEPAGE_DOMAIN` | Homepage dashboard domain | `list.plexlab.site` | Optional |
| `CODE_SERVER_DOMAIN` | Code-server base domain | `tinkeringturtle.site` | Optional |

## Step-by-Step Setup

### 1. Create SSH Key for Deployment

**On your homelab server:**

```bash
# Generate dedicated deployment key
ssh-keygen -t ed25519 -C "github-deploy" -f ~/.ssh/github_deploy

# Don't set a passphrase (press Enter)

# Add public key to authorized_keys
cat ~/.ssh/github_deploy.pub >> ~/.ssh/authorized_keys

# Set proper permissions
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh

# Display private key (copy this for GitHub)
cat ~/.ssh/github_deploy
```

**Copy the entire output** including:
```
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

### 2. Create Cloudflare API Token

1. Go to: https://dash.cloudflare.com/profile/api-tokens
2. Click **"Create Token"**
3. Use **"Edit zone DNS"** template or create custom token with:
   - **Permissions:**
     - Zone → DNS → Edit
     - Zone → Zone → Read
   - **Zone Resources:**
     - Include → Specific zone → Select your domain
4. Click **"Continue to summary"** → **"Create Token"**
5. **Copy the token** (you won't see it again!)

### 3. Generate Traefik Dashboard Password

**Option 1: Using htpasswd (Linux/Mac)**

```bash
# Install apache2-utils if needed
sudo apt-get install apache2-utils  # Ubuntu/Debian
brew install httpd                   # macOS

# Generate password (replace 'admin' and 'yourpassword')
echo $(htpasswd -nb admin yourpassword)

# Output example:
# admin:$apr1$xyz123$abc...

# Use the ENTIRE string as TRAEFIK_DASHBOARD_PASSWORD
```

**Option 2: Online Generator**

1. Go to: https://hostingcanada.org/htpasswd-generator/
2. Enter username: `admin`
3. Enter your password
4. Copy the generated string
5. Use as `TRAEFIK_DASHBOARD_PASSWORD`

**Option 3: Plain password (Less secure)**

Just use a strong password. The script will handle it, but htpasswd format is more secure.

### 4. Add Secrets to GitHub

For **each secret** below:

1. Go to: **Repository → Settings → Secrets and variables → Actions**
2. Click **"New repository secret"**
3. Enter the **Name** from table
4. Paste the **Value**
5. Click **"Add secret"**

#### Deployment Secrets

```bash
# DEPLOY_SSH_KEY
# Paste entire private key from ~/.ssh/github_deploy

# DEPLOY_HOST
192.168.1.100

# DEPLOY_USER
ubuntu

# DEPLOY_PATH
/home/ubuntu/docker-configs
```

#### Traefik Secrets

```bash
# CLOUDFLARE_API_TOKEN
your_cloudflare_token_from_dashboard

# CLOUDFLARE_EMAIL
your.email@example.com

# TRAEFIK_DASHBOARD_USER
admin

# TRAEFIK_DASHBOARD_PASSWORD
admin:$apr1$xyz123$abc...
# (Or just a plain password)

# DOMAIN
plexlab.site
```

#### Service Secrets

```bash
# PIHOLE_PASSWORD
MySecurePiholePassword123

# PIHOLE_DOMAIN
nexuswarrior.site

# CODE_SERVER_PASSWORD
MyCodeServerPass456

# HOMEPAGE_DOMAIN
list.plexlab.site

# CODE_SERVER_DOMAIN
tinkeringturtle.site
```

## Verification

### Test Secrets Setup Locally

**On your homelab server:**

```bash
cd /home/ubuntu/docker-configs

# Set environment variables manually for testing
export CLOUDFLARE_API_TOKEN="your_token"
export TRAEFIK_DASHBOARD_USER="admin"
export TRAEFIK_DASHBOARD_PASSWORD="your_password"
export DOMAIN="plexlab.site"
# ... (set others as needed)

# Run setup script
./deploy/setup-secrets.sh

# Check created files
ls -la traefik/.env
ls -la traefik/cf-token
cat traefik/.env  # Should show your values
```

### Test GitHub Actions

1. Make a small change (e.g., add a comment to README)
2. Commit and push:
   ```bash
   git add .
   git commit -m "Test automated deployment"
   git push origin main
   ```
3. Go to **Actions** tab in GitHub
4. Watch the workflow run
5. Check logs for any errors

## Security Best Practices

### ✅ Do's

- ✅ Use dedicated SSH keys (not your personal key)
- ✅ Use strong, unique passwords for each service
- ✅ Rotate secrets regularly (every 90 days)
- ✅ Use htpasswd-hashed passwords when possible
- ✅ Limit Cloudflare token to specific zones only
- ✅ Review GitHub Actions logs for exposed secrets

### ❌ Don'ts

- ❌ Never commit secrets to git
- ❌ Never share GitHub secret values
- ❌ Don't use the same password for multiple services
- ❌ Don't use weak passwords (use 16+ chars)
- ❌ Don't give Cloudflare token global permissions

## Troubleshooting

### Secret Not Being Used

**Problem:** Service shows default password or missing configuration

**Solution:**
1. Verify secret exists in GitHub: **Settings → Secrets → Actions**
2. Check secret name matches exactly (case-sensitive)
3. Re-run deployment workflow
4. Check deployment logs for errors

### SSH Connection Failed

**Problem:** `Permission denied (publickey)`

**Solution:**
1. Verify `DEPLOY_SSH_KEY` contains **entire private key** including headers
2. Check public key is in `~/.ssh/authorized_keys` on server
3. Test SSH manually:
   ```bash
   ssh -i ~/.ssh/github_deploy ubuntu@192.168.1.100
   ```
4. Check SSH server is running:
   ```bash
   sudo systemctl status ssh
   ```

### Cloudflare Token Invalid

**Problem:** `Error creating certificate: ACME error`

**Solution:**
1. Verify token has correct permissions:
   - Zone → DNS → Edit
   - Zone → Zone → Read
2. Check token isn't expired (check Cloudflare dashboard)
3. Verify `CLOUDFLARE_EMAIL` matches your Cloudflare account
4. Create a new token if needed

### Secrets Not Showing in Logs

**Problem:** Can't see secret values in GitHub Actions logs

**Note:** This is **expected behavior** - GitHub automatically masks secrets in logs for security. You'll see `***` instead of actual values.

To verify secrets are set:
```yaml
- name: Check secrets exist
  run: |
    if [ -z "${{ secrets.CLOUDFLARE_API_TOKEN }}" ]; then
      echo "CLOUDFLARE_API_TOKEN not set"
    fi
```

## Updating Secrets

### To Update a Secret:

1. Go to: **Repository → Settings → Secrets and variables → Actions**
2. Find the secret you want to update
3. Click the **pencil icon** (Edit)
4. Enter new value
5. Click **"Update secret"**
6. Re-run deployment or push a change to trigger automatic deployment

### Rotating Secrets (Recommended Every 90 Days)

```bash
# 1. Create new SSH key
ssh-keygen -t ed25519 -C "github-deploy-2025" -f ~/.ssh/github_deploy_new

# 2. Add to authorized_keys
cat ~/.ssh/github_deploy_new.pub >> ~/.ssh/authorized_keys

# 3. Update DEPLOY_SSH_KEY in GitHub with new private key

# 4. Test deployment

# 5. Remove old key from authorized_keys
# Edit ~/.ssh/authorized_keys and remove the old key line
```

## Advanced: Restricting SSH Key

For better security, restrict the deployment SSH key to only run the deployment script.

**Edit `~/.ssh/authorized_keys` on homelab server:**

```bash
# Add this before the key:
command="/home/ubuntu/docker-configs/deploy/deploy.sh all",no-port-forwarding,no-X11-forwarding,no-agent-forwarding ssh-ed25519 AAAA...yourkey...
```

Now this key can **only** run the deployment script and nothing else.

## Reference: Complete Secret List

### Minimal Setup (Core Services Only)

```
DEPLOY_SSH_KEY
DEPLOY_HOST
DEPLOY_USER
DEPLOY_PATH
CLOUDFLARE_API_TOKEN
CLOUDFLARE_EMAIL
TRAEFIK_DASHBOARD_USER
TRAEFIK_DASHBOARD_PASSWORD
DOMAIN
```

### Full Setup (All Services)

```
# Deployment
DEPLOY_SSH_KEY
DEPLOY_HOST
DEPLOY_USER
DEPLOY_PATH

# Traefik
CLOUDFLARE_API_TOKEN
CLOUDFLARE_EMAIL
TRAEFIK_DASHBOARD_USER
TRAEFIK_DASHBOARD_PASSWORD
DOMAIN

# Services
PIHOLE_PASSWORD
PIHOLE_DOMAIN
CODE_SERVER_PASSWORD
HOMEPAGE_DOMAIN
CODE_SERVER_DOMAIN
```

## Support

If you encounter issues:

1. Check GitHub Actions logs: **Actions tab → Select workflow → View logs**
2. SSH to homelab and check: `tail -f /home/ubuntu/docker-configs/deploy/deploy.log`
3. Verify secrets manually: Run `./deploy/setup-secrets.sh` with exported env vars
4. Check service logs: `docker compose logs` in service directory

---

**Last Updated:** 2025-01-24
