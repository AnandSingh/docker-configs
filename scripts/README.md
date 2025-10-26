# Remote Testing Scripts

These scripts can be run from **any computer on your network** to test your Traefik deployments.

## test-remote.sh

Universal remote testing script for both homelab and teaching VM.

### Usage

**Test Teaching VM:**
```bash
./test-remote.sh teaching
```

**Test Homelab:**
```bash
./test-remote.sh homelab
```

### What It Tests

1. **Network Connectivity** - Can the server be reached?
2. **Port Accessibility** - Are ports 80 and 443 open?
3. **DNS Resolution** - Do domains resolve to the correct IP?
4. **HTTP to HTTPS Redirect** - Is traffic being redirected?
5. **Service Accessibility** - Can each service be accessed via HTTPS?
6. **SSL Certificates** - Are Let's Encrypt certificates properly installed?

### Example Output

```
================================================
  Remote Traefik Testing - Teaching VM
  IP: 192.168.10.29
  Primary Domain: lab.nexuswarrior.site
================================================

[1/5] Testing Network Connectivity...

  Ping test (192.168.10.29): Reachable
✓ PASS - Server is reachable on network

[2/5] Testing Port Connectivity...

  Port 80 (HTTP): Open
✓ PASS - HTTP port is accessible
  Port 443 (HTTPS): Open
✓ PASS - HTTPS port is accessible

[3/5] Testing DNS Resolution...

  traefik.lab.nexuswarrior.site: 192.168.10.29 ✓
  coder.lab.nexuswarrior.site: 192.168.10.29 ✓
✓ PASS - DNS resolution working correctly

[4/5] Testing HTTP to HTTPS Redirect...

✓ PASS - HTTP redirects to HTTPS (Status: 301)

[5/5] Testing Services (HTTPS + SSL Certificates)...

Testing: Traefik Dashboard
  Domain: traefik.lab.nexuswarrior.site
  HTTPS: 200 (OK)
✓ PASS - Traefik Dashboard is accessible
  SSL Certificate: Let's Encrypt ✓
✓ PASS - Traefik Dashboard has valid Let's Encrypt certificate
...
```

### Running from Different Machines

**From your laptop (macOS/Linux):**
```bash
# Clone or copy the script
git clone https://github.com/YOUR_USERNAME/docker-configs.git
cd docker-configs/scripts

# Test teaching VM
./test-remote.sh teaching

# Test homelab
./test-remote.sh homelab
```

**From Windows (Git Bash or WSL):**
```bash
git clone https://github.com/YOUR_USERNAME/docker-configs.git
cd docker-configs/scripts
bash test-remote.sh teaching
```

**Quick download and run:**
```bash
# Download just the script
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/docker-configs/main/scripts/test-remote.sh
chmod +x test-remote.sh

# Run it
./test-remote.sh teaching
```

### Prerequisites

The script requires:
- `curl` - For HTTP/HTTPS testing
- `openssl` - For SSL certificate checking
- `ping` - For connectivity testing
- `nslookup` or `host` - For DNS testing
- `nc` (netcat) or bash `/dev/tcp` - For port testing

Most Linux/macOS systems have these by default.

### Troubleshooting

**DNS issues detected:**
```
⚠ WARN - DNS resolution issues detected
```
- Check your DNS server configuration
- Add temporary entries to `/etc/hosts` for testing:
  ```bash
  sudo nano /etc/hosts
  # Add:
  192.168.10.29 traefik.lab.nexuswarrior.site
  192.168.10.29 coder.lab.nexuswarrior.site
  ```

**Connection failed:**
```
✗ FAIL - Connection failed (DNS issue?)
```
- Verify the server IP is correct
- Check firewall rules
- Ensure you're on the same network

**Traefik Default certificate:**
```
⚠ WARN - Using Traefik default certificate
```
- Let's Encrypt certificates haven't been generated yet
- Check Traefik logs: `docker logs traefik`
- Verify Cloudflare API token is configured
- Wait 1-2 minutes for certificate generation

### Configuration

The script is pre-configured for:

**Homelab (192.168.10.13):**
- plexlab.site
- All media services (Jellyfin, Servarr stack)
- Management tools (Traefik, Portainer, Proxmox, TrueNAS)

**Teaching VM (192.168.10.29):**
- lab.nexuswarrior.site
- Coder platform
- Student code-server instances
- Management tools

To test different services, edit the `SERVICES` array in the script.

### Exit Codes

- `0` - All tests passed
- `1` - Some tests failed or server unreachable

### Related Tools

- `teaching/scripts/test-traefik.sh` - Run ON the teaching VM
- `homelab/scripts/test-traefik.sh` - Run ON the homelab server
- `teaching/scripts/check-certificates.sh` - Certificate diagnostics
- `homelab/scripts/setup-traefik-secrets.sh` - Setup secrets

---

**Last Updated:** 2025-10-26
