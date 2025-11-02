# AdGuard Home Quick Setup & Testing Guide

Fast track setup using your existing TrueNAS NFS mount at `~/docker/appdata`

---

## Prerequisites Check

```bash
# Verify NFS mount is working
df -h | grep appdata
# Should show: 192.168.10.15:/mnt/... on /home/dev/docker/appdata

# Verify you're on homelab server
hostname
# Should be: homelab or 192.168.10.13
```

---

## Setup Steps

### Step 1: Create Directory Structure (2 minutes)

```bash
# Navigate to docker configs
cd ~/docker/docker-configs/homelab/adguard-home

# Create directories on TrueNAS mount
mkdir -p ~/docker/appdata/adguard/work
mkdir -p ~/docker/appdata/adguard/conf
mkdir -p ./config/unbound

# Set permissions
chmod -R 755 ~/docker/appdata/adguard/

# Verify
ls -la ~/docker/appdata/adguard/
```

### Step 2: Download Unbound Root Hints (1 minute)

```bash
# Download DNS root server list
curl -o ./config/unbound/root.hints https://www.internic.net/domain/named.root

# Verify download
ls -lh ./config/unbound/root.hints
# Should be ~3KB
```

### Step 3: Deploy Containers (2 minutes)

```bash
# Make sure proxy network exists
docker network create proxy 2>/dev/null || echo "Proxy network already exists"

# Start services
docker compose up -d

# Wait for containers to start
sleep 10

# Check status
docker compose ps
```

**Expected output:**
```
NAME       IMAGE                           STATUS
adguard    adguard/adguardhome:latest     Up (healthy)
unbound    mvance/unbound:latest          Up (healthy)
```

### Step 4: Verify Containers (2 minutes)

```bash
# Check AdGuard logs
docker compose logs adguard | tail -20

# Should see:
# "AdGuard Home is available at the following addresses:"
# "Go to http://127.0.0.1:3000"

# Check Unbound logs
docker compose logs unbound | tail -20

# Should see:
# "unbound: start of service"
# "info: server started"
```

### Step 5: Test Unbound DNS (1 minute)

```bash
# Test Unbound directly
docker exec unbound drill google.com @127.0.0.1

# Should see:
# ;; ANSWER SECTION:
# google.com.  <ttl>  IN  A  <IP address>
# ;; Query time: <time> msec

# Test DNSSEC validation
docker exec unbound drill cloudflare.com @127.0.0.1 +dnssec

# Should include RRSIG records (DNSSEC signatures)
```

### Step 6: Initial AdGuard Setup (5 minutes)

```bash
# Get your homelab server IP
ip addr show | grep "inet 192.168.10"
```

**Open browser:** http://192.168.10.13:3053

**Setup Wizard:**

1. **Welcome Screen** → Click "Get Started"

2. **Admin Web Interface:**
   - Listen interface: `All interfaces`
   - Port: `3000` (default)
   - Click "Next"

3. **DNS Server:**
   - Listen interface: `All interfaces`
   - Port: `53` (default)
   - Click "Next"

4. **Authentication:**
   - Username: `admin`
   - Password: `<create strong password>`
   - Click "Next"

5. **Configure Devices:**
   - Skip for now (we'll configure pfSense later)
   - Click "Next"

6. **Finish:**
   - Click "Open Dashboard"

### Step 7: Configure Upstream DNS (3 minutes)

**In AdGuard Web UI:**

1. **Settings → DNS settings**

2. **Upstream DNS servers:**
   ```
   172.30.0.2:53
   ```
   (This is the Unbound container)

3. **Bootstrap DNS servers:**
   ```
   1.1.1.1
   1.0.0.1
   ```
   (Only used during startup, not for actual queries)

4. Scroll down → **Test upstream DNS**
   - Should show all green checkmarks

5. **Save**

### Step 8: Add Blocklists (5 minutes)

**Filters → DNS blocklists → Add blocklist**

**Add these URLs one by one:**

**Ads & Tracking:**
```
https://big.oisd.nl/
```
Name: OISD Big List

```
https://o0.pages.dev/Pro/adblock.txt
```
Name: 1Hosts Pro

**Adult Content:**
```
https://nsfw.oisd.nl/
```
Name: OISD NSFW

```
https://blocklistproject.github.io/Lists/porn.txt
```
Name: Adult Content

**Malware & Security:**
```
https://blocklistproject.github.io/Lists/malware.txt
```
Name: Malware

```
https://blocklistproject.github.io/Lists/phishing.txt
```
Name: Phishing

**Privacy:**
```
https://blocklistproject.github.io/Lists/tracking.txt
```
Name: Tracking

### Step 9: Add Custom Local Blocklists (2 minutes)

**Filters → DNS blocklists → Add blocklist → Add a custom list**

**AI Tools Blocklist:**
- Name: `AI Tools (ChatGPT, Claude, etc.)`
- URL: `file:///opt/adguardhome/blocklists/ai-tools.txt`
- Click "Save"

**Social Media Blocklist:**
- Name: `Social Media (Kids)`
- URL: `file:///opt/adguardhome/blocklists/social-media.txt`
- Click "Save"

### Step 10: Enable SafeSearch (1 minute)

**Settings → General settings → SafeSearch**

Enable:
- ✅ Google
- ✅ Bing
- ✅ DuckDuckGo
- ✅ YouTube

**Save**

---

## Testing (10 minutes)

### Test 1: Basic DNS Resolution

```bash
# From homelab server, test AdGuard DNS
nslookup google.com 192.168.10.13

# Expected output:
# Server:    192.168.10.13
# Address:   192.168.10.13#53
#
# Non-authoritative answer:
# Name:   google.com
# Address: <IP>
```

### Test 2: Ad Blocking

```bash
# Test known ad domain
nslookup ads.google.com 192.168.10.13

# Expected output:
# Server:    192.168.10.13
# Address:   192.168.10.13#53
#
# Name:   ads.google.com
# Address: 0.0.0.0
```

### Test 3: AI Tools Blocking

```bash
# Test ChatGPT blocking
nslookup chatgpt.com 192.168.10.13

# Expected output:
# Server:    192.168.10.13
# Address:   192.168.10.13#53
#
# Name:   chatgpt.com
# Address: 0.0.0.0

# Test Claude blocking
nslookup claude.ai 192.168.10.13

# Expected: 0.0.0.0
```

### Test 4: Social Media Blocking

```bash
# Test Instagram
nslookup instagram.com 192.168.10.13

# Expected: 0.0.0.0

# Test TikTok
nslookup tiktok.com 192.168.10.13

# Expected: 0.0.0.0

# Test Facebook
nslookup facebook.com 192.168.10.13

# Expected: 0.0.0.0
```

### Test 5: Adult Content Blocking

```bash
# Test adult site (generic example)
nslookup pornhub.com 192.168.10.13

# Expected: 0.0.0.0
```

### Test 6: DNSSEC Validation

```bash
# Test valid DNSSEC domain
dig @192.168.10.13 cloudflare.com +dnssec

# Should include RRSIG records

# Test DNSSEC failure (intentionally broken)
dig @192.168.10.13 dnssec-failed.org

# Should return SERVFAIL
```

### Test 7: Check AdGuard Statistics

**In Web UI:**

1. Go to **Dashboard**
2. You should see:
   - DNS queries processed
   - Blocked by filters (should be >0 from your tests)
   - Average processing time (<10ms)

3. Go to **Query Log**
   - Should see all your test queries
   - Blocked queries should be marked in red

### Test 8: Performance Test

```bash
# Measure query time
time nslookup google.com 192.168.10.13

# Should be very fast (< 0.1 seconds)

# Test caching (second query should be instant)
time nslookup google.com 192.168.10.13
time nslookup google.com 192.168.10.13
```

### Test 9: Verify TrueNAS Storage

```bash
# Check files are being written to NFS mount
ls -lh ~/docker/appdata/adguard/work/
ls -lh ~/docker/appdata/adguard/conf/

# Should see:
# - data/ directory
# - querylog.json or similar
# - AdGuardHome.yaml (config file)

# Check disk usage
du -sh ~/docker/appdata/adguard/
```

### Test 10: Container Health

```bash
# Check container health
docker ps | grep -E "adguard|unbound"

# Both should show "Up" status

# Check resource usage
docker stats --no-stream adguard unbound

# Should show reasonable CPU/Memory usage
```

---

## Configure Client Device (Optional Testing)

To test from another device on your network:

### On Your Laptop/Phone (Temporary Test):

**Windows:**
1. Settings → Network & Internet → Change adapter options
2. Right-click your network → Properties
3. IPv4 → Properties
4. Use DNS: `192.168.10.13`
5. Save

**macOS:**
1. System Settings → Network
2. Select your connection → Details
3. DNS → Add: `192.168.10.13`
4. Save

**iPhone/Android:**
1. WiFi Settings → Select your network
2. Configure DNS → Manual
3. Add DNS: `192.168.10.13`
4. Save

**Test from device:**
- Try opening chatgpt.com → Should be blocked
- Try opening instagram.com → Should be blocked
- Try opening google.com → Should work
- Check AdGuard query log to see device requests

---

## Verification Checklist

- [ ] Containers running (adguard + unbound)
- [ ] Unbound can resolve DNS
- [ ] AdGuard web UI accessible
- [ ] Upstream DNS configured (172.30.0.2)
- [ ] Blocklists loaded (7+ external + 2 custom)
- [ ] SafeSearch enabled
- [ ] DNS resolution works (google.com)
- [ ] Ad blocking works (ads.google.com → 0.0.0.0)
- [ ] AI blocking works (chatgpt.com → 0.0.0.0)
- [ ] Social media blocking works (instagram.com → 0.0.0.0)
- [ ] DNSSEC validation works
- [ ] Query logs visible in UI
- [ ] Data stored in ~/docker/appdata/adguard/

---

## Next Steps After Testing

Once everything is working:

### 1. Configure pfSense DNS (CRITICAL)

See [SETUP.md Phase 5](./SETUP.md#phase-5-pfsense-configuration) for:
- Setting AdGuard as primary DNS
- Forcing all DNS traffic (preventing bypass)
- Blocking DoH/DoT

### 2. Set Up Client-Specific Rules

See [SETUP.md Phase 4](./SETUP.md#phase-4-client-specific-filtering) for:
- Identifying kids' devices
- Creating client profiles
- Applying different blocklists per device

### 3. Configure TrueNAS Backups

Set up automatic snapshots:
1. TrueNAS → Storage → Snapshots
2. Add snapshot task for `pool/docker/appdata/adguard`
3. Schedule: Daily at 2 AM
4. Retention: 7 daily, 4 weekly

### 4. Access via HTTPS

After Traefik is configured:
- https://dns.plexlab.site (secure web UI)

---

## Troubleshooting

### Containers won't start

```bash
# Check logs
docker compose logs adguard
docker compose logs unbound

# Common issue: Port 53 already in use
sudo lsof -i :53
# Kill conflicting service or stop Pi-hole if running
```

### DNS not resolving

```bash
# Test Unbound directly
docker exec unbound drill google.com @127.0.0.1

# Test AdGuard → Unbound connection
docker exec adguard nslookup google.com 172.30.0.2

# Check network
docker network inspect dns_internal
```

### Blocklists not loading

```bash
# Check AdGuard logs
docker compose logs adguard | grep -i block

# Manually update blocklists
# In Web UI: Filters → Check for updates
```

### Can't access Web UI

```bash
# Check port is listening
sudo netstat -tlnp | grep 3000

# Check from server
curl http://localhost:3000

# Check firewall
sudo ufw status
```

### Files not persisting

```bash
# Verify NFS mount
df -h | grep appdata

# Check permissions
ls -la ~/docker/appdata/adguard/

# Remount if needed
sudo mount -a
```

---

## Performance Benchmarks

Expected performance on homelab server:

- **Query Resolution**: <10ms (first query), <1ms (cached)
- **Memory Usage**: ~300MB (AdGuard) + ~100MB (Unbound)
- **CPU Usage**: <5% average
- **Disk I/O**: Minimal (~1-5 MB/day for logs)

---

## Support

- **Full Setup Guide**: [SETUP.md](./SETUP.md)
- **Blocklists**: [config/blocklists/README.md](./config/blocklists/README.md)
- **AdGuard Docs**: https://github.com/AdguardTeam/AdGuardHome/wiki

---

**Total Setup Time: ~25 minutes**
**Total Testing Time: ~10 minutes**
