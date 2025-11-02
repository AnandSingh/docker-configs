# AdGuard Home + Unbound Setup Guide

Comprehensive DNS filtering system with parental controls, ad blocking, and privacy protection.

## Architecture

```
Internet
    ↓
pfSense Router (192.168.10.1)
    ↓ (Force all DNS traffic)
AdGuard Home (192.168.10.13:53)
    ├─ Content Filtering
    ├─ Client-specific Rules
    ├─ Logs → TrueNAS (192.168.10.15)
    ↓
Unbound (172.30.0.2:53)
    ├─ Recursive DNS
    ├─ DNSSEC Validation
    ├─ Direct to Root Servers
    ↓
Root DNS Servers
```

## Prerequisites

- **TrueNAS** (192.168.10.15) with NFS exports configured
- **Homelab Server** (192.168.10.13) with Docker
- **pfSense Router** with admin access
- **UniFi Controller** (optional, for WiFi DNS settings)

---

## Phase 1: TrueNAS Configuration

### Step 1.1: Create TrueNAS Datasets

SSH into TrueNAS or use the web UI:

```bash
# Create datasets for AdGuard Home
zfs create pool/docker/adguard
zfs create pool/docker/adguard/work
zfs create pool/docker/adguard/conf

# Set permissions (uid:gid should match Docker host user)
chown -R 1000:1000 /mnt/pool/docker/adguard/
chmod -R 755 /mnt/pool/docker/adguard/
```

### Step 1.2: Configure NFS Export

In TrueNAS Web UI:

1. **Sharing → Unix Shares (NFS)**
2. **Add** new NFS share:
   - **Path**: `/mnt/pool/docker/adguard`
   - **Authorized Networks**: `192.168.10.0/24`
   - **Mapall User**: `root` (or your Docker user)
   - **Mapall Group**: `root` (or your Docker group)

3. Enable NFS service: **Services → NFS → Running**

### Step 1.3: Mount NFS on Homelab Server

SSH into homelab server (192.168.10.13):

```bash
# Create mount point
sudo mkdir -p /mnt/truenas/adguard

# Test mount
sudo mount -t nfs 192.168.10.15:/mnt/pool/docker/adguard /mnt/truenas/adguard

# Verify
ls -la /mnt/truenas/adguard

# Add to /etc/fstab for persistent mount
echo "192.168.10.15:/mnt/pool/docker/adguard /mnt/truenas/adguard nfs4 rw,hard,intr,rsize=131072,wsize=131072,timeo=600 0 0" | sudo tee -a /etc/fstab

# Mount all
sudo mount -a
```

### Step 1.4: Verify Permissions

```bash
# Create test file
sudo touch /mnt/truenas/adguard/test.txt

# Check ownership
ls -la /mnt/truenas/adguard/

# If permissions are wrong, fix on TrueNAS side
```

---

## Phase 2: Deploy AdGuard Home + Unbound

### Step 2.1: Download Root Hints for Unbound

```bash
cd /home/dev/docker/docker-configs/homelab/adguard-home/config/unbound
curl -o root.hints https://www.internic.net/domain/named.root
```

### Step 2.2: Deploy Containers

```bash
cd /home/dev/docker/docker-configs/homelab/adguard-home

# Create network
docker network create proxy 2>/dev/null || true

# Start services
docker compose up -d

# Check status
docker compose ps
docker compose logs -f
```

### Step 2.3: Initial AdGuard Home Setup

1. Open browser: **http://192.168.10.13:3053**
2. Follow setup wizard:
   - **Admin Web Interface**: Port `3000` (default)
   - **DNS Server**: Port `53` (default)
   - **Username**: `admin`
   - **Password**: Create strong password
3. Click **Next**
4. Configure upstream DNS:
   - **Upstream DNS servers**: `172.30.0.2:53`
   - This points to Unbound container
5. **Bootstrap DNS**: `1.1.1.1` (only used during startup)
6. Complete setup

---

## Phase 3: Configure AdGuard Home Filtering

### Step 3.1: Add External Blocklists

Go to **Filters → DNS blocklists → Add blocklist**

**Ads & Tracking:**
- AdGuard DNS filter (already included)
- OISD Big: `https://big.oisd.nl/`
- 1Hosts Pro: `https://o0.pages.dev/Pro/adblock.txt`

**Adult Content (for kids devices):**
- OISD NSFW: `https://nsfw.oisd.nl/`
- Blocklist Project - Adult: `https://blocklistproject.github.io/Lists/porn.txt`
- StevenBlack (porn+gambling): `https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts`

**Malware & Security:**
- Blocklist Project - Malware: `https://blocklistproject.github.io/Lists/malware.txt`
- Blocklist Project - Phishing: `https://blocklistproject.github.io/Lists/phishing.txt`
- URLHaus: `https://urlhaus.abuse.ch/downloads/hostfile/`

**Privacy & Tracking:**
- Blocklist Project - Tracking: `https://blocklistproject.github.io/Lists/tracking.txt`
- EasyPrivacy: `https://v.firebog.net/hosts/Easyprivacy.txt`

### Step 3.2: Add Custom Local Blocklists

**Filters → DNS blocklists → Add blocklist → Choose from file**

Add these custom blocklists:
- `/opt/adguardhome/blocklists/ai-tools.txt`
- `/opt/adguardhome/blocklists/social-media.txt`

Or use file:// URLs if web UI doesn't support file selection.

### Step 3.3: Enable SafeSearch (for kids)

**Settings → General settings → SafeSearch**

Enable for:
- ✅ Google
- ✅ Bing
- ✅ DuckDuckGo
- ✅ YouTube (safe mode)

### Step 3.4: Configure Query Logging

**Settings → Query log settings**

- **Enable query log**: ✅ Yes
- **Anonymize client IP**: ❌ No (needed for client-specific filtering)
- **Log retention**: 7-30 days
- **Ignored domains**: Add any domains you don't want logged

---

## Phase 4: Client-Specific Filtering

### Step 4.1: Identify Client Devices

**Query log → Filters** to see all devices making DNS requests.

Note down:
- Kids' devices (tablets, phones, laptops)
- Adult devices
- Work devices
- IoT devices

### Step 4.2: Configure Client Settings

**Settings → Client settings → Add client**

#### Kids Profile (Strict Filtering)

**Client identifier:**
- MAC address: `aa:bb:cc:dd:ee:ff`
- Or IP: `192.168.10.50` (assign static IP in DHCP)

**Settings:**
- ✅ Use global settings
- ✅ Use global blocked services
- ✅ Enable SafeSearch
- ✅ Block adult content

**Blocked Services:**
- ✅ TikTok
- ✅ Instagram
- ✅ Facebook
- ✅ Snapchat
- ✅ Discord
- ✅ Twitch
- ✅ Reddit
- ❌ YouTube (if needed for education, leave unchecked)

**Custom Rules:**
Add AI tools blocking (ChatGPT, Claude, etc.) in custom filtering rules.

#### Adult Profile (Moderate Filtering)

**Settings:**
- ✅ Use global settings
- ❌ Block adult content
- ❌ SafeSearch
- ✅ Block ads & malware

**Blocked Services:** None or minimal

#### Work Profile (Minimal Filtering)

**Settings:**
- ❌ Block adult content
- ❌ Block ads (if needed for work)
- ✅ Block malware only

---

## Phase 5: pfSense Configuration

### Step 5.1: Set DNS in pfSense

1. **System → General Setup**
2. **DNS Servers:**
   - Primary: `192.168.10.13` (AdGuard Home)
   - Secondary: `1.1.1.3` (Cloudflare Family - fallback)
3. **DNS Resolution Behavior:**
   - ✅ Do not use DNS Forwarder/Resolver as a DNS server for this system
4. **Save**

### Step 5.2: Configure DNS Resolver (Unbound)

**Option A: Disable pfSense Unbound (Recommended)**

We're using Unbound in Docker, so disable pfSense's built-in resolver:

1. **Services → DNS Resolver**
2. ❌ **Enable DNS resolver**
3. **Save**

**Option B: Forward to AdGuard**

If you want to use pfSense's Unbound:

1. **Services → DNS Resolver → General Settings**
2. ✅ **Enable Forwarding Mode**
3. **DNS Query Forwarding:**
   - Forward to: `192.168.10.13`
4. **Save**

### Step 5.3: Force DNS Redirection (Critical!)

This prevents bypassing DNS filtering by using hardcoded DNS (8.8.8.8, etc.)

**Firewall → NAT → Port Forward**

**Add rule:**
- **Interface**: LAN
- **Protocol**: TCP/UDP
- **Source**: LAN net
- **Destination**: `!192.168.10.13` (NOT AdGuard)
- **Destination Port**: `53` (DNS)
- **Redirect target IP**: `192.168.10.13`
- **Redirect target port**: `53`
- **Description**: Force all DNS to AdGuard Home
- **Filter rule association**: Create new associated filter rule

**Save** and **Apply Changes**

### Step 5.4: Block DNS-over-HTTPS/TLS (Optional)

Prevent browsers from bypassing DNS filtering:

**Firewall → Aliases → URLs**

Create alias:
- **Name**: `DoH_Servers`
- **Type**: Host(s)
- **Content**: Add known DoH/DoT providers:
  ```
  dns.google
  dns.cloudflare.com
  mozilla.cloudflare-dns.com
  dns.quad9.net
  ```

**Firewall → Rules → LAN**

Block DoH/DoT:
- **Action**: Block
- **Protocol**: TCP/UDP
- **Source**: LAN net
- **Destination**: `DoH_Servers` (alias)
- **Destination Port**: `443, 853`
- **Description**: Block DoH/DoT bypass

---

## Phase 6: UniFi WiFi Configuration (Optional)

If using UniFi:

1. **Settings → Networks → Edit LAN**
2. **DHCP**
3. **DHCP Name Server:**
   - Manual
   - DNS Server 1: `192.168.10.13`
   - DNS Server 2: `1.1.1.3` (Cloudflare Family fallback)
4. **Save**

---

## Phase 7: Testing & Verification

### Test 7.1: Verify DNS Resolution

From any device:

```bash
# Should resolve via AdGuard
nslookup google.com 192.168.10.13

# Test blocking
nslookup chatgpt.com 192.168.10.13
# Should return 0.0.0.0 or blocked response

nslookup instagram.com 192.168.10.13
# Should return 0.0.0.0 if social media blocking enabled
```

### Test 7.2: Verify DNSSEC

```bash
# Check DNSSEC validation
dig @192.168.10.13 cloudflare.com +dnssec
# Should have RRSIG records

# Test DNSSEC failure (should fail)
dig @192.168.10.13 dnssec-failed.org
# Should return SERVFAIL
```

### Test 7.3: Check AdGuard Logs

1. Open AdGuard Web UI: `https://dns.plexlab.site` (via Traefik)
2. Go to **Query log**
3. Verify queries are being logged
4. Check blocked queries count
5. Verify client identification

### Test 7.4: Verify TrueNAS Storage

```bash
# Check logs on TrueNAS
ssh truenas@192.168.10.15
ls -lh /mnt/pool/docker/adguard/work/
ls -lh /mnt/pool/docker/adguard/conf/

# Check log size
du -sh /mnt/pool/docker/adguard/work/
```

### Test 7.5: Test Bypass Prevention

From a client device:

```bash
# Try to use Google DNS directly
nslookup google.com 8.8.8.8
# Should still route through AdGuard (due to pfSense redirect)

# Verify redirection
traceroute -p 53 8.8.8.8
```

---

## Maintenance

### Daily (Automated)
- Blocklists auto-update every 24 hours
- Logs rotate automatically
- TrueNAS snapshots (configure on TrueNAS)

### Weekly
- Review top blocked domains
- Check for false positives
- Review query logs for bypass attempts

### Monthly
- Update Unbound root hints:
  ```bash
  cd /home/dev/docker/docker-configs/homelab/adguard-home/config/unbound
  curl -o root.hints https://www.internic.net/domain/named.root
  docker compose restart unbound
  ```
- Review TrueNAS log storage usage
- Backup AdGuard configuration (automatic via TrueNAS)

### Backups

**Automatic (TrueNAS Snapshots):**
Configure in TrueNAS:
1. **Storage → Snapshots → Add**
2. **Dataset**: `pool/docker/adguard`
3. **Schedule**: Daily at 2 AM
4. **Retention**: 7 daily, 4 weekly, 3 monthly

**Manual Backup:**
```bash
# Backup AdGuard config
cd /mnt/truenas/adguard/conf
tar -czf adguard-backup-$(date +%Y%m%d).tar.gz AdGuardHome.yaml

# Copy to safe location
scp adguard-backup-*.tar.gz user@backup-server:/backups/
```

---

## Troubleshooting

### Issue: DNS not resolving

**Check services:**
```bash
docker ps | grep -E "adguard|unbound"
docker logs adguard
docker logs unbound
```

**Check Unbound:**
```bash
docker exec unbound drill google.com @127.0.0.1
```

**Check AdGuard → Unbound:**
```bash
docker exec adguard nslookup google.com 172.30.0.2
```

### Issue: Clients can bypass filtering

**Verify pfSense NAT redirect:**
- Check **Firewall → NAT → Port Forward**
- Verify rule is enabled and applied
- Check firewall logs for blocked DNS

**Check client device:**
```bash
# On client
nslookup google.com
# Should show server: 192.168.10.13
```

### Issue: False positives

**Whitelist in AdGuard:**
1. **Filters → Custom filtering rules**
2. Add: `@@||example.com^$important`
3. Save

### Issue: High memory usage

**Check AdGuard:**
```bash
docker stats adguard
```

**Reduce log retention:**
- Settings → Query log settings → Reduce retention to 7 days

**Restart services:**
```bash
docker compose restart
```

### Issue: TrueNAS mount not working

**Check NFS:**
```bash
showmount -e 192.168.10.15
```

**Remount:**
```bash
sudo umount /mnt/truenas/adguard
sudo mount -a
```

---

## Next Steps

After successful deployment:

1. ✅ Test from multiple devices
2. ✅ Configure client-specific rules for kids
3. ✅ Enable TrueNAS snapshots
4. ✅ Set up monitoring (Uptime Kuma, etc.)
5. ✅ Document whitelisted domains for family
6. ✅ Train kids on appropriate internet use

---

## Support & Resources

- **AdGuard Home Docs**: https://github.com/AdguardTeam/AdGuardHome/wiki
- **Unbound Docs**: https://nlnetlabs.nl/documentation/unbound/
- **Blocklist Project**: https://blocklistproject.github.io/Lists/
- **OISD**: https://oisd.nl/

---

## Security Considerations

- 🔒 Change default AdGuard password
- 🔒 Use HTTPS for AdGuard web UI (via Traefik)
- 🔒 Restrict AdGuard web UI access (firewall rules)
- 🔒 Enable pfSense DNS redirect enforcement
- 🔒 Block DoH/DoT in pfSense
- 🔒 Monitor logs for bypass attempts
- 🔒 Regular backups to TrueNAS
