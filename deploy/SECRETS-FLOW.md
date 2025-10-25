# Secrets Management Flow

## Visual Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      GitHub Repository                       │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │              GitHub Secrets (Encrypted)             │    │
│  │                                                      │    │
│  │  • CLOUDFLARE_API_TOKEN                             │    │
│  │  • TRAEFIK_DASHBOARD_PASSWORD                       │    │
│  │  • PIHOLE_PASSWORD                                  │    │
│  │  • DEPLOY_SSH_KEY                                   │    │
│  │  • ... (all other secrets)                          │    │
│  └────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │           GitHub Actions Workflow                   │    │
│  │           (.github/workflows/deploy.yml)            │    │
│  │                                                      │    │
│  │  1. Validate docker-compose files                   │    │
│  │  2. SSH to homelab with secrets as env vars         │    │
│  │  3. Trigger deployment                              │    │
│  └────────────────────────────────────────────────────┘    │
└──────────────────────────┬───────────────────────────────────┘
                           │
                           │ SSH Connection
                           │ (Secrets passed as environment variables)
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Homelab Server                            │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │         deploy/deploy.sh (Main Script)              │    │
│  │                                                      │    │
│  │  1. Pull latest code from GitHub                    │    │
│  │  2. Call setup-secrets.sh                           │    │
│  │  3. Deploy services                                 │    │
│  └────────────────────────┬───────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────┐    │
│  │      deploy/setup-secrets.sh (Secrets Manager)      │    │
│  │                                                      │    │
│  │  Reads environment variables and creates:           │    │
│  │                                                      │    │
│  │  ├─▶ .env (root environment file)                   │    │
│  │  ├─▶ traefik/.env (Traefik config)                  │    │
│  │  └─▶ traefik/cf-token (Cloudflare token)            │    │
│  │                                                      │    │
│  │  All files are chmod 600 (owner read/write only)    │    │
│  └────────────────────────┬───────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌────────────────────────────────────────────────────┐    │
│  │         Docker Compose Services                     │    │
│  │                                                      │    │
│  │  Traefik  ──▶  Reads traefik/.env                   │    │
│  │                 Reads traefik/cf-token               │    │
│  │                                                      │    │
│  │  Pi-hole  ──▶  Uses $PIHOLE_PASSWORD from .env      │    │
│  │                                                      │    │
│  │  Others   ──▶  Use variables from .env              │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Detailed Flow

### 1. Developer Pushes Code

```bash
git add .
git commit -m "Update configuration"
git push origin main
```

### 2. GitHub Actions Triggered

The workflow:
1. Checks out code
2. Validates docker-compose files
3. Checks for hardcoded secrets (fails if found)
4. Sets up SSH connection to homelab
5. Exports GitHub Secrets as environment variables
6. SSHs to homelab and runs deployment script

### 3. Deployment Script Runs on Homelab

**deploy.sh** does:
1. Pulls latest code from git
2. Calls `setup-secrets.sh` to create .env files
3. Creates backups of current state
4. Deploys each service with `docker compose up -d`
5. Verifies deployment success

### 4. Secrets Setup Script

**setup-secrets.sh** does:
1. Reads environment variables (passed from GitHub)
2. Creates `.env` file in root directory
3. Creates `traefik/.env` with dashboard credentials
4. Creates `traefik/cf-token` with Cloudflare API token
5. Sets proper permissions (600) on all secret files
6. Verifies critical secrets are present

### 5. Docker Compose Services Start

Services read from `.env` files:
- Traefik uses credentials for dashboard auth
- Cloudflare token used for SSL certificate DNS challenge
- Pi-hole uses password for web interface
- Other services use their respective credentials

## Security Model

### At Rest (on Homelab)

```
.env files          ┐
traefik/.env        ├─▶  chmod 600 (owner read/write only)
traefik/cf-token    ┘

.gitignore          ──▶  Prevents committing to git

SSH keys            ──▶  Restricted to deployment script only
```

### In Transit (GitHub → Homelab)

```
GitHub Secrets      ──▶  Encrypted at rest in GitHub
                    ↓
GitHub Actions      ──▶  Masked in logs (shows ***)
                    ↓
SSH Connection      ──▶  Encrypted with SSH protocol
                    ↓
Homelab             ──▶  Environment variables (temporary)
                    ↓
.env files          ──▶  Written with 600 permissions
```

### Access Control

1. **GitHub Secrets**: Only repository admins can view/edit
2. **SSH Key**: Only deployment user can use
3. **`.env` files**: Only owner can read (chmod 600)
4. **Docker secrets**: Passed securely to containers

## Comparison: Manual vs Automated

### Manual Secret Management

```
Developer          Homelab Server
   ↓                     ↓
   └─▶ SSH manually      │
       └─▶ Edit .env files manually
           └─▶ git pull
               └─▶ docker compose up
```

**Pros:**
- Simple to understand
- Direct control
- Good for testing

**Cons:**
- Manual steps required
- Secrets must be set up on each server
- No central secret management
- Easy to forget to update secrets

### Automated Secret Management (Current)

```
Developer          GitHub              Homelab
   ↓                  ↓                    ↓
   └─▶ git push      │                    │
       └─▶ Actions runs                   │
           └─▶ SSH with secrets           │
               └─▶ setup-secrets.sh creates .env
                   └─▶ docker compose up
```

**Pros:**
- Fully automated
- Centralized secret management in GitHub
- Secrets automatically sync on deployment
- Consistent across multiple servers
- Audit trail in GitHub Actions logs

**Cons:**
- Slightly more complex setup
- Requires GitHub Secrets configuration

## Secrets Lifecycle

### 1. Initial Setup

```bash
# Admin creates secrets in GitHub
GitHub → Settings → Secrets → Actions
  Add: CLOUDFLARE_API_TOKEN
  Add: TRAEFIK_DASHBOARD_PASSWORD
  Add: ... (others)
```

### 2. Deployment

```bash
# Automatic on git push
GitHub Actions
  → Exports secrets as env vars
    → SSH to homelab
      → setup-secrets.sh creates .env files
        → Docker Compose uses .env
```

### 3. Updates

```bash
# Update secret in GitHub
GitHub → Settings → Secrets → Actions
  Edit: CLOUDFLARE_API_TOKEN (new value)

# Trigger redeployment
git push  # or manual workflow trigger

# Result: .env files updated automatically
```

### 4. Rotation (Every 90 days recommended)

```bash
# 1. Generate new values
# 2. Update in GitHub Secrets
# 3. Trigger deployment
# 4. Old secrets automatically replaced
```

## Troubleshooting Flow

### Secret Not Working?

```
Check GitHub Secrets exist
  ↓ YES
Check workflow logs (secrets shown as ***)
  ↓ OK
Check deployment logs on homelab
  ↓ OK
Check .env file exists and has correct values
  ↓ OK
Check .env file permissions (should be 600)
  ↓ OK
Check docker compose reads .env correctly
  ↓ OK
Service should work!
```

## File Permissions

All secret files should have restrictive permissions:

```bash
# Created by setup-secrets.sh
-rw------- 1 ubuntu ubuntu  .env
-rw------- 1 ubuntu ubuntu  traefik/.env
-rw------- 1 ubuntu ubuntu  traefik/cf-token
-rw------- 1 ubuntu ubuntu  .backups/

# SSH keys
-rw------- 1 ubuntu ubuntu  ~/.ssh/github_deploy
-rw------- 1 ubuntu ubuntu  ~/.ssh/authorized_keys
```

**Permission 600 means:**
- Owner: Read + Write
- Group: No access
- Others: No access

## Environment Variables Priority

Docker Compose reads variables in this order (highest priority first):

1. Environment variables set in shell
2. `.env` file in the same directory as docker-compose
3. `.env` file in parent directories
4. Default values in docker-compose.yml

Our setup uses #2 - `.env` files in service directories.

## Best Practices

1. ✅ **Never commit secrets to git** - Use `.gitignore`
2. ✅ **Use strong passwords** - 16+ characters, mixed case, numbers, symbols
3. ✅ **Rotate secrets regularly** - Every 90 days minimum
4. ✅ **Use dedicated API tokens** - Don't use global admin keys
5. ✅ **Restrict SSH keys** - Use command= restriction in authorized_keys
6. ✅ **Monitor logs** - Check for failed authentication attempts
7. ✅ **Use htpasswd hashing** - For passwords that support it (like Traefik)
8. ✅ **Limit token scope** - Give minimum required permissions

## References

- **Setup Guide**: [SETUP.md](SETUP.md)
- **GitHub Secrets**: [GITHUB-SECRETS.md](GITHUB-SECRETS.md)
- **Main README**: [../README.md](../README.md)

---

**Last Updated:** 2025-01-24
