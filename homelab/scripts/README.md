# Homelab Scripts

Utility scripts for managing and maintaining your homelab infrastructure.

## Available Scripts

### `docker-host-setup.sh`
**Purpose:** Initial Docker host configuration and setup

Sets up the Docker host with necessary dependencies, configurations, and security settings.

```bash
bash docker-host-setup.sh
```

### `setup-traefik-secrets.sh`
**Purpose:** Generate and configure Traefik secrets

Creates necessary secrets for Traefik including:
- Dashboard credentials
- Cloudflare API tokens
- SSL certificates

```bash
bash setup-traefik-secrets.sh
```

### `test-traefik.sh`
**Purpose:** Test Traefik configuration and connectivity

Validates:
- Traefik service is running
- SSL certificates are valid
- Routing rules are working
- DNS resolution

```bash
bash test-traefik.sh
```

## Usage

All scripts are designed to be run from the homelab/scripts directory:

```bash
cd /path/to/docker-configs/homelab/scripts
chmod +x *.sh
bash <script-name>.sh
```

## Prerequisites

- Docker and Docker Compose installed
- Proper network configuration
- Access to Cloudflare account (for Traefik)
- Sudo access for system-level changes

## Deployment Scripts

For automated deployment to your homelab server, see the main deployment scripts in the `deploy/` directory at the repository root.

## Notes

- Always review scripts before running them
- Make sure to backup configurations before running setup scripts
- Check logs if any script fails
- Scripts create backups automatically when modifying existing configurations

## Troubleshooting

**Script fails with permission errors:**
```bash
chmod +x *.sh
# or run with sudo if needed
sudo bash <script-name>.sh
```

**Docker not found:**
```bash
# Install Docker first
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

## Related Documentation

- Main deployment guide: `/deploy/README.md`
- Teaching scripts: `/teaching/scripts/README.md`
- Manual deployment: `/MANUAL-DEPLOYMENT-GUIDE.md`
