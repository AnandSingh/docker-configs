# Manual Deployment Guide - Teaching VM

## Quick Start - Deploy in 10 Minutes

This guide walks you through manually deploying the teaching VM services.

---

## Prerequisites Checklist

Before starting, make sure you have:

- [ ] SSH access to teaching VM (192.168.10.29)
- [ ] Docker and Docker Compose installed
- [ ] Git repository cloned
- [ ] DNS records pointing to teaching VM:
  - `coder.lab.nexuswarrior.site` → 192.168.10.29
  - `*.coder.lab.nexuswarrior.site` → 192.168.10.29
  - `traefik.lab.nexuswarrior.site` → 192.168.10.29
- [ ] Cloudflare API token
- [ ] NFS mount at `/home/dev/docker` (optional but recommended)

---

## Step 1: Generate Secrets (5 minutes)

**SSH to teaching VM:**
```bash
ssh dev@192.168.10.29
```

**Navigate to repository:**
```bash
cd ~/docker-configs
git pull origin main
```

**Run secrets generation script:**
```bash
bash SETUP-TEACHING-SECRETS.sh
```

**Follow the prompts:**
1. Press Enter to continue
2. Press Enter for username (default: admin)
3. Enter a password for Traefik dashboard
4. Enter your Cloudflare email
5. Enter your Cloudflare API token
6. Confirm the detected settings

**Result:**
- ✅ Secrets saved to `/tmp/teaching-vm-secrets.txt`
- ✅ `.env` files created in `teaching/traefik/` and `teaching/coder/`
- ✅ SSH key created and added to authorized_keys

---

## Step 2: Verify .env Files (1 minute)

**Check Traefik .env:**
```bash
cat ~/docker-configs/teaching/traefik/.env
```

Should contain:
```
CLOUDFLARE_EMAIL=your-email@example.com
CLOUDFLARE_API_TOKEN=your-token
DOMAIN=lab.nexuswarrior.site
TRAEFIK_DASHBOARD_USER=admin
TRAEFIK_DASHBOARD_PASSWORD=$$apr1$$...
```

**Check Coder .env:**
```bash
cat ~/docker-configs/teaching/coder/.env
```

Should contain:
```
CODER_DB_PASSWORD=long-random-string
```

---

## Step 3: Create Docker Network (30 seconds)

```bash
# Check if proxy network exists
docker network ls | grep proxy

# If not, create it
docker network create proxy
```

---

## Step 4: Deploy Traefik (2 minutes)

**Deploy Traefik:**
```bash
cd ~/docker-configs
./deploy/deploy.sh --server teaching traefik
```

**Expected output:**
```
==========================================
Multi-Server Deployment Router
Server: teaching (192.168.10.29)
Service: traefik
==========================================
✅ Successfully deployed teaching/traefik
```

**Verify Traefik is running:**
```bash
cd ~/docker-configs/teaching/traefik
docker compose ps
```

Should show:
```
NAME      STATUS       PORTS
traefik   Up X minutes  0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
```

**Check logs:**
```bash
docker compose logs traefik --tail=20
```

Look for:
- ✅ "Configuration loaded from file"
- ✅ SSL certificate generated
- ❌ No errors about API token

**Test Traefik dashboard:**
```bash
# Should show 200 OK
curl -I https://traefik.lab.nexuswarrior.site
```

---

## Step 5: Deploy Coder (2 minutes)

**Deploy Coder and PostgreSQL:**
```bash
cd ~/docker-configs
./deploy/deploy.sh --server teaching coder
```

**Expected output:**
```
==========================================
Multi-Server Deployment Router
Server: teaching (192.168.10.29)
Service: coder
==========================================
✅ Successfully deployed teaching/coder
```

**Verify Coder is running:**
```bash
cd ~/docker-configs/teaching/coder
docker compose ps
```

Should show:
```
NAME             STATUS       PORTS
coder            Up X seconds
coder-postgres   Up X seconds  (healthy)
```

**Watch Coder startup:**
```bash
docker compose logs -f coder
```

Wait for:
```
Started HTTP listener at http://[::]:3000
```

Press Ctrl+C to exit logs.

---

## Step 6: Access Coder (2 minutes)

**Open in browser:**
```
https://coder.lab.nexuswarrior.site
```

**First-time setup:**
1. You'll see "Welcome to Coder" page
2. Create admin account:
   - Username: `admin` (or your name)
   - Email: your-email@example.com
   - Password: (create a secure password)
3. Click "Create Account"

**You should now see the Coder dashboard!**

---

## Step 7: Build Coder Workspace Template (3 minutes)

**Build the FLL Python Docker image:**
```bash
cd ~/docker-configs/teaching/coder/templates/fll-python
docker build -t fll-python:latest .
```

This will take 2-3 minutes. You'll see:
- Python installation
- VS Code extensions installation
- Pybricks runner installation

**Verify image was built:**
```bash
docker images | grep fll-python
```

Should show:
```
fll-python   latest   abc123...   X minutes ago   X.XGB
```

---

## Step 8: Create Coder Template (5 minutes)

**In Coder dashboard (web UI):**

1. Click **Templates** in left sidebar
2. Click **Create Template**
3. Choose **Docker** as the provider
4. Click **Use this template**

**Template Configuration:**
- **Name:** `FLL Python`
- **Display Name:** `FLL Python Workspace`
- **Description:** `Python 3.11 workspace for FLL robotics with VS Code, pybricks-runner, and Robot Framework`
- **Icon:** 🐍 (optional)

**Copy template code:**
```bash
# On teaching VM, display the template
cat ~/docker-configs/teaching/coder/templates/fll-python/main.tf
```

Copy all the contents and paste into the Coder template editor.

**Click "Create Template"**

You should see: "✅ Template created successfully"

---

## Step 9: Create Test Workspace (3 minutes)

**In Coder dashboard:**

1. Click **Workspaces** in left sidebar
2. Click **Create Workspace**
3. Select **FLL Python** template
4. Configure:
   - **Workspace Name:** `test-workspace`
   - Click **Create Workspace**

**Wait for workspace to build:**
- Status: Building → Starting → Running (takes 1-2 minutes first time)

**Access workspace:**
- Click **Open in VS Code**
- Or click **Terminal** to get command line

**Test the workspace:**
```bash
# In workspace terminal
python --version
# Should show: Python 3.11.x

pip list
# Should show installed packages

robot --version
# Should show Robot Framework

code-server --list-extensions
# Should show all extensions including pybricks-runner
```

---

## Step 10: Deploy RustDesk (Optional, 1 minute)

**If you want remote desktop access:**
```bash
cd ~/docker-configs
./deploy/deploy.sh --server teaching rustdesk
```

---

## Verification Checklist

After deployment, verify everything:

### Services Running
```bash
cd ~/docker-configs/teaching
docker compose -f traefik/docker-compose.yaml ps
docker compose -f coder/docker-compose.yaml ps
```

All should show "Up" status.

### Web Access
- [ ] https://traefik.lab.nexuswarrior.site (Traefik dashboard)
- [ ] https://coder.lab.nexuswarrior.site (Coder dashboard)

### Coder Functionality
- [ ] Can create admin account
- [ ] Can see Templates page
- [ ] FLL Python template created
- [ ] Test workspace runs successfully
- [ ] Python 3.11 works
- [ ] VS Code extensions loaded
- [ ] Pybricks-runner extension present

---

## Troubleshooting

### Issue: Traefik can't get SSL certificate

**Check:**
```bash
docker compose -f ~/docker-configs/teaching/traefik/docker-compose.yaml logs traefik | grep -i error
```

**Common causes:**
- Wrong Cloudflare API token
- DNS records not propagated yet
- Port 443 blocked

**Fix:**
```bash
# Wait for DNS propagation (can take 5-10 minutes)
nslookup coder.lab.nexuswarrior.site

# Check Cloudflare API token
cat ~/docker-configs/teaching/traefik/.env
```

### Issue: Coder won't start

**Check logs:**
```bash
docker compose -f ~/docker-configs/teaching/coder/docker-compose.yaml logs coder
```

**Common causes:**
- Database password mismatch
- PostgreSQL not ready
- Port 3000 already in use

**Fix:**
```bash
# Recreate with fresh database
cd ~/docker-configs/teaching/coder
docker compose down -v
docker compose up -d

# Watch startup
docker compose logs -f
```

### Issue: Workspace template creation fails

**Check:**
- Is `fll-python:latest` image built?
- Is the `main.tf` syntax correct?
- Check Coder logs for errors

**Fix:**
```bash
# Rebuild the image
cd ~/docker-configs/teaching/coder/templates/fll-python
docker build -t fll-python:latest . --no-cache
```

### Issue: Can't access services from browser

**Check DNS:**
```bash
nslookup coder.lab.nexuswarrior.site
# Should return: 192.168.10.29

nslookup traefik.lab.nexuswarrior.site
# Should return: 192.168.10.29
```

**Check firewall:**
```bash
sudo ufw status
# Make sure ports 80 and 443 are allowed
```

---

## Next Steps

After successful deployment:

1. **Add more kids:**
   - Create user accounts in Coder
   - Share login credentials
   - Have them create workspaces

2. **Migrate from code-server:**
   - Copy kids' code to new workspaces
   - Test with 1-2 kids first
   - Gradually onboard all kids

3. **Setup GitHub Actions:**
   - Add secrets to GitHub (use `/tmp/teaching-vm-secrets.txt`)
   - Create workflow file
   - Test automated deployment

4. **Scale to 12 kids:**
   - Monitor resource usage
   - Adjust Coder resource limits if needed

---

## Cleanup Secrets File

**⚠️ IMPORTANT:**
```bash
# After everything works, delete the secrets file
rm /tmp/teaching-vm-secrets.txt

# Verify
ls /tmp/teaching-vm-secrets.txt
# Should say: No such file or directory
```

---

## Success Criteria

✅ Deployment is successful when:
- Traefik dashboard accessible
- Coder dashboard accessible
- Can create admin account in Coder
- FLL Python template created
- Test workspace runs
- Python, extensions, pybricks-runner work

---

**Ready to deploy?** Start with Step 1!

**Questions?** Check the troubleshooting section or review:
- `deploy/TEACHING-VM-SECRETS.md`
- `teaching/coder/DEPLOYMENT-GUIDE.md`
