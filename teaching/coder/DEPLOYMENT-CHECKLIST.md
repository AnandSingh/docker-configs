# Coder Deployment Checklist - Teaching VM

Quick checklist to deploy the latest Coder fixes to the teaching VM.

---

## Prerequisites

- ✅ All changes committed and pushed to GitHub
- ✅ SSH access to teaching VM (192.168.10.29)
- ✅ Coder accessible at https://coder.lab.nexuswarrior.site

---

## Step 1: Pull Latest Changes (2 min)

```bash
# SSH to teaching VM
ssh dev@192.168.10.29

# Navigate to repo
cd /home/dev/docker-configs

# Pull latest changes
git pull origin main

# Verify the changes
git log --oneline -3
# Should show: "Fix Coder workspace container initialization"
```

---

## Step 2: Add Docker Group to Coder Container (5 min)

This fixes Docker socket permission errors.

```bash
# Get the docker group ID
getent group docker
# Note the GID (number after the second colon), e.g., 999

# Edit docker-compose.yaml
cd /home/dev/docker-configs/teaching/coder
nano docker-compose.yaml
```

**Add this after the `volumes:` section (around line 30):**

```yaml
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /home/dev/docker/coder/data:/home/coder/.config/coderv2

    # Add Docker group for socket access
    group_add:
      - "999"  # Replace 999 with your docker group ID from above
```

**OR use this automated command:**

```bash
# Automatic method
cd /home/dev/docker-configs/teaching/coder

# Get docker GID and add to docker-compose
DOCKER_GID=$(getent group docker | cut -d: -f3)

# Backup original
cp docker-compose.yaml docker-compose.yaml.backup

# Add group_add after volumes section if not exists
if ! grep -q "group_add:" docker-compose.yaml; then
    # Find the line with "volumes:" and add group_add after the volumes block
    sed -i "/^    volumes:/a\\    group_add:\\n      - \"$DOCKER_GID\"" docker-compose.yaml
    echo "✅ Added group_add with GID $DOCKER_GID"
else
    echo "⚠️  group_add already exists, skipping"
fi

# Verify the change
grep -A 2 "group_add" docker-compose.yaml
```

---

## Step 3: Rebuild Docker Image (10 min)

The Dockerfile was updated to fix container initialization.

```bash
cd /home/dev/docker-configs/teaching/coder/templates/fll-python

# Rebuild the image
docker build -t fll-python:latest .

# This takes 5-10 minutes

# Verify the build
docker images | grep fll-python
# Should show: fll-python   latest   [id]   X seconds ago   ~1.2GB
```

---

## Step 4: Restart Coder Service (2 min)

```bash
cd /home/dev/docker-configs/teaching/coder

# Restart with new docker-compose config
docker compose down
docker compose up -d

# Check logs for errors
docker compose logs -f coder

# Look for:
# ✅ "Started HTTP listener at http://0.0.0.0:3000"
# ✅ No Docker socket permission errors

# Press Ctrl+C to exit logs when ready
```

---

## Step 5: Recreate Template Zip (2 min)

```bash
cd /home/dev/docker-configs/teaching/coder/templates

# Recreate the template zip with latest main.tf
./create-template-zip.sh

# Should show:
# ✅ Template zip created: fll-python-template.zip
```

---

## Step 6: Download Template Zip to Your Computer (1 min)

```bash
# From your Mac terminal (new window):
scp dev@192.168.10.29:/home/dev/docker-configs/teaching/coder/templates/fll-python-template.zip ~/Downloads/fll-python-final.zip
```

---

## Step 7: Delete Old Template in Coder (1 min)

1. Open browser: `https://coder.lab.nexuswarrior.site`
2. Login as admin
3. Click **Templates** in left sidebar
4. Find "fll-python" template
5. Click **Delete** (trash icon)
6. Confirm deletion

---

## Step 8: Upload New Template (2 min)

1. Still in Coder web UI
2. Click **Create Template**
3. Click upload/file icon
4. Select `~/Downloads/fll-python-final.zip`
5. Fill in:
   - **Name:** `fll-python`
   - **Display name:** `FLL Python`
   - **Description:** `Python 3.11 workspace for FLL robotics with VS Code`
   - **Icon:** 🐍
6. Click **Create Template**
7. Wait for template to process (~30 seconds)
8. Should show "Template created successfully"

---

## Step 9: Create Test Workspace (5 min)

Time to test if everything works!

```bash
# Create test user if not exists
ssh dev@192.168.10.29
cd /home/dev/docker-configs/teaching/coder

docker compose exec coder coder users create \
  --email test@fll.local \
  --username test \
  --password TestPass123

# Or skip if you already have a user
```

**In Coder Web UI:**

1. Login as test user (or your admin)
2. Click **Workspaces** → **Create Workspace**
3. Select **FLL Python** template
4. Workspace name: `test-workspace`
5. Click **Create Workspace**
6. **Watch the build logs for errors**

**Expected behavior:**
- ✅ Template initializes
- ✅ Container starts
- ✅ Agent connects (shows "Connected")
- ✅ Status changes to "Running"

**If it fails:**
- Check logs in Coder UI
- SSH to VM and check: `docker logs coder-test-test-workspace`

---

## Step 10: Test Workspace (3 min)

Once workspace shows "Running":

1. Click **Open in VS Code** or **Terminal**
2. Should open VS Code in browser
3. Open terminal in VS Code (bottom panel)
4. Test commands:

```bash
# Test Python
python --version
# Should show: Python 3.11.x

# Test Robot Framework
robot --version
# Should show Robot Framework version

# Create test file
echo 'print("Hello from Coder!")' > test.py
python test.py
# Should print: Hello from Coder!
```

**If everything works:** 🎉 Success!

---

## Step 11: Create User Accounts for Kids (10 min)

```bash
ssh dev@192.168.10.29
cd /home/dev/docker-configs/teaching/coder

# Create all 4 kids
docker compose exec coder coder users create \
  --email gautham@fll.local --username gautham --password [choose-password]

docker compose exec coder coder users create \
  --email nihita@fll.local --username nihita --password [choose-password]

docker compose exec coder coder users create \
  --email dhruv@fll.local --username dhruv --password [choose-password]

docker compose exec coder coder users create \
  --email farish@fll.local --username farish --password [choose-password]

# Save credentials somewhere safe!
```

---

## Step 12: Share Access with Kids

Give each kid:

```
=================================
   Your FLL Coding Workspace
=================================

URL:      https://coder.lab.nexuswarrior.site
Username: [their-username]
Password: [their-password]

Instructions:
1. Open the URL in your browser
2. Login with your username/password
3. Click "Create Workspace"
4. Select "FLL Python" template
5. Name it: [yourname]-workspace
6. Click "Create Workspace"
7. Wait 1-2 minutes
8. Click "Open in VS Code"
9. Start coding!
```

---

## Verification Checklist

After completing all steps, verify:

- [ ] Coder accessible at https://coder.lab.nexuswarrior.site (200/302, not 502)
- [ ] SSL certificate valid
- [ ] FLL Python template exists and shows in Templates list
- [ ] Test workspace creates successfully
- [ ] VS Code loads in browser
- [ ] Python 3.11 works in workspace
- [ ] Robot Framework installed
- [ ] All 4 kids have user accounts

---

## Troubleshooting

### Container Still Exits Immediately

**Check logs:**
```bash
ssh dev@192.168.10.29
docker logs coder-test-test-workspace
```

**Look for:**
- Missing agent init script
- Docker permissions errors
- Python/code-server startup errors

### Docker Permission Denied

**Fix:**
```bash
# Ensure group_add is in docker-compose.yaml
cd /home/dev/docker-configs/teaching/coder
grep -A 2 "group_add" docker-compose.yaml

# If missing, add it manually (Step 2 above)
```

### Template Upload Fails

**Check:**
- Template zip file size (should be ~1.5MB)
- Main.tf syntax (check for Terraform errors)
- Docker image exists: `docker images | grep fll-python`

### Workspace Won't Connect

**Check:**
- Container running: `docker ps | grep coder-test`
- Agent logs: `docker logs coder-test-test-workspace`
- Coder service logs: `docker compose logs coder`

---

## Rollback Procedure

If something goes wrong:

```bash
# Stop Coder
cd /home/dev/docker-configs/teaching/coder
docker compose down

# Restore from backup (if you created one)
cp docker-compose.yaml.backup docker-compose.yaml

# Start Coder
docker compose up -d

# Wait for old template to be available again
```

---

## Next Steps After Success

1. Let kids create their own workspaces
2. Migrate code from old code-server (if needed)
3. Monitor resource usage: `docker stats`
4. Plan for scaling to 12 kids
5. Consider adding Twingate for remote access

---

**Deployment Time:** ~30-40 minutes total

**Questions?** Check `WORKSPACE-SETUP-GUIDE.md` for detailed information.

---

**Last Updated:** October 26, 2025
