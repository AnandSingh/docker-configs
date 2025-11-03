# Teaching Lab Homepage

A customized homepage dashboard for the Teaching Lab server at `lab.nexuswarrior.site`.

## Features

- Quick access to all teaching infrastructure services
- Links to student code server instances
- Clean, dark-themed interface
- Search functionality
- Responsive design

## Services Displayed

### Teaching Infrastructure
- Traefik dashboard
- Portainer container management
- Coder workspace platform
- Proxmox hypervisor

### Student Code Servers
- Individual code-server instances for each student (Gautham, Nihita, Dhruv, Farish)

## Configuration

All configuration files are in the `config/` directory:
- `services.yaml` - Service links and descriptions
- `settings.yaml` - Theme and layout settings
- `widgets.yaml` - Top dashboard widgets
- `bookmarks.yaml` - Quick bookmark links
- `docker.yaml` - Docker integration settings

## Deployment

Deploy the homepage service:

```bash
cd teaching/homepage
docker compose up -d
```

The homepage will be accessible at:
- https://lab.nexuswarrior.site (production)
- http://192.168.10.29:3001 (direct access)

## Environment Variables

Required environment variables (set in `.env` file):
- `PUID` - User ID (default: 1000)
- `PGID` - Group ID (default: 1000)
- `HOMEPAGE_VAR_PROXMOX_USERNAME` - Proxmox username for widgets
- `HOMEPAGE_VAR_PROXMOX_PASSWORD` - Proxmox password for widgets
- `HOMEPAGE_VAR_PORTAINER_KEY` - Portainer API key for widgets

## Customization

To customize the homepage:

1. Edit `config/services.yaml` to add/remove/modify service links
2. Edit `config/settings.yaml` to change theme, layout, or behavior
3. Edit `config/widgets.yaml` to customize top widgets
4. Restart the container: `docker compose restart`

## Traefik Integration

The homepage is configured with Traefik labels for automatic routing:
- Listens on the root domain `lab.nexuswarrior.site`
- Automatic HTTPS redirect
- SSL termination via Traefik

## Troubleshooting

Check container logs:
```bash
docker logs homepage-teaching
```

Verify Traefik routing:
```bash
curl -I https://lab.nexuswarrior.site
```
