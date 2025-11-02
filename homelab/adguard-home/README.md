# AdGuard Home + Unbound DNS Filtering System

Comprehensive DNS-based content filtering with parental controls, ad blocking, malware protection, and privacy.

## Features

### Network-Wide Protection
- 🛡️ **Ad Blocking**: Block ads, trackers, and telemetry across all devices
- 🔒 **Malware Protection**: Block known malicious domains and phishing sites
- 👨‍👩‍👧‍👦 **Parental Controls**: Filter adult content, violence, gambling
- 🎓 **Homework Protection**: Block AI tools (ChatGPT, Claude, etc.)
- 📱 **Social Media Control**: Block social platforms for kids
- 🔐 **DNSSEC Validation**: Cryptographic DNS validation via Unbound
- 🕵️ **Privacy**: Recursive DNS (no external DNS providers)

### Client-Specific Rules
- Different filtering profiles for kids, adults, and work devices
- MAC/IP-based identification
- Custom schedules per device (coming soon)

### Infrastructure
- **AdGuard Home**: DNS filtering and web UI
- **Unbound**: Recursive DNS resolver with DNSSEC
- **TrueNAS**: Centralized log and config storage
- **pfSense**: Network-level DNS enforcement
- **Traefik**: HTTPS access to web UI

## Quick Start

### Prerequisites
- TrueNAS with NFS configured (192.168.10.15)
- Docker host (192.168.10.13)
- pfSense router with admin access

### 1. Setup TrueNAS NFS Mount

```bash
# On homelab server (192.168.10.13)
sudo mkdir -p /mnt/truenas/adguard
sudo mount -t nfs 192.168.10.15:/mnt/pool/docker/adguard /mnt/truenas/adguard
```

See [SETUP.md](./SETUP.md#phase-1-truenas-configuration) for details.

### 2. Download Unbound Root Hints

```bash
cd config/unbound
curl -o root.hints https://www.internic.net/domain/named.root
```

### 3. Deploy Containers

```bash
docker compose up -d
```

### 4. Initial Setup

Open browser: **http://192.168.10.13:3053**

Follow setup wizard:
- Set admin credentials
- Configure upstream DNS: `172.30.0.2:53` (Unbound)
- Complete setup

### 5. Configure Filtering

See [SETUP.md](./SETUP.md#phase-3-configure-adguard-home-filtering) for:
- Adding blocklists
- Enabling SafeSearch
- Client-specific rules

### 6. Configure pfSense

**Critical:** Force all DNS traffic through AdGuard Home

See [SETUP.md](./SETUP.md#phase-5-pfsense-configuration) for:
- DNS redirection rules
- Blocking DoH/DoT bypass attempts

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                        Internet                         │
└────────────────────────────┬────────────────────────────┘
                             │
                    ┌────────▼─────────┐
                    │  pfSense Router  │
                    │  192.168.10.1    │
                    │  (Force DNS)     │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │  AdGuard Home    │
                    │  192.168.10.13   │
                    │  Port 53         │
                    │                  │
                    │  ├─ Filtering    │
                    │  ├─ Logging      │
                    │  └─ Web UI       │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │     Unbound      │
                    │  172.30.0.2      │
                    │                  │
                    │  ├─ Recursive    │
                    │  ├─ DNSSEC       │
                    │  └─ Caching      │
                    └────────┬─────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
         Root DNS Servers            TrueNAS Storage
         (a-m.root-servers.net)      (Logs & Backups)
```

## Blocklists

### Built-in External Lists
- **Ads**: AdGuard DNS, OISD, 1Hosts
- **Adult Content**: OISD NSFW, Blocklist Project
- **Malware**: URLHaus, Blocklist Project
- **Tracking**: EasyPrivacy, Blocklist Project

### Custom Local Lists
- `ai-tools.txt`: ChatGPT, Claude, Gemini, etc. (95+ domains)
- `social-media.txt`: Facebook, Instagram, TikTok, etc. (100+ domains)

See [config/blocklists/](./config/blocklists/) for details.

## Client Profiles

### Kids Profile (Strict)
- ✅ Block ads & trackers
- ✅ Block adult content
- ✅ Block AI tools
- ✅ Block social media
- ✅ SafeSearch enforced
- ✅ Query logging enabled

### Adult Profile (Moderate)
- ✅ Block ads & malware
- ❌ No content filtering
- ❌ No social media blocking
- ❌ Minimal logging

### Work Profile (Minimal)
- ✅ Malware blocking only
- ❌ No ad blocking (if needed)
- ❌ No content filtering
- ❌ No logging

## Access

- **Web UI**: https://dns.plexlab.site (via Traefik)
- **Local UI**: http://192.168.10.13:3000
- **Initial Setup**: http://192.168.10.13:3053
- **DNS Server**: 192.168.10.13:53

## Monitoring

### Query Log
View real-time DNS queries in AdGuard web UI:
- **Dashboard**: Overview stats
- **Query Log**: Detailed query history
- **Statistics**: Top clients, top domains, blocked queries

### Container Health
```bash
docker compose ps
docker compose logs -f adguard
docker compose logs -f unbound
```

### TrueNAS Storage
```bash
# Check log storage
du -sh /mnt/truenas/adguard/work/

# View logs
tail -f /mnt/truenas/adguard/work/logs/querylog.json
```

## Maintenance

### Automatic
- ✅ Blocklists update daily
- ✅ Logs rotate automatically
- ✅ TrueNAS snapshots (configure)

### Monthly Tasks (~15 minutes)
- Update Unbound root hints
- Review top blocked domains
- Check for false positives
- Review TrueNAS storage usage

### Backups
All data stored on TrueNAS:
- Automatic via TrueNAS snapshots
- Manual: `docker compose exec adguard cat /opt/adguardhome/conf/AdGuardHome.yaml`

## Troubleshooting

### DNS Not Resolving
```bash
# Check containers
docker ps | grep -E "adguard|unbound"

# Test Unbound
docker exec unbound drill google.com @127.0.0.1

# Test AdGuard → Unbound
docker exec adguard nslookup google.com 172.30.0.2
```

### Clients Bypassing Filter
- Verify pfSense NAT redirect rule
- Check pfSense firewall logs
- Block DoH/DoT in pfSense

### False Positives
Add to Custom filtering rules:
```
@@||example.com^$important
```

See [SETUP.md](./SETUP.md#troubleshooting) for more details.

## Configuration Files

```
homelab/adguard-home/
├── docker-compose.yaml          # Container orchestration
├── config/
│   ├── unbound/
│   │   ├── unbound.conf         # Unbound configuration
│   │   └── root.hints           # DNS root servers
│   └── blocklists/
│       ├── ai-tools.txt         # AI chatbot blocking
│       ├── social-media.txt     # Social media blocking
│       └── README.md            # Blocklist documentation
├── SETUP.md                     # Detailed setup guide
└── README.md                    # This file
```

## Resources

- **Full Setup Guide**: [SETUP.md](./SETUP.md)
- **Blocklists Documentation**: [config/blocklists/README.md](./config/blocklists/README.md)
- **AdGuard Home**: https://github.com/AdguardTeam/AdGuardHome
- **Unbound**: https://nlnetlabs.nl/projects/unbound/
- **Blocklist Project**: https://blocklistproject.github.io/

## Security

- 🔒 Change default admin password
- 🔒 Restrict web UI access (firewall)
- 🔒 Force DNS redirection in pfSense
- 🔒 Block DoH/DoT bypass
- 🔒 Monitor query logs for anomalies
- 🔒 Regular TrueNAS backups

## Support

For issues or questions:
1. Check [SETUP.md](./SETUP.md) troubleshooting section
2. Review AdGuard Home logs: `docker compose logs adguard`
3. Check Unbound logs: `docker compose logs unbound`
4. Review pfSense firewall logs

## License

Configuration files and documentation: MIT License
AdGuard Home: GPL-3.0
Unbound: BSD License
