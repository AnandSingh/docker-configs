# Coder Deployment Guide - FLL Teaching Environment

## Quick Overview

Deploy Coder on your existing teaching VM (192.168.10.29) alongside current code-server setup.

**What you'll get:**
- ✅ Professional workspace management for 12 kids
- ✅ Access via: `coder.lab.nexuswarrior.site`
- ✅ Individual workspaces for each kid
- ✅ Python 3.11 + Robot Framework + VS Code
- ✅ Doesn't disrupt existing code-server

**Time:** 30-45 minutes

---

## Prerequisites

- [x] VM running: 192.168.10.29
- [x] Traefik already configured
- [x] Domain: lab.nexuswarrior.site
- [ ] SSH access to VM
- [ ] `proxy` Docker network exists

---

## Step 1: Prepare on Your Local Machine

### 1.1 Update Repository

```bash
# On your local machine
cd /Users/anand/mindsync/github/docker-configs

# Add Coder files to git
git add coder/
git status

# Commit
git commit -m "Add Coder setup for FLL kids teaching environment

- Docker compose with PostgreSQL backend
- Traefik integration with wildcard routing
- Python/Robotics workspace template
- Ready for 12 concurrent users"

# Push (will auto-deploy via GitHub Actions)
git push origin main
```

### 1.2 Verify Deployment

Check GitHub Actions to see if it deployed to your homelab.

---

## Step 2: Setup on Teaching VM

### 2.1 SSH to Teaching VM

```bash
ssh <username>@192.168.10.29
```

### 2.2 Navigate to Coder Directory

```bash
cd /path/to/docker-configs/coder
# Or wherever your docker-configs repo is on the teaching VM
```

### 2.3 Create .env File

```bash
# Generate secure password
openssl rand -base64 32

# Create .env file
cat > .env << 'EOF'
CODER_DB_PASSWORD=<paste-the-generated-password-here>
EOF
```

### 2.4 Verify Traefik Network Exists

```bash
# Check if proxy network exists
docker network ls | grep proxy

# If it doesn't exist, create it
docker network create proxy
```

### 2.5 Verify TrueNAS NFS Mount

```bash
# Check NFS mount is active
df -h | grep docker

# Should show:
# 192.168.10.15:/mnt/nas-pool/nfs-share/docker  XXG  XXG  XXG  XX% /home/dev/docker

# Create Coder directories on NFS storage (will be auto-created, but good to verify)
ls -la /home/dev/docker/
```

**Important:** All Coder data (PostgreSQL database, config, workspace data) will be stored on TrueNAS via this NFS mount. This ensures:
- ✅ Data persists even if containers are removed
- ✅ Automatic backups via TrueNAS snapshots
- ✅ No data loss during updates or maintenance

---

## Step 3: DNS Configuration

### 3.1 Add DNS Records

On your DNS provider (Cloudflare, etc.), add these records:

```
Type: A or CNAME
Name: coder.lab
Host: coder.lab.nexuswarrior.site
Value: <your-public-ip-or-homelab-ip>

Type: A or CNAME
Name: *.coder.lab
Host: *.coder.lab.nexuswarrior.site
Value: <your-public-ip-or-homelab-ip>
```

**Note:** If using Cloudflare DNS challenge for Let's Encrypt (via Traefik), the wildcard cert will be generated automatically.

---

## Step 4: Start Coder

### 4.1 Start Services

```bash
cd /path/to/coder

# Start Coder and PostgreSQL
docker compose up -d

# Watch logs
docker compose logs -f
```

### 4.2 Wait for Startup

Wait ~30 seconds for:
- PostgreSQL to initialize
- Coder to start
- Traefik to generate SSL cert

### 4.3 Check Status

```bash
# Check containers
docker compose ps

# Should see:
# coder          running
# coder-postgres running

# Check logs for errors
docker compose logs coder | tail -20
```

---

## Step 5: Initial Coder Setup

### 5.1 Access Coder Dashboard

Open browser: `https://coder.lab.nexuswarrior.site`

### 5.2 Create First Admin Account

1. **First-time setup wizard will appear**
2. Create admin account:
   ```
   Username: admin (or your name)
   Email: your-email@example.com
   Password: <secure-password>
   ```
3. Click **Create Account**

### 5.3 Login

You should now see the Coder dashboard!

---

## Step 6: Create Python/Robotics Template

### 6.1 Build Custom Docker Image

Back on the teaching VM:

```bash
cd /path/to/coder/templates/fll-python

# Build the image
docker build -t fll-python:latest .

# Verify
docker images | grep fll-python
```

### 6.2 Create Template in Coder (Web UI)

1. In Coder dashboard, click **Templates** (left sidebar)
2. Click **Create Template**
3. Select **Docker** as provider
4. **Template Configuration:**
   ```
   Name: FLL Python
   Description: Python 3.11 workspace for FLL robotics
   Icon: 🐍 (or choose Python icon)
   ```

5. **Template Code:** Use the generated `main.tf` from `templates/fll-python/main.tf`
   - Copy the contents
   - Paste into Coder template editor

6. Click **Create Template**

---

## Step 7: Create Test Workspace

### 7.1 Create Workspace for Testing

1. Click **Workspaces** (left sidebar)
2. Click **Create Workspace**
3. Select **FLL Python** template
4. Configure:
   ```
   Workspace Name: test-workspace
   ```
5. Click **Create Workspace**

### 7.2 Wait for Provisioning

- Workspace will build (takes 1-2 minutes first time)
- Status will change: Building → Starting → Running

### 7.3 Access Workspace

1. Click **Open in VS Code**
2. Or click **Terminal** for command-line access

### 7.4 Test Python Environment

In the workspace terminal:

```bash
# Check Python version
python --version
# Should show: Python 3.11.x

# Test pip
pip list

# Test Robot Framework
robot --version

# Create test file
echo 'print("Hello from FLL workspace!")' > test.py
python test.py
```

**✅ If everything works, you're ready to add kids!**

---

## Step 8: Add Kids as Users

### 8.1 Create User Accounts

In Coder dashboard:

1. Click **Users** (left sidebar)
2. Click **Create User**
3. For each kid:
   ```
   Username: gautham  (or nihita, etc.)
   Email: gautham@fll.local (can be fake for now)
   Password: <temp-password>
   ```
4. Click **Create**

### 8.2 Share Credentials with Kids

Give each kid:
```
URL: https://coder.lab.nexuswarrior.site
Username: <their-username>
Password: <temp-password>
Instructions: "Change password after first login"
```

### 8.3 Kids Create Their Workspaces

Each kid:
1. Logs into Coder
2. Clicks **Create Workspace**
3. Selects **FLL Python** template
4. Names it (e.g., "gautham-workspace")
5. Starts coding!

---

## Step 9: Test with 1-2 Kids First

### 9.1 Pilot Test

Before migrating all 4 kids:

1. **Have 1-2 kids try Coder**
2. **Keep code-server running** (fallback)
3. **Compare experience:**
   - Easier to use?
   - Performance OK?
   - VS Code works well?
   - Any issues?

### 9.2 Gather Feedback

Ask kids:
- "Is this easier than before?"
- "Can you find your files?"
- "Does it feel fast enough?"
- "Any problems?"

### 9.3 Iterate

Based on feedback:
- Adjust resource limits (CPU/RAM per workspace)
- Add more tools kids need
- Fix any issues

---

## Step 10: Scale to 12 Users

### 10.1 Check VM Resources

```bash
# Check current usage
htop
# Or: docker stats

# Make sure you have:
# - 32+ GB RAM available
# - 24+ CPU cores
```

### 10.2 Create All 12 User Accounts

Repeat Step 8 for all 12 kids.

### 10.3 Monitor Performance

```bash
# Watch resource usage
watch docker stats

# Check Coder logs
docker compose logs -f coder
```

---

## Maintenance & Monitoring

### Daily Checks

```bash
# Check if services are running
docker compose ps

# Check logs for errors
docker compose logs --tail=50 coder
```

### Backup User Data

```bash
# Backup PostgreSQL database
docker compose exec postgres pg_dump -U coder coder > coder-backup-$(date +%Y%m%d).sql

# Backup workspaces (Docker volumes)
docker volume ls | grep coder
# Individual workspace volumes are named: coder-<username>-<workspace-name>
```

### Update Coder

```bash
# Pull latest image
docker compose pull

# Restart with new version
docker compose up -d

# Coder will automatically migrate database if needed
```

---

## Troubleshooting

### Issue: Can't access coder.lab.nexuswarrior.site

**Check:**
```bash
# Is container running?
docker compose ps

# Check Traefik logs
docker logs traefik

# Check if port 3000 is accessible internally
curl http://localhost:3000
```

**Fix:**
- Verify DNS records
- Check Traefik labels in docker-compose.yaml
- Ensure proxy network is connected

### Issue: Workspaces won't start

**Check:**
```bash
# Check Docker socket access
docker ps

# Check Coder logs
docker compose logs coder | grep -i error

# Check available resources
free -h
df -h
```

**Fix:**
- Ensure `/var/run/docker.sock` is mounted in Coder container
- Check VM has enough RAM/CPU
- Verify template syntax is correct

### Issue: Kids can't login

**Check:**
```bash
# Check PostgreSQL is running
docker compose ps postgres

# Check Coder logs
docker compose logs coder | grep -i auth
```

**Fix:**
- Verify users were created correctly
- Check CODER_ACCESS_URL is correct
- Reset password if needed (via Coder UI as admin)

---

## Comparison: code-server vs Coder

| Feature | code-server (current) | Coder (new) |
|---------|----------------------|-------------|
| **Setup** | One container per kid | One Coder, many workspaces |
| **Access** | gautham.lab.nexuswarrior.site | coder.lab.nexuswarrior.site |
| **Management** | Manual per kid | Centralized dashboard |
| **Resources** | Fixed per container | Dynamic per workspace |
| **Templates** | Manual setup | Reusable templates |
| **Scaling** | Add more containers | Just create workspace |
| **Updates** | Update each container | Update once, affects all |

**Winner:** Coder is much easier to manage for 12 kids!

---

## Next Steps After Coder Works

1. ✅ Coder deployed and tested
2. → Add Twingate for remote access
3. → Migrate all 4 kids from code-server
4. → Scale to 12 kids for FLL
5. → FLL competition prep!

---

## Emergency Rollback

If Coder doesn't work well:

```bash
# Stop Coder
docker compose down

# Kids go back to code-server
# Nothing was disrupted!
```

---

## Support & Resources

- **Coder Docs:** https://coder.com/docs
- **Templates:** https://github.com/coder/coder/tree/main/examples/templates
- **Community:** https://github.com/coder/coder/discussions

---

**Ready to deploy?** 🚀

Start with **Step 1** and let me know if you hit any issues!
