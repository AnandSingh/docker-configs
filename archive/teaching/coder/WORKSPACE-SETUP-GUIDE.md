# Coder Workspace Setup Guide - FLL Kids

Complete step-by-step guide to set up code-server workspaces for Gautham, Nihita, Dhruv, Farish, and future kids.

---

## Overview

You'll be setting up:
- ✅ **FLL Python Template** - Pre-configured with Python 3.11, Robot Framework, VS Code
- ✅ **User Accounts** - One account per kid
- ✅ **Individual Workspaces** - Each kid gets their own isolated environment
- ✅ **Familiar Interface** - Same VS Code setup they're used to from code-server

**Time Required:** 30-45 minutes for initial setup, 5 minutes per kid thereafter

---

## Prerequisites

Before starting, ensure:
- [x] Coder is running at `https://coder.lab.nexuswarrior.site`
- [x] You've created your admin account
- [x] You're logged into Coder dashboard as admin
- [x] You have SSH access to the teaching VM (192.168.10.29)

---

## Step 1: Build the FLL Python Docker Image

The template uses a custom Docker image with all the tools kids need.

### 1.1 SSH to Teaching VM

```bash
ssh dev@192.168.10.29
```

### 1.2 Navigate to Template Directory

```bash
cd /home/dev/docker-configs/teaching/coder/templates/fll-python
```

### 1.3 Build the Docker Image

```bash
# Build the image (takes 5-10 minutes)
docker build -t fll-python:latest .

# Verify the image was built
docker images | grep fll-python
```

**Expected output:**
```
fll-python    latest    abc123def456    2 minutes ago    1.2GB
```

### 1.4 Test the Image (Optional)

```bash
# Quick test to verify everything works
docker run --rm fll-python:latest python --version
# Should show: Python 3.11.x

docker run --rm fll-python:latest robot --version
# Should show: Robot Framework version info
```

---

## Step 2: Create the Template in Coder

Now you'll upload the Terraform template to Coder.

### 2.1 Open Coder Dashboard

Visit: `https://coder.lab.nexuswarrior.site`

### 2.2 Navigate to Templates

1. Click **"Templates"** in the left sidebar
2. Click **"Create Template"** button (top right)

### 2.3 Create New Template

**Method A: Upload Template (Recommended)**

1. On your local machine, copy the template file:
   ```bash
   cat ~/docker-configs/teaching/coder/templates/fll-python/main.tf
   ```

2. In Coder web UI:
   - Name: `FLL Python`
   - Display Name: `FLL Python & Robotics`
   - Description: `Python 3.11 workspace for FLL robotics with VS Code`
   - Icon: 🐍 (or choose the Python icon)

3. **Paste the Terraform code** from `main.tf` into the editor

4. Click **"Create Template"**

**Method B: Use Coder CLI (Alternative)**

```bash
# From your local machine
cd ~/docker-configs/teaching/coder/templates/fll-python

# Create template via CLI
coder templates create fll-python \
  --directory . \
  --name "FLL Python"
```

### 2.4 Verify Template

- You should see "FLL Python" in your templates list
- Status should show green "Active"

---

## Step 3: Create User Accounts for Kids

Each kid needs their own Coder user account.

### 3.1 Create User via Web UI

1. In Coder dashboard, click **"Users"** (left sidebar)
2. Click **"Create User"** button

3. **For each kid**, create an account:

**Gautham:**
```
Username: gautham
Email: gautham@fll.local
Password: [Generate a simple password for the kid]
```

**Nihita:**
```
Username: nihita
Email: nihita@fll.local
Password: [Generate a simple password for the kid]
```

**Dhruv:**
```
Username: dhruv
Email: dhruv@fll.local
Password: [Generate a simple password for the kid]
```

**Farish:**
```
Username: farish
Email: farish@fll.local
Password: [Generate a simple password for the kid]
```

4. Click **"Create User"** for each

### 3.2 Create Users via CLI (Faster Alternative)

```bash
# SSH to teaching VM
ssh dev@192.168.10.29

cd /home/dev/docker-configs/teaching/coder

# Create users
docker compose exec coder coder users create \
  --email gautham@fll.local \
  --username gautham \
  --password SimplePass123

docker compose exec coder coder users create \
  --email nihita@fll.local \
  --username nihita \
  --password SimplePass123

docker compose exec coder coder users create \
  --email dhruv@fll.local \
  --username dhruv \
  --password SimplePass123

docker compose exec coder coder users create \
  --email farish@fll.local \
  --username farish \
  --password SimplePass123
```

### 3.3 Save Credentials

**Important:** Write down each kid's credentials:

```
Gautham: gautham / [password]
Nihita:  nihita  / [password]
Dhruv:   dhruv   / [password]
Farish:  farish  / [password]
```

---

## Step 4: Create Workspaces for Each Kid

Now create a workspace for each kid using the FLL Python template.

### 4.1 Option A: Kids Create Their Own (Recommended)

**Give each kid these instructions:**

1. Go to: `https://coder.lab.nexuswarrior.site`
2. Login with your username and password
3. Click **"Create Workspace"**
4. Select **"FLL Python"** template
5. Workspace name: `[your-name]-workspace` (e.g., `gautham-workspace`)
6. Click **"Create Workspace"**
7. Wait 1-2 minutes for workspace to build
8. Click **"Open in VS Code"** or **"Terminal"**

### 4.2 Option B: You Create Them (As Admin)

**For each kid:**

1. Login to Coder as the kid's account
2. Click **"Workspaces"** → **"Create Workspace"**
3. Template: **FLL Python**
4. Name: `[name]-workspace`
5. Click **"Create"**

Repeat for: Gautham, Nihita, Dhruv, Farish

### 4.3 Monitor Workspace Creation

While workspaces are building, you can monitor progress:

```bash
# SSH to teaching VM
ssh dev@192.168.10.29

# Watch containers being created
watch docker ps
```

You should see containers named like:
- `coder-gautham-gautham-workspace`
- `coder-nihita-nihita-workspace`
- `coder-dhruv-dhruv-workspace`
- `coder-farish-farish-workspace`

---

## Step 5: Verify Workspaces Are Working

### 5.1 Test Each Workspace

For each kid's account:

1. Login to Coder
2. Open their workspace
3. Click **"Open in VS Code"**
4. VS Code should load in the browser
5. Open terminal in VS Code
6. Test Python:
   ```bash
   python --version
   # Should show: Python 3.11.x
   ```

7. Test Robot Framework:
   ```bash
   robot --version
   # Should show Robot Framework info
   ```

### 5.2 Check Resource Usage

```bash
# SSH to teaching VM
ssh dev@192.168.10.29

# Check resource usage
docker stats

# Should show each workspace using ~2GB RAM, 2 CPU cores
```

---

## Step 6: Migrate Kids from Old code-server

If the kids have existing code/projects in the old code-server setup:

### 6.1 Access Old Code-Server Files

```bash
# SSH to teaching VM
ssh dev@192.168.10.29

# Old code-server data is at:
ls /home/dev/code-server/gautham/workspace/
ls /home/dev/code-server/nihita/workspace/
# etc.
```

### 6.2 Copy Files to New Workspaces

```bash
# Find the new workspace volume
docker volume ls | grep coder-gautham

# Copy files from old to new
docker run --rm \
  -v /home/dev/code-server/gautham/workspace:/source \
  -v coder-gautham-gautham-workspace:/target \
  ubuntu:22.04 \
  cp -r /source/. /target/workspace/

# Repeat for each kid
```

### 6.3 Alternative: Let Kids Re-Download

If projects are in Git:
1. Kids can just `git clone` their repos again in new workspace
2. Cleaner migration, no old cruft

---

## Step 7: Share Access Info with Kids

### 7.1 Create Access Cards

Print or share this info with each kid:

```
╔════════════════════════════════════════╗
║   Your FLL Coding Workspace Access     ║
╠════════════════════════════════════════╣
║ URL:      https://coder.lab.nexuswarrior.site
║ Username: gautham
║ Password: [their password]
║
║ After login, click "Open in VS Code"
║ to start coding!
╚════════════════════════════════════════╝
```

### 7.2 First Login Instructions

**What kids should do:**
1. Open browser (Chrome, Firefox, Safari, Edge)
2. Go to: `https://coder.lab.nexuswarrior.site`
3. Login with username/password
4. Click on your workspace name
5. Click "Open in VS Code"
6. Start coding!

**First-time tips:**
- Change password after first login (optional)
- Create a folder for each project
- Use the terminal at bottom of VS Code
- All your work is saved automatically

---

## Troubleshooting

### Issue: Template creation fails

**Check:**
```bash
# Verify Docker image exists
docker images | grep fll-python

# If missing, rebuild:
cd /home/dev/docker-configs/teaching/coder/templates/fll-python
docker build -t fll-python:latest .
```

### Issue: Workspace won't start

**Check:**
```bash
# Check Coder logs
cd /home/dev/docker-configs/teaching/coder
docker compose logs coder | tail -50

# Check if Docker socket is accessible
docker ps
```

**Fix:**
- Ensure `/var/run/docker.sock` is mounted in Coder container
- Check VM has enough RAM/CPU (32GB RAM, 32 cores recommended for 12 kids)

### Issue: VS Code won't load

**Check:**
- Browser popup blocker disabled
- Try different browser
- Check if workspace container is running: `docker ps | grep coder-[username]`

### Issue: Kids forgot password

**Reset via CLI:**
```bash
ssh dev@192.168.10.29
cd /home/dev/docker-configs/teaching/coder

# Reset password
docker compose exec coder coder users update-password gautham
# Enter new password when prompted
```

---

## Scaling to 12 Kids

When you add 8 more kids for the full FLL team:

### Resource Check

```bash
# Check VM resources
ssh dev@192.168.10.29
htop  # Press 'q' to exit

# Ensure you have:
# - 32+ GB RAM available
# - 24+ CPU cores
# - 200+ GB disk space
```

### Create Additional Users

Repeat Step 3 for each new kid:
```bash
docker compose exec coder coder users create \
  --email kidname@fll.local \
  --username kidname \
  --password SimplePass123
```

### Monitor Performance

```bash
# Watch resource usage as kids work
docker stats

# If containers are slow, you can:
# 1. Reduce CPU/RAM per workspace in main.tf
# 2. Add more RAM to the VM
# 3. Ask kids to stop workspaces when not in use
```

---

## Managing Workspaces

### Start/Stop Workspaces

Kids can start/stop their own workspaces:
1. Login to Coder
2. Click workspace name
3. Click "Start" or "Stop"

**As admin:**
```bash
# Stop a workspace
docker stop coder-gautham-gautham-workspace

# Start a workspace (Coder will auto-restart)
docker start coder-gautham-gautham-workspace
```

### Delete a Workspace

**In Coder UI:**
1. Go to workspace
2. Click settings (gear icon)
3. Click "Delete Workspace"
4. Confirm

**Warning:** This deletes all the kid's code! Make sure they've pushed to Git first.

### Backup Workspaces

```bash
# Backup a specific workspace
docker run --rm \
  -v coder-gautham-gautham-workspace:/source \
  -v /home/dev/backups:/backup \
  ubuntu:22.04 \
  tar czf /backup/gautham-workspace-$(date +%Y%m%d).tar.gz /source

# Backup all workspaces
docker volume ls | grep coder- | awk '{print $2}' | while read vol; do
  docker run --rm \
    -v $vol:/source \
    -v /home/dev/backups:/backup \
    ubuntu:22.04 \
    tar czf /backup/$vol-$(date +%Y%m%d).tar.gz /source
done
```

---

## Next Steps

1. ✅ Complete this setup guide
2. → Test with 1-2 kids first
3. → Gather feedback and adjust
4. → Migrate all 4 current kids
5. → Add remaining 8 kids for full FLL team
6. → Setup Twingate for remote access (optional)

---

## Quick Reference

**Coder Dashboard:** https://coder.lab.nexuswarrior.site

**Common Commands:**
```bash
# Check Coder status
docker compose -f /home/dev/docker-configs/teaching/coder/docker-compose.yaml ps

# View Coder logs
docker compose -f /home/dev/docker-configs/teaching/coder/docker-compose.yaml logs -f

# List all users
docker compose -f /home/dev/docker-configs/teaching/coder/docker-compose.yaml exec coder coder users list

# List all workspaces
docker ps | grep coder-

# Check resource usage
docker stats
```

---

**Last Updated:** October 26, 2025
**Questions?** Check the main DEPLOYMENT-GUIDE.md or Coder docs at https://coder.com/docs
