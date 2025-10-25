# Docker Homelab Configuration

Automated Docker-based homelab infrastructure with CI/CD deployment pipeline.

## Overview

This repository manages containerized services for a home lab environment with automated deployment from GitHub to the homelab server. Changes pushed to the `main` branch are automatically validated and deployed.

## Services

| Service | Purpose | Domain | Status |
|---------|---------|--------|--------|
| **Traefik** | Reverse proxy & SSL termination | `traefik.plexlab.site` | Core |
| **Homepage** | Service dashboard | `list.plexlab.site` | Core |
| **Pi-hole v6** | DNS filtering & ad blocking | `piholev6.nexuswarrior.site` | Core |
| **RustDesk** | Remote desktop server | Host network | Core |
| **Code-Server** | Multi-user VS Code instances | `*.tinkeringturtle.site` | Optional |

## Quick Start

### For New Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/docker-configs.git
   cd docker-configs
   ```

2. **Configure environment**
   ```bash
   cp .env.example .env
   nano .env  # Fill in your values
   ```

3. **Set up Traefik (required first)**
   ```bash
   cd traefik
   cp .env.example .env
   cp cf-token.example cf-token
   nano .env       # Add dashboard credentials
   nano cf-token   # Add Cloudflare API token
   ```

4. **Create Docker network**
   ```bash
   docker network create proxy
   ```

5. **Deploy services**
   ```bash
   cd ..
   ./deploy/deploy.sh all
   ```

6. **Verify deployment**
   ```bash
   ./deploy/health-check.sh
   ```

### For Automated Deployment

See [deploy/SETUP.md](deploy/SETUP.md) for complete automated deployment setup.

**Quick setup:**
1. Configure GitHub Secrets (SSH key, host, user)
2. Push changes to `main` branch
3. GitHub Actions automatically deploys to homelab

## Repository Structure

```
docker-configs/
├── .github/
│   └── workflows/
│       └── deploy.yml              # CI/CD workflow
│
├── deploy/
│   ├── deploy.sh                   # Main deployment script
│   ├── health-check.sh             # Service health validation
│   ├── rollback.sh                 # Rollback to previous state
│   └── SETUP.md                    # Deployment setup guide
│
├── traefik/                        # Reverse proxy (REQUIRED)
│   ├── docker-compose.yaml
│   ├── .env.example
│   ├── cf-token.example
│   └── config/
│       ├── traefik.yml             # Static configuration
│       └── dynamic/                # Dynamic routing rules
│
├── homepage/                       # Service dashboard
│   └── docker-compose.yaml
│
├── Piholev6/                       # DNS & ad blocking
│   └── docker-compose.yaml
│
├── rustdesk/                       # Remote desktop
│   ├── docker-compose.yml
│   └── data/                       # Persistent data
│
├── scripts/
│   ├── script-code-server.sh       # Generate code-server instances
│   └── create-code-server-traefil-yml.sh
│
├── cloudflare-ddns-updater/        # Dynamic DNS updates
│   ├── cloudflare-ddns-updater.sh
│   └── README.md
│
├── .env.example                    # Environment template
└── README.md                       # This file
```

## Network Architecture

```
Internet
   │
   │ (Port 80/443)
   │
   ▼
Traefik (Reverse Proxy)
   │
   ├──▶ Homepage Dashboard
   ├──▶ Pi-hole Web UI
   ├──▶ Code-Server Instances (x10)
   └──▶ External Services (Portainer)

Pi-hole Internal Network (172.70.9.0/29)
   ├──▶ Cloudflared (DoH Proxy)
   └──▶ Pi-hole (DNS Server)

RustDesk (Host Network)
   ├──▶ hbbs (Signal Server)
   └──▶ hbbr (Relay Server)
```

## Deployment

### Automated Deployment (Recommended)

Push to `main` branch → GitHub Actions validates → Deploys to homelab

```bash
git add .
git commit -m "Update configuration"
git push origin main
# Deployment happens automatically
```

**Manual trigger:**
1. Go to GitHub Actions tab
2. Select "Homelab CI/CD" workflow
3. Click "Run workflow"

### Manual Deployment

```bash
# Deploy all services
./deploy/deploy.sh all

# Deploy specific service
./deploy/deploy.sh traefik

# Check service health
./deploy/health-check.sh

# Rollback if needed
./deploy/rollback.sh traefik
```

See [deploy/SETUP.md](deploy/SETUP.md) for detailed instructions.

## Service Details

### Traefik (Reverse Proxy)

**Features:**
- Automatic SSL/TLS with Let's Encrypt
- Cloudflare DNS challenge for wildcard certificates
- HTTP → HTTPS redirect
- Dashboard with authentication
- Docker integration for service discovery

**Ports:**
- 80 (HTTP)
- 443 (HTTPS)
- 8080 (Dashboard)

**Configuration:**
- Static: `traefik/config/traefik.yml`
- Dynamic routes: `traefik/config/dynamic/*.yml`

### Homepage (Dashboard)

**Features:**
- Web-based service dashboard
- Docker integration via secure socket proxy
- Centralized access to all services

**Domain:** `list.plexlab.site`

### Pi-hole v6 (DNS & Ad Blocking)

**Features:**
- Network-wide ad blocking
- DNS over HTTPS (DoH) via Cloudflared
- Custom DNS rules
- Web interface for management

**Components:**
- Pi-hole: Main DNS server (port 53)
- Cloudflared: Upstream DoH proxy (port 5053)

**Domain:** `piholev6.nexuswarrior.site`

### RustDesk (Remote Desktop)

**Features:**
- Self-hosted remote desktop solution
- Alternative to TeamViewer/AnyDesk
- Full control over your data

**Components:**
- hbbs: Signal/rendezvous server
- hbbr: Relay server

**Network:** Host mode (direct network access)

### Code-Server (Web-based VS Code)

**Features:**
- 10 isolated user instances
- VS Code in the browser
- Persistent workspaces
- Pre-configured extensions

**Users:** anand, alice, emma, anshi, abby, elly, meghana, nitya, paige, jessica

**Domains:** `{username}.tinkeringturtle.site`

**Ports:** 8444-8453

## Configuration Management

### Environment Variables

All sensitive data is stored in `.env` files (gitignored):

```bash
# Root level
cp .env.example .env

# Service specific
cp traefik/.env.example traefik/.env
cp traefik/cf-token.example traefik/cf-token
```

**Required secrets:**
- Cloudflare API token (DNS challenge)
- Traefik dashboard password
- Pi-hole admin password
- Code-server passwords

### Networks

**External network** (shared between services):
```bash
docker network create proxy
```

**Pi-hole internal** (isolated DNS network):
- Created automatically by docker-compose
- Subnet: 172.70.9.0/29

## Monitoring & Maintenance

### Health Checks

```bash
# Check all services
./deploy/health-check.sh

# Check specific service
./deploy/health-check.sh traefik
```

### Logs

```bash
# Deployment logs
tail -f deploy/deploy.log

# Service logs
cd traefik
docker compose logs -f

# All logs for a service
docker compose logs --tail=100
```

### Backups

Backups are created automatically before each deployment:

```bash
# List backups
ls -lt .backups/

# Rollback to latest backup
./deploy/rollback.sh traefik

# Rollback to specific backup
./deploy/rollback.sh traefik 20250124_143022
```

### Cleanup

```bash
# Remove unused containers, images, networks
docker system prune -a

# Remove unused volumes (CAREFUL!)
docker volume prune

# Remove old logs
find traefik/logs -type f -mtime +30 -delete
```

## TrueNAS Integration

For production deployments with TrueNAS storage:

1. **Create datasets** on TrueNAS for each service
2. **Configure NFS exports** with appropriate permissions
3. **Mount NFS shares** on homelab server
4. **Update volume paths** in docker-compose files

Example NFS mount:
```bash
sudo mount -t nfs -o vers=4,soft,timeo=600 \
  192.168.1.x:/mnt/pool/docker/traefik \
  /mnt/truenas/traefik
```

See [TrueNAS Integration Guide](#truenas-integration-guide-coming-soon) for detailed instructions.

## Security Considerations

### Implemented

- ✅ Reverse proxy with TLS termination
- ✅ Let's Encrypt automatic SSL certificates
- ✅ Docker socket access via read-only proxy
- ✅ Network segmentation (Pi-hole isolated)
- ✅ Secrets in gitignored files
- ✅ HTTP → HTTPS forced redirect
- ✅ Basic authentication on dashboards

### Recommended Improvements

- 🔄 Implement Authelia for SSO authentication
- 🔄 Add fail2ban for brute force protection
- 🔄 Enable audit logging
- 🔄 Implement secret rotation schedule
- 🔄 Add rate limiting on exposed services
- 🔄 Configure resource limits on containers

## Troubleshooting

### Common Issues

**Port already in use:**
```bash
sudo lsof -i :80
sudo lsof -i :443
```

**Docker permission denied:**
```bash
sudo usermod -aG docker $USER
# Log out and back in
```

**Network not found:**
```bash
docker network create proxy
```

**Service won't start:**
```bash
cd service_directory
docker compose logs
docker compose config  # Validate compose file
```

**GitHub Actions deployment fails:**
- Check GitHub Secrets are configured
- Verify SSH key has correct permissions
- Check server is reachable from GitHub
- Review Actions logs for specific errors

See [deploy/SETUP.md](deploy/SETUP.md) for more troubleshooting steps.

## Development Workflow

### Making Changes

1. Create feature branch
   ```bash
   git checkout -b feature/my-change
   ```

2. Make changes and test locally
   ```bash
   docker compose config  # Validate
   docker compose up -d   # Test
   ```

3. Commit and push
   ```bash
   git add .
   git commit -m "Description of changes"
   git push origin feature/my-change
   ```

4. Create Pull Request
   - GitHub Actions will validate
   - Review changes
   - Merge to `main`

5. Automatic deployment
   - Merge triggers deployment
   - Check GitHub Actions for status

### Adding New Services

1. Create service directory
   ```bash
   mkdir new-service
   cd new-service
   ```

2. Create docker-compose file
   ```bash
   nano docker-compose.yaml
   ```

3. Add to deployment script
   Edit `deploy/deploy.sh` and add to `SERVICES` array

4. Configure Traefik routing
   Create `traefik/config/dynamic/new-service.yml`

5. Test deployment
   ```bash
   ./deploy/deploy.sh new-service
   ```

## Performance Optimization

### Resource Limits

Add to docker-compose files:
```yaml
services:
  myservice:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          memory: 512M
```

### Logging

Configure log rotation:
```yaml
services:
  myservice:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

## Contributing

1. Fork the repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit pull request

## License

This configuration is for personal homelab use. Modify as needed for your environment.

## Support & Documentation

- **Deployment Setup:** [deploy/SETUP.md](deploy/SETUP.md)
- **Cloudflare DDNS:** [cloudflare-ddns-updater/README.md](cloudflare-ddns-updater/README.md)
- **GitHub Actions:** [.github/workflows/deploy.yml](.github/workflows/deploy.yml)

## Quick Reference Commands

```bash
# Deployment
./deploy/deploy.sh all              # Deploy all
./deploy/deploy.sh traefik          # Deploy one
./deploy/health-check.sh            # Check health
./deploy/rollback.sh traefik        # Rollback

# Docker
docker compose up -d                # Start services
docker compose down                 # Stop services
docker compose logs -f              # View logs
docker compose ps                   # List containers

# Maintenance
docker system prune -a              # Clean everything
docker network ls                   # List networks
docker volume ls                    # List volumes

# Git
git status                          # Check status
git pull                            # Update local
git log --oneline -10               # Recent commits
```

---

**Repository:** https://github.com/YOUR_USERNAME/docker-configs

**Last Updated:** 2025-01-24
