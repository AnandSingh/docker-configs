# Homepage Dashboard - Deployment Guide

## What I've Set Up

I've configured **Homepage** - a modern, fully customizable dashboard for all your Docker services. It will display services from both:
- **Homelab Server** (plexlab.com)
- **Teaching Server** (lab.nexuswarrior.site)

## Changes Made

### 1. Created Configuration Files

Created complete Homepage configuration in `homelab/homepage/config/`:

- `services.yaml` - Lists all your services from both servers
- `settings.yaml` - Dark theme, layout, and general settings
- `widgets.yaml` - Top widgets (search, greeting, datetime)
- `bookmarks.yaml` - Quick links to docs and resources
- `docker.yaml` - Docker integration settings

### 2. Updated docker-compose.yaml

- ✅ Enabled Docker socket for auto-discovery
- ✅ Updated domain from `plexlab.site` to `homepage.plexlab.com`
- ✅ Added proper HOMEPAGE_ALLOWED_HOSTS

### 3. Updated .env File

- ✅ Set HOMEPAGE_DOMAIN to `homepage.plexlab.com`
- ✅ Added PUID and PGID
- ✅ Added placeholder environment variables for widgets (Proxmox, TrueNAS, Portainer, etc.)

## Deployment Steps

### Step 1: Configure DNS

Add DNS record in Cloudflare for `homepage.plexlab.com` pointing to your homelab server IP.

### Step 2: Update Service URLs (Optional)

Edit `config/services.yaml` to match your actual service URLs. I've set up common ones, but you may need to adjust:

```yaml
# Example: Update this
- Jellyfin:
    href: https://jellyfin.plexlab.com  # Change to your actual URL
```

### Step 3: Deploy

```bash
cd homelab/homepage
docker compose up -d
```

### Step 4: Verify

Check logs:
```bash
docker logs homepage
```

Access the dashboard:
- **Public**: https://homepage.plexlab.com
- **Local**: http://192.168.10.13:3000

## Next Steps (Optional)

### 1. Enable Service Widgets

To show live stats from your services, fill in these environment variables in `.env`:

```bash
# Proxmox
HOMEPAGE_VAR_PROXMOX_URL=https://your-proxmox:8006
HOMEPAGE_VAR_PROXMOX_USERNAME=your-username@pam
HOMEPAGE_VAR_PROXMOX_PASSWORD=your-password

# TrueNAS
HOMEPAGE_VAR_TRUENAS_URL=https://your-truenas
HOMEPAGE_VAR_TRUENAS_KEY=your-api-key

# Portainer
HOMEPAGE_VAR_PORTAINER_URL=https://your-portainer
HOMEPAGE_VAR_PORTAINER_KEY=your-api-key
```

### 2. Enable Docker Auto-Discovery

To automatically discover and monitor all Docker containers:

1. Edit `config/settings.yaml`
2. Uncomment the providers section:
   ```yaml
   providers:
     docker:
       host: unix:///var/run/docker.sock
   ```
3. Restart: `docker compose restart`

### 3. Monitor Teaching Server Containers

To monitor Docker on your teaching server:

**Option A: SSH Tunnel (Recommended)**
```bash
# On homelab server, create SSH tunnel to teaching server
ssh -L 2375:localhost:2375 user@teaching-server -N
```

**Option B: Tailscale/VPN**
Use your existing Twingate or VPN to securely access teaching server's Docker.

Then update `config/docker.yaml`:
```yaml
teaching-server:
  host: tcp://teaching-server-ip:2375
```

## Features

- 🎨 **Beautiful UI** - Dark theme with customizable colors
- 🔍 **Quick Search** - Search all your services instantly
- 📊 **Widgets** - Live stats from Proxmox, TrueNAS, Portainer, etc.
- 🐋 **Docker Integration** - Auto-discover containers with health status
- 📱 **Responsive** - Works great on mobile
- 🔗 **Bookmarks** - Quick access to frequently used links

## Troubleshooting

**Issue**: "Forbidden Host" error
```bash
# Add your access URL to HOMEPAGE_ALLOWED_HOSTS in .env
HOMEPAGE_ALLOWED_HOSTS: homepage.plexlab.com,plexlab.com,192.168.10.13:3000
```

**Issue**: Widgets not loading
- Ensure API credentials are correct in `.env`
- Check service URLs are accessible from the container
- Review logs: `docker logs homepage`

**Issue**: Services not showing
- Verify YAML syntax in `config/services.yaml`
- Check indentation (use spaces, not tabs)

## Alternative Solutions

If you want to explore other dashboard options:

1. **Dashy** - More customizable, heavier
2. **Heimdall** - Simpler, lightweight
3. **Homarr** - Modern, with integrated services
4. **Organizr** - Good for media servers

But **Homepage** is currently the best choice because:
- Active development
- Beautiful modern UI
- Excellent Docker integration
- Great widget support
- Lightweight and fast

## Documentation

- Homepage Docs: https://gethomepage.dev
- Widgets Guide: https://gethomepage.dev/widgets/
- Docker Integration: https://gethomepage.dev/configs/docker/
