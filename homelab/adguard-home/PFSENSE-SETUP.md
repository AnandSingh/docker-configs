# pfSense Configuration for AdGuard Home

Configure pfSense to route all DNS traffic through AdGuard Home with forced redirection.

---

## Overview

We'll configure pfSense to:
1. ✅ Use AdGuard as primary DNS server
2. ✅ Force ALL DNS queries to AdGuard (prevent bypass)
3. ✅ Block DNS-over-HTTPS/TLS bypass attempts
4. ✅ Distribute AdGuard DNS to all DHCP clients

---

## Phase 1: Configure pfSense System DNS (5 minutes)

### Step 1.1: Set DNS Servers

1. **Login to pfSense**: http://192.168.10.1 (or your pfSense IP)

2. **System → General Setup**

3. **DNS Server Settings:**
   - **DNS Server 1:**
     - IP: `192.168.10.13`
     - Gateway: `None`
     - Description: `AdGuard Home Primary`

   - **DNS Server 2:**
     - IP: `1.1.1.3`
     - Gateway: `None`
     - Description: `Cloudflare Family (Backup)`

   - **DNS Server 3:**
     - IP: `1.0.0.3`
     - Gateway: `None`
     - Description: `Cloudflare Family (Backup 2)`

4. **DNS Server Override:**
   - ✅ **Allow DNS server list to be overridden by DHCP/PPP on WAN**
   - (Leave checked if you want WAN DHCP to override, or uncheck to force AdGuard)

5. **DNS Resolution Behavior:**
   - ✅ **Do not use the DNS Forwarder/Resolver as a DNS server for the firewall**
   - (This makes pfSense use AdGuard directly)

6. **Scroll down and click Save**

---

## Phase 2: Configure DNS Resolver (Disable or Forward) (3 minutes)

### Option A: Disable DNS Resolver (Recommended)

Since we're using AdGuard + Unbound in Docker, we don't need pfSense's built-in Unbound.

1. **Services → DNS Resolver**

2. **General Settings:**
   - ❌ **Enable DNS Resolver** (UNCHECK this box)

3. **Save**

4. **Apply Changes**

### Option B: Forward to AdGuard (Alternative)

If you prefer to keep pfSense's DNS Resolver:

1. **Services → DNS Resolver**

2. **General Settings:**
   - ✅ **Enable DNS Resolver**
   - ✅ **Enable Forwarding Mode**

3. **DNS Query Forwarding:**
   - This will forward to the DNS servers configured in System → General Setup (AdGuard)

4. **Save** and **Apply Changes**

**Note:** I recommend Option A (disable) to avoid unnecessary double-processing.

---

## Phase 3: Configure DHCP to Distribute AdGuard DNS (3 minutes)

This tells all DHCP clients to use AdGuard for DNS.

### Step 3.1: LAN DHCP Settings

1. **Services → DHCP Server**

2. **Select LAN interface tab**

3. **Servers:**
   - **DNS Server 1:** `192.168.10.13` (AdGuard Home)
   - **DNS Server 2:** `1.1.1.3` (Cloudflare Family - backup)
   - **DNS Server 3:** Leave empty (optional)

4. **Scroll down and click Save**

### Step 3.2: Repeat for Other Networks (If Applicable)

If you have multiple VLANs (Guest WiFi, IoT, etc.):

1. **Services → DHCP Server → [Interface Name]**
2. Set the same DNS servers
3. Save each one

---

## Phase 4: Force DNS Redirection (CRITICAL - Prevent Bypass) (10 minutes)

This is **the most important step**. It prevents devices from bypassing AdGuard by using hardcoded DNS (like 8.8.8.8).

### Step 4.1: Create NAT Port Forward Rule

1. **Firewall → NAT → Port Forward**

2. **Add** (↑ button at the top)

3. **Edit Redirect Entry:**

   **Interface:** `LAN`

   **Address Family:** `IPv4`

   **Protocol:** `TCP/UDP`

   **Source:**
   - Type: `LAN net`

   **Destination:**
   - Type: `Invert match` ☑️ (CHECK THIS BOX!)
   - Address: `Single host or alias` → `192.168.10.13`
   - Port range: `DNS (53)` to `DNS (53)`

   **Redirect target IP:** `192.168.10.13`

   **Redirect target port:** `DNS (53)`

   **Description:** `Force all DNS to AdGuard Home`

   **Filter rule association:** `Add associated filter rule`

4. **Save**

5. **Apply Changes**

**What this does:**
- Any DNS query (port 53) to ANY server EXCEPT AdGuard (192.168.10.13)
- Gets redirected to AdGuard (192.168.10.13)
- Prevents devices from using Google DNS (8.8.8.8), Cloudflare (1.1.1.1), etc.

### Step 4.2: Verify the Filter Rule Was Created

1. **Firewall → Rules → LAN**

2. You should see a new rule at the top:
   - **NAT Force all DNS to AdGuard Home**
   - Protocol: TCP/UDP
   - Source: LAN net
   - Destination: !192.168.10.13:53

3. Make sure it's **enabled** (checkbox on the left)

---

## Phase 5: Block DNS-over-HTTPS/DoT (Optional but Recommended) (10 minutes)

Modern browsers (Firefox, Chrome) try to bypass DNS filtering using encrypted DNS. Let's block that.

### Step 5.1: Create Alias for DoH/DoT Servers

1. **Firewall → Aliases → URLs**

2. **Add** (↑ button)

3. **Properties:**
   - **Name:** `DoH_DoT_Servers`
   - **Description:** `DNS-over-HTTPS and DNS-over-TLS servers`
   - **Type:** `URL (IPs)`
   - **URL:**
     ```
     https://raw.githubusercontent.com/dibdot/DoH-IP-blocklists/master/doh-ipv4.txt
     ```
   - **Frequency:** `1 Days`
   - **Description:** `Blocklist of known DoH/DoT servers`

4. **Save**

5. **Apply Changes**

### Step 5.2: Create Firewall Rule to Block DoH/DoT

1. **Firewall → Rules → LAN**

2. **Add** (↑ button at the top)

3. **Edit Firewall Rule:**

   **Action:** `Block`

   **Disabled:** ❌ (Leave unchecked - rule is enabled)

   **Interface:** `LAN`

   **Address Family:** `IPv4`

   **Protocol:** `TCP/UDP`

   **Source:**
   - Type: `LAN net`

   **Destination:**
   - Type: `Single host or alias` → Select `DoH_DoT_Servers` (the alias we created)

   **Destination Port Range:**
   - From: `HTTPS (443)` To: `HTTPS (443)`

   **Description:** `Block DNS-over-HTTPS/TLS bypass attempts`

   **Log:** ☑️ **Log packets that are handled by this rule**

4. **Save**

5. **Drag this rule to the TOP** of the LAN rules (above the Allow rule)

6. **Apply Changes**

### Step 5.3: Also Block DoT on Port 853

1. **Firewall → Rules → LAN**

2. **Add** another rule (same as above but):
   - **Destination Port Range:** `853 to 853` (DNS-over-TLS port)
   - **Description:** `Block DNS-over-TLS (port 853)`

3. **Save** and **Apply Changes**

---

## Phase 6: Verification & Testing (5 minutes)

### Test 6.1: Check pfSense DNS

From pfSense itself:

1. **Diagnostics → DNS Lookup**

2. **Hostname:** `google.com`

3. **DNS Server:** (leave default)

4. Click **Lookup**

5. Should resolve successfully using AdGuard

### Test 6.2: Test from a Client Device

**From your laptop/phone (connected to the network):**

**Windows CMD / Mac Terminal / Linux:**

```bash
# Check what DNS server you're using
nslookup google.com

# Output should show:
# Server: 192.168.10.13 (AdGuard)
```

**If it shows something else:**
- Release/renew DHCP lease
- Windows: `ipconfig /release && ipconfig /renew`
- Mac: System Settings → Network → Renew DHCP Lease
- Linux: `sudo dhclient -r && sudo dhclient`

### Test 6.3: Test Blocking from Client

**From your laptop/phone:**

```bash
# Test AI blocking
nslookup chatgpt.com

# Should return 0.0.0.0 (blocked)

# Test social media
nslookup instagram.com

# Should return 0.0.0.0 (blocked)

# Test normal site
nslookup google.com

# Should return real IP (allowed)
```

### Test 6.4: Test DNS Redirection (Bypass Prevention)

**Try to use Google DNS directly:**

```bash
nslookup google.com 8.8.8.8
```

**What SHOULD happen:**
- The query should STILL go through AdGuard
- You might see it timeout or get redirected

**Check pfSense logs:**
1. **Firewall → NAT → Port Forward → View Applied NAT Rules**
2. Look for your redirect rule
3. **Status → System Logs → Firewall**
4. You should see NAT redirects happening

### Test 6.5: Test DoH/DoT Blocking

**Try to access a DoH server:**

```bash
# This should timeout or be blocked
curl -I https://dns.google/dns-query --max-time 5
```

**Check pfSense firewall logs:**
1. **Status → System Logs → Firewall**
2. Look for blocked connections to port 443 with DoH_DoT_Servers destination
3. Should show "Block DNS-over-HTTPS" rule

---

## Phase 7: Monitor & Verify (Ongoing)

### Check AdGuard Query Log

1. **Open AdGuard:** http://192.168.10.13:3053

2. **Query Log:**
   - Should now see queries from ALL devices on your network
   - Not just the homelab server
   - Should see blocked queries (red) from various devices

3. **Dashboard:**
   - "DNS queries" should be increasing from all network devices
   - "Blocked by filters" should show blocked content

### Check pfSense Logs

**Status → System Logs → Firewall:**

Look for:
- DNS redirections (NAT rule)
- DoH/DoT blocks (if enabled)
- Any unusual patterns

---

## Troubleshooting

### Devices Still Not Using AdGuard

**Check:**
1. DHCP lease renewed? (release/renew)
2. Static DNS configured on device? (remove it)
3. pfSense DHCP configured correctly? (Services → DHCP Server)
4. NAT redirect rule enabled? (Firewall → NAT → Port Forward)

### DNS Not Resolving at All

**Check:**
1. AdGuard container running? `docker ps | grep adguard`
2. Unbound container running? `docker ps | grep unbound`
3. Port 53 listening? `sudo netstat -tlnp | grep :53`
4. AdGuard upstream DNS correct? (172.30.0.2:53)

### Blocking Not Working

**Check:**
1. Blocklists loaded in AdGuard? (Filters → DNS blocklists)
2. Custom blocklists added? (ai-tools.txt, social-media.txt)
3. AdGuard query log shows the queries?
4. Queries being blocked (red) or allowed (green)?

### Devices Can Bypass Filtering

**Check:**
1. NAT redirect rule in pfSense? (Firewall → NAT → Port Forward)
2. "Invert match" checked for destination?
3. Associated firewall rule created and enabled?
4. Test: `nslookup google.com 8.8.8.8` (should fail or redirect)

### DoH/DoT Bypass Working

**Check:**
1. Alias downloaded? (Firewall → Aliases → URLs → DoH_DoT_Servers)
2. Firewall rule blocking port 443 to DoH servers?
3. Rule is at the TOP of LAN rules (above allow all)?
4. Test: `curl https://dns.google/dns-query` (should timeout)

---

## Summary Checklist

After completing all phases:

- [ ] pfSense system DNS set to AdGuard (192.168.10.13)
- [ ] DNS Resolver disabled (or forwarding to AdGuard)
- [ ] DHCP distributing AdGuard DNS to clients
- [ ] NAT redirect rule forcing all DNS to AdGuard
- [ ] DoH/DoT blocking rules created
- [ ] Client devices using AdGuard (check nslookup)
- [ ] Blocking working from clients (chatgpt.com → 0.0.0.0)
- [ ] AdGuard query log showing network-wide queries
- [ ] pfSense logs showing NAT redirects

---

## Next Steps

After pfSense configuration:

1. **Set up client-specific filtering** in AdGuard
   - Identify kids' devices by MAC address
   - Create client groups (Kids, Adults, Work)
   - Apply different blocklists per group

2. **Configure UniFi WiFi** (if applicable)
   - Guest network with strict filtering
   - IoT network with telemetry blocking

3. **Set up TrueNAS backups**
   - Daily snapshots of ~/docker/appdata/adguard
   - Retention: 7 daily, 4 weekly, 3 monthly

4. **Monitor and refine**
   - Review query logs weekly
   - Whitelist false positives
   - Adjust blocklists as needed

---

## Support

- **Full Setup Guide:** [SETUP.md](./SETUP.md)
- **Quick Start:** [QUICKSTART.md](./QUICKSTART.md)
- **pfSense Docs:** https://docs.netgate.com/pfsense/
- **AdGuard Docs:** https://github.com/AdguardTeam/AdGuardHome/wiki

---

**Estimated Time:** 30-40 minutes total
