# Homepage Dashboard

A beautiful dashboard to manage and monitor all your Docker services across both homelab and teaching servers.

## Features

- Lists all services from both servers (plexlab.com and lab.nexuswarrior.site)
- Docker integration for auto-discovery and monitoring
- Widgets for Proxmox, TrueNAS, Portainer integration
- Beautiful dark theme with quick search
- Bookmarks for frequently used resources

## Access

- **URL**: https://homepage.plexlab.com
- **Local**: http://192.168.10.13:3000

## Configuration Files

All configuration is stored in `./config/` directory:

- **services.yaml** - Define your services and their links
- **widgets.yaml** - Configure top-level widgets (search, greeting, datetime)
- **settings.yaml** - General settings (theme, layout, etc.)
- **bookmarks.yaml** - Quick links to external resources
- **docker.yaml** - Docker integration settings

## Quick Start

1. Make sure your environment variables are set in `.env` file (see below)

2. Start the container:
   ```bash
   cd homelab/homepage
   docker compose up -d
   ```

3. Access the dashboard at https://homepage.plexlab.com

## Required Environment Variables

Make sure these are set in your root `.env` file:

```bash
# Homepage Configuration
PUID=1000
PGID=1000

# Optional: URLs for external services
HOMEPAGE_VAR_PROXMOX_URL=https://proxmox.example.com:8006
HOMEPAGE_VAR_PROXMOX_USERNAME=your-username@pam
HOMEPAGE_VAR_PROXMOX_PASSWORD=your-password

HOMEPAGE_VAR_TRUENAS_URL=https://truenas.example.com
HOMEPAGE_VAR_TRUENAS_KEY=your-api-key

HOMEPAGE_VAR_PORTAINER_URL=https://portainer.example.com
HOMEPAGE_VAR_PORTAINER_KEY=your-api-key
```

## Customization

### Adding a New Service

Edit `config/services.yaml`:

```yaml
- Category Name:
    - Service Name:
        icon: service-icon.png
        href: https://service.plexlab.com
        description: Service description
```

### Enabling Docker Auto-Discovery

The Docker socket is already mounted in read-only mode. To enable auto-discovery:

1. Edit `config/settings.yaml` and uncomment:
   ```yaml
   providers:
     docker:
       host: unix:///var/run/docker.sock
   ```

2. Restart the container:
   ```bash
   docker compose restart
   ```

### Adding Service Widgets

For services that support Homepage widgets, add a `widget` section:

```yaml
- Service Name:
    icon: service.png
    href: https://service.example.com
    widget:
      type: service-type
      url: https://service.example.com
      key: {{HOMEPAGE_VAR_SERVICE_KEY}}
```

Supported widgets include: proxmox, truenas, portainer, pihole, sonarr, radarr, jellyfin, and many more.

## Monitoring Remote Docker (Teaching Server)

To monitor Docker containers on your teaching server:

1. On the teaching server, expose Docker API securely (use SSH tunnel or Tailscale)

2. Edit `config/docker.yaml`:
   ```yaml
   teaching-server:
     host: tcp://teaching-server-ip:2375
   ```

**Security Note**: Never expose Docker API over TCP without proper security (TLS, firewall, VPN).

## Updating

```bash
cd homelab/homepage
docker compose pull
docker compose up -d
```

## Documentation

- Official Docs: https://gethomepage.dev
- Service Widgets: https://gethomepage.dev/widgets/
- Docker Integration: https://gethomepage.dev/configs/docker/

## Troubleshooting

**Issue**: Services not showing up
- Check that config files are properly formatted (YAML syntax)
- Check Docker logs: `docker logs homepage`

**Issue**: Can't access at homepage.plexlab.com
- Ensure DNS is configured in Cloudflare
- Check Traefik is running and properly configured
- Verify the domain in HOMEPAGE_ALLOWED_HOSTS

**Issue**: Widgets not working
- Ensure API keys are set in environment variables
- Check service URLs are accessible from the container
- Review logs for authentication errors
