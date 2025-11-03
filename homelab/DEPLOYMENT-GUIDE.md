# Homelab Deployment Guide

Complete guide for deploying and configuring all homelab services with monitoring and automated stats.

## Quick Start

### 1. Deploy Monitoring Stack (New!)

```bash
cd homelab/monitoring
docker compose up -d
```

**Services deployed:**
- Uptime Kuma: https://uptime.plexlab.site (port 3002)
- Dozzle: https://logs.plexlab.site (port 8888)
- Glances: https://stats.plexlab.site (port 61208)

### 2. Configure Homepage with API Keys

```bash
cd homelab/homepage

# Copy and edit environment file
cp .env.example .env
nano .env  # Fill in your API keys
```

**Required API Keys to Configure:**

| Service | How to Get API Key | Where to Use |
|---------|-------------------|--------------|
| Jellyfin | Dashboard > API Keys > Create new | HOMEPAGE_VAR_JELLYFIN_KEY |
| Jellyseerr | Settings > General > API Key | HOMEPAGE_VAR_JELLYSEERR_KEY |
| Sonarr | Settings > General > API Key | HOMEPAGE_VAR_SONARR_KEY |
| Radarr | Settings > General > API Key | HOMEPAGE_VAR_RADARR_KEY |
| Lidarr | Settings > General > API Key | HOMEPAGE_VAR_LIDARR_KEY |
| Bazarr | Settings > General > API Key | HOMEPAGE_VAR_BAZARR_KEY |
| Portainer | User settings > Access tokens | HOMEPAGE_VAR_PORTAINER_KEY |
| TrueNAS | Top right menu > API Keys | HOMEPAGE_VAR_TRUENAS_KEY |
| AdGuard | Use your login credentials | HOMEPAGE_VAR_ADGUARD_USER/PASS |

### 3. Restart Homepage

```bash
cd homelab/homepage
docker compose restart
```

## What's New

### Automated Stats & Widgets

Your homepage now displays **real-time stats** automatically:

**Top Widgets (Automatic):**
- System Resources (CPU, RAM, Disk, Uptime)
- Glances Metrics (System info, CPU charts, Memory charts)
- Date/Time & Search

**Service Widgets (After API key configuration):**
- **AdGuard**: DNS queries, blocked ads count
- **Jellyfin**: Now playing, library stats
- **Jellyseerr**: Pending requests
- **Sonarr/Radarr/Lidarr/Bazarr**: Queue, calendar, missing items
- **Proxmox**: VM/CT status, resources
- **TrueNAS**: Storage pools, datasets
- **Portainer**: Container stats
- **Glances**: Detailed system metrics

### New Monitoring Services

**1. Uptime Kuma (uptime.plexlab.site)**
- Monitor uptime of all your services
- Get notifications when services go down
- Create status pages
- Track response times

**Setup after first access:**
1. Create admin account
2. Add monitors for each service:
   - Jellyfin: https://jellyfin.plexlab.site
   - AdGuard: https://dns.plexlab.site
   - Traefik: https://traefik.plexlab.site
   - All *arr services
   - Proxmox, TrueNAS, etc.
3. Configure notifications (Discord, Email, etc.)

**2. Dozzle (logs.plexlab.site)**
- View real-time Docker container logs
- Search and filter across all containers
- No configuration needed!

**3. Glances (stats.plexlab.site)**
- System monitoring dashboard
- CPU, Memory, Disk, Network stats
- Docker container monitoring
- REST API for homepage integration

## Service Overview

### All Services by Category

**Homelab Infrastructure:**
- Traefik (Reverse Proxy)
- AdGuard Home (DNS/Ad Blocking) - *With widget!*

**Monitoring & Logs:**
- Uptime Kuma (Uptime Monitoring) - *NEW!*
- Dozzle (Docker Logs) - *NEW!*
- Glances (System Stats) - *NEW!* - *With widget!*

**Homelab Media:**
- Jellyfin (Media Server) - *With widget!*
- Jellyseerr (Requests) - *With widget!*
- Jellystat (Statistics)

**Media Automation:**
- Sonarr (TV) - *With widget!*
- Radarr (Movies) - *With widget!*
- Lidarr (Music) - *With widget!*
- Bazarr (Subtitles) - *With widget!*

**Monitoring & Management:**
- Proxmox - *With widget!*
- TrueNAS - *With widget!*
- Portainer - *With widget!*

## Testing Your Setup

### 1. Test Homepage Access

```bash
# Local access
curl http://192.168.10.13:3000

# Public access
curl https://plexlab.site
```

### 2. Test Monitoring Services

```bash
# Uptime Kuma
curl https://uptime.plexlab.site

# Dozzle
curl https://logs.plexlab.site

# Glances
curl https://stats.plexlab.site
curl http://192.168.10.13:61208/api/3/system
```

### 3. Verify Docker Integration

Check homepage can access Docker:
```bash
docker logs homepage
# Should see: "Docker socket connected successfully"
```

### 4. Verify Widgets

After adding API keys, check homepage for:
- Service statistics showing up
- No "API Error" messages
- Real-time data updating

## Troubleshooting

### Homepage widgets showing "API Error"

1. Check API key is correct in `.env` file
2. Verify service is running: `docker ps`
3. Check homepage logs: `docker logs homepage`
4. Test API endpoint manually:
   ```bash
   # Example for Jellyfin
   curl -H "X-Emby-Token: YOUR_API_KEY" http://192.168.10.13:8096/System/Info
   ```

### Monitoring services not accessible

1. Check containers are running:
   ```bash
   cd homelab/monitoring
   docker compose ps
   ```

2. Check Traefik routing:
   ```bash
   docker logs traefik | grep uptime
   ```

3. Verify DNS resolution:
   ```bash
   nslookup uptime.plexlab.site
   ```

### System stats not showing

1. Verify Docker socket is mounted:
   ```bash
   docker inspect homepage | grep docker.sock
   ```

2. Check Glances is running:
   ```bash
   docker ps | grep glances
   curl http://192.168.10.13:61208/api/3/system
   ```

## Maintenance

### Backup Important Data

```bash
# Backup Uptime Kuma configuration
tar -czf uptime-kuma-backup-$(date +%Y%m%d).tar.gz homelab/monitoring/uptime-kuma/

# Backup Homepage configuration (already in git!)
git add homelab/homepage/config/
git commit -m "Backup homepage config"
```

### Update All Services

```bash
# Update monitoring stack
cd homelab/monitoring
docker compose pull
docker compose up -d

# Update homepage
cd homelab/homepage
docker compose pull
docker compose restart
```

### Check Service Health

```bash
# All containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Specific services
docker compose -f homelab/monitoring/docker-compose.yaml ps
docker compose -f homelab/homepage/docker-compose.yaml ps
```

## Advanced Configuration

### Add Uptime Kuma Widget to Homepage

After setting up monitors in Uptime Kuma, you can add a widget:

```yaml
# In services.yaml
- Uptime Kuma:
    icon: uptime-kuma.png
    href: https://uptime.plexlab.site
    description: Service Uptime Monitoring
    widget:
      type: uptimekuma
      url: https://uptime.plexlab.site
      slug: your-status-page-slug
```

### Enable Prometheus Metrics (Optional)

For advanced monitoring with Grafana:

1. Enable Prometheus exporters in your services
2. Add Prometheus + Grafana to monitoring stack
3. Configure scrapers and dashboards

### Customize Widget Metrics

Edit `homelab/homepage/config/widgets.yaml`:

```yaml
# Example: Add disk monitoring for specific mount
- glances:
    url: http://192.168.10.13:61208
    metric: disk:/media
    chart: true
```

## Next Steps

1. **Configure Uptime Kuma notifications** - Get alerted when services go down
2. **Add all services to Uptime Kuma** - Monitor everything!
3. **Generate API keys** - Enable all homepage widgets
4. **Create .env file** - Add your API keys to homepage
5. **Test everything** - Verify all widgets display correctly

## Quick Links

- **Homepage**: https://plexlab.site
- **Uptime Kuma**: https://uptime.plexlab.site
- **Dozzle (Logs)**: https://logs.plexlab.site
- **Glances (Stats)**: https://stats.plexlab.site
- **Traefik Dashboard**: https://traefik.plexlab.site

---

**Last Updated:** 2025-11-02
