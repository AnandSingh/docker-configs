# Homepage Deployment Notes

## Deployment Without .env File

The homepage service is designed to deploy successfully **without** a `.env` file. This allows for:
- Initial deployment via CI/CD
- Homepage to function without API keys
- Widgets to be enabled later by adding API keys

### What Works Without .env

✅ **Working:**
- Homepage displays and is accessible
- Service links work
- Basic widgets (search, greeting, datetime)
- System resource widgets (CPU, RAM, Disk)
- Layout and theme

❌ **Not Working (until API keys added):**
- Service-specific widgets (Jellyfin, Servarr, etc.)
- External service stats (Proxmox, TrueNAS, Portainer)
- AdGuard statistics

### Default Values

When no `.env` file exists, these defaults are used:

```bash
PUID=1000
PGID=1000
LOG_LEVEL=info
# All API keys default to empty strings
```

### Deployment Behavior

**Automatic Deploy Script (`deploy-homelab.sh`):**
1. Checks for `.env` file
2. If missing but `.env.example` exists:
   - For homepage: Creates `.env` from `.env.example` with defaults
   - For other services: Fails with warning to add secrets
3. Continues deployment with default values

**Manual Deployment:**
```bash
cd homelab/homepage
docker compose up -d
# Works without .env file!
```

### Adding API Keys Later

To enable widgets after deployment:

1. **Create .env file:**
   ```bash
   cd homelab/homepage
   cp .env.example .env
   nano .env  # Add your API keys
   ```

2. **Restart homepage:**
   ```bash
   docker compose restart
   ```

3. **Verify widgets:**
   - Access https://plexlab.site
   - Check that service widgets show data
   - Look for "API Error" messages (indicates wrong/missing keys)

### Getting API Keys

See the main [DEPLOYMENT-GUIDE.md](../DEPLOYMENT-GUIDE.md) for detailed instructions on obtaining API keys from each service.

### CI/CD Deployment

For GitHub Actions or automated deployment:

**Option 1: Use Secrets Manager (Recommended)**
- Store API keys in GitHub Secrets
- Have deployment script create .env from secrets
- Keep secrets out of repository

**Option 2: Deploy Without Keys**
- Let homepage deploy with defaults
- Manually add .env file on server later
- Simple but requires manual step

**Current Implementation: Option 2**
- Homepage deploys automatically without keys
- Widgets can be enabled later by adding .env

### Troubleshooting

**Homepage not starting:**
```bash
# Check logs
docker logs homepage

# Common issues:
# - Port 3000 already in use
# - Docker socket not accessible
# - Traefik network not created
```

**Widgets showing "API Error":**
```bash
# Check environment variables are set
docker exec homepage env | grep HOMEPAGE_VAR

# Test API endpoint manually
curl -H "X-Api-Key: YOUR_KEY" http://192.168.10.13:8989/api/v3/system/status
```

**Docker socket permission denied:**
```bash
# Ensure Docker socket has correct permissions
ls -la /var/run/docker.sock

# Add user to docker group if needed
sudo usermod -aG docker $USER
```

### Security Notes

- `.env` files are gitignored and never committed
- API keys should be managed via secrets manager in production
- Homepage container runs as non-root (PUID/PGID)
- Docker socket is mounted read-only (`:ro`)

### Migration Path

**Current State:**
- Homepage deploys without .env
- Basic functionality works
- Widgets disabled

**Future Enhancement:**
- Integrate with secrets management
- Auto-populate .env from GitHub Secrets
- Encrypted secrets at rest

---

Last Updated: 2025-11-02
