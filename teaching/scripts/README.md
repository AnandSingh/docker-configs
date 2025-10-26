# Teaching VM Scripts

Utility scripts for managing and testing the Teaching VM (192.168.10.29) services.

## Available Scripts

### 1. `test-traefik.sh`

Comprehensive testing script for Traefik and all configured services.

**Usage:**
```bash
./test-traefik.sh
```

**What it tests:**
- Traefik container status
- Docker network configuration
- Port listeners (80, 443)
- HTTP to HTTPS redirects
- All service domains (HTTPS + SSL certificates)
- Backend container health (Coder, RustDesk)

**Services tested:**
- traefik.lab.nexuswarrior.site
- portainer.lab.nexuswarrior.site
- coder.lab.nexuswarrior.site
- gautham.lab.nexuswarrior.site
- nihita.lab.nexuswarrior.site
- dhruv.lab.nexuswarrior.site
- farish.lab.nexuswarrior.site
- proxmox.lab.nexuswarrior.site (proxy)

**Example output:**
```
========================================
  Traefik Testing Script - Teaching VM
  IP: 192.168.10.29
  Domain: *.lab.nexuswarrior.site
========================================

[1/6] Checking Traefik Container Status...
✓ PASS - Traefik container is running

[2/6] Checking Docker Network...
✓ PASS - Traefik 'proxy' network exists
...
```

### 2. `setup-traefik-secrets.sh`

Interactive script to set up Traefik secrets and configuration files.

**Usage:**
```bash
./setup-traefik-secrets.sh
```

**What it does:**
- Prompts for Cloudflare API token
- Prompts for Traefik dashboard credentials
- Creates `.env` file with all required secrets
- Sets up `acme.json` with correct permissions
- Ready for deployment

**When to use:**
- First-time setup
- After cloning the repository
- When secrets need to be updated
- When automated deployment fails

**Interactive prompts:**
1. Cloudflare email (default: anand.krs@gmail.com)
2. Cloudflare API token
3. Dashboard username (default: admin)
4. Dashboard password

## Common Workflows

### Initial Setup

```bash
# 1. Clone the repository
cd ~
git clone https://github.com/YOUR_USERNAME/docker-configs.git
cd docker-configs/teaching/scripts

# 2. Run setup script
./setup-traefik-secrets.sh

# 3. Deploy Traefik
cd ../traefik
docker network create proxy
docker compose up -d

# 4. Test deployment
cd ../scripts
./test-traefik.sh
```

### After Git Pull

```bash
# 1. Pull latest changes
cd ~/docker-configs
git pull origin main

# 2. Deploy updated services
cd teaching/traefik
docker compose up -d

# 3. Test
cd ../scripts
./test-traefik.sh
```

### Troubleshooting

```bash
# Check Traefik logs
docker logs traefik --tail=50 -f

# Check Traefik container status
docker ps | grep traefik

# Restart Traefik
cd ~/docker-configs/teaching/traefik
docker compose restart

# Full reset
docker compose down
docker compose up -d

# Run tests
cd ../scripts
./test-traefik.sh
```

## Prerequisites

All scripts require:
- Docker and Docker Compose installed
- Network connectivity
- Appropriate permissions (may need sudo for some Docker commands)

The test script also requires:
- `curl` command
- `openssl` command
- `grep`, `netstat` or `ss` commands

## Troubleshooting Script Issues

If the test script exits early or shows errors:

1. **Check Docker permissions:**
   ```bash
   # Add user to docker group
   sudo usermod -aG docker $USER
   # Log out and back in
   ```

2. **Check required commands:**
   ```bash
   which curl openssl docker
   ```

3. **Run with verbose output:**
   ```bash
   bash -x ./test-traefik.sh
   ```

4. **Check script permissions:**
   ```bash
   ls -la *.sh
   # Should show: -rwxr-xr-x

   # If not executable:
   chmod +x *.sh
   ```

## Related Documentation

- [Services and Domains](../../docs/SERVICES-AND-DOMAINS.md) - Complete service inventory
- [Deployment Troubleshooting](../../docs/DEPLOYMENT-TROUBLESHOOTING.md) - Fix common issues
- [Multi-Server Deployment](../../docs/MULTI-SERVER-DEPLOYMENT.md) - Architecture overview

## Support

For issues or questions:
1. Check the main documentation in `docs/`
2. Review GitHub Actions logs
3. Check Docker container logs
4. Run the test script for diagnostics

---

**Last Updated:** 2025-10-26
