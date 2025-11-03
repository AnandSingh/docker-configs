# Homelab Monitoring Stack

Comprehensive monitoring solution for your homelab infrastructure.

## Services

### 1. Uptime Kuma (uptime.plexlab.site)
**Uptime Monitoring & Status Pages**

- Monitor all your services (HTTP, TCP, Ping, Docker)
- Create beautiful status pages
- Notifications via Discord, Slack, Email, etc.
- Response time tracking
- SSL certificate expiry monitoring

**Setup:**
1. Access https://uptime.plexlab.site
2. Create admin account on first visit
3. Add monitors for all your services
4. Configure notification channels

**Recommended Monitors to Add:**
- Jellyfin (https://jellyfin.plexlab.site)
- AdGuard (https://dns.plexlab.site)
- Traefik (https://traefik.plexlab.site)
- All Servarr services
- Proxmox (https://proxmox.plexlab.site)
- TrueNAS (https://truenas.plexlab.site)

### 2. Dozzle (logs.plexlab.site)
**Real-time Docker Log Viewer**

- View logs from all Docker containers in real-time
- Search and filter logs
- Multi-container log streaming
- Dark mode UI
- Zero configuration required

**Usage:**
- Access https://logs.plexlab.site
- Select container from sidebar
- View live logs with search/filter

### 3. Glances (stats.plexlab.site)
**Real-time System Monitoring**

- CPU, Memory, Disk, Network usage
- Process monitoring
- Docker container stats
- Temperature sensors
- Disk I/O
- Network I/O

**Features:**
- REST API available at https://stats.plexlab.site/api/3
- WebSocket for real-time updates
- Can be integrated with Homepage widgets

## Deployment

```bash
cd homelab/monitoring
docker compose up -d
```

## Accessing Services

- **Uptime Kuma**: https://uptime.plexlab.site (or http://192.168.10.13:3002)
- **Dozzle**: https://logs.plexlab.site (or http://192.168.10.13:8888)
- **Glances**: https://stats.plexlab.site (or http://192.168.10.13:61208)

## Integration with Homepage

These services can be added to your homepage dashboard with widgets:

```yaml
- Monitoring:
    - Uptime Kuma:
        href: https://uptime.plexlab.site
        description: Service Uptime Monitoring
        widget:
          type: uptimekuma
          url: https://uptime.plexlab.site
          slug: status  # Your status page slug

    - Glances:
        href: https://stats.plexlab.site
        description: System Stats
        widget:
          type: glances
          url: http://192.168.10.13:61208
          metric: info  # or cpu, memory, disk, etc.
```

## Notifications Setup (Uptime Kuma)

Recommended notification channels:
1. **Discord** - Create webhook for server monitoring channel
2. **Email** - For critical alerts
3. **Telegram** - For mobile notifications

## Advanced: Prometheus + Grafana (Optional)

For advanced metrics and custom dashboards, you can add:
- Prometheus for metrics collection
- Grafana for visualization
- Node Exporter for host metrics
- cAdvisor for container metrics

## Maintenance

**Data Backup:**
```bash
# Backup Uptime Kuma data
tar -czf uptime-kuma-backup-$(date +%Y%m%d).tar.gz ./uptime-kuma/
```

**Update Containers:**
```bash
docker compose pull
docker compose up -d
```

## Troubleshooting

**Glances not showing Docker containers:**
- Ensure Docker socket is mounted correctly
- Check container has access to /var/run/docker.sock

**Uptime Kuma notifications not working:**
- Check notification service credentials
- Test notification from Uptime Kuma UI
- Check container logs: `docker logs uptime-kuma`

**Dozzle not showing containers:**
- Verify Docker socket mount
- Check container logs: `docker logs dozzle`
