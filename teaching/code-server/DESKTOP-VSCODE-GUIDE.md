# Connecting Desktop VS Code to code-server

Guide for connecting desktop VS Code application to your existing code-server instances running on the teaching VM.

---

## Current Setup

You have 5 code-server instances:
- **Farish:** https://farish.lab.nexuswarrior.site (port 8445)
- **Dhruv:** https://dhruv.lab.nexuswarrior.site (port 8446)
- **Gautham:** https://gautham.lab.nexuswarrior.site (port 8447)
- **Nihita:** https://nihita.lab.nexuswarrior.site (port 8448)
- **Anand:** https://anand.lab.nexuswarrior.site (port 8449)

All accessible via browser ✅

**Goal:** Connect from desktop VS Code app to these workspaces.

---

## Method 1: SSH Remote Development (Recommended)

This is the cleanest approach - VS Code connects directly to the teaching VM via SSH.

### Advantages
✅ Native VS Code experience (not browser)
✅ Full access to workspace files
✅ No port forwarding needed
✅ Can access all kids' workspaces from one connection
✅ Uses SSH keys you already have

### Setup Steps

#### 1. Install Remote-SSH Extension

In desktop VS Code:
1. Open VS Code on your Mac
2. Go to Extensions (⇧⌘X)
3. Search for: **Remote - SSH**
4. Install the extension by Microsoft

#### 2. Configure SSH Connection

```bash
# On your Mac, edit SSH config
nano ~/.ssh/config
```

**Add this configuration:**

```ssh
Host teaching-vm
    HostName 192.168.10.29
    User dev
    IdentityFile ~/.ssh/id_rsa
    ForwardAgent yes

# Alias for each kid's workspace
Host farish-workspace
    HostName 192.168.10.29
    User dev
    IdentityFile ~/.ssh/id_rsa
    RemoteCommand cd /home/dev/code-server-config/farish/workspace && exec $SHELL

Host dhruv-workspace
    HostName 192.168.10.29
    User dev
    IdentityFile ~/.ssh/id_rsa
    RemoteCommand cd /home/dev/code-server-config/dhruv/workspace && exec $SHELL

Host gautham-workspace
    HostName 192.168.10.29
    User dev
    IdentityFile ~/.ssh/id_rsa
    RemoteCommand cd /home/dev/code-server-config/gautham/workspace && exec $SHELL

Host nihita-workspace
    HostName 192.168.10.29
    User dev
    IdentityFile ~/.ssh/id_rsa
    RemoteCommand cd /home/dev/code-server-config/nihita/workspace && exec $SHELL

Host anand-workspace
    HostName 192.168.10.29
    User dev
    IdentityFile ~/.ssh/id_rsa
    RemoteCommand cd /home/dev/code-server-config/anand/workspace && exec $SHELL
```

#### 3. Connect from VS Code

**In desktop VS Code:**

1. Press `⇧⌘P` (Command Palette)
2. Type: `Remote-SSH: Connect to Host`
3. Select one of your hosts:
   - `teaching-vm` - Main connection
   - `farish-workspace` - Opens directly in Farish's workspace
   - `gautham-workspace` - Opens in Gautham's workspace
   - etc.

4. VS Code will open a new window connected via SSH
5. You'll see "SSH: teaching-vm" in the bottom-left corner
6. Open folder: `/home/dev/code-server-config/[kid-name]/workspace`

#### 4. Install Extensions on Remote

Extensions need to be installed on the remote server:
1. Once connected via SSH
2. Go to Extensions
3. You'll see two sections: "Local" and "SSH: teaching-vm"
4. Install extensions in the "SSH" section

**Recommended extensions (install on remote):**
- Python
- Black Formatter
- GitLens
- Error Lens
- PDF viewer

---

## Method 2: SSH Port Forwarding (Alternative)

Forward the code-server ports to your local machine.

### Advantages
✅ Access via localhost
✅ Works if you can't use Remote-SSH
✅ Can access through browser at localhost

### Disadvantages
⚠️ Need separate tunnel for each kid
⚠️ Still uses browser-based VS Code (not desktop app)

### Setup Steps

#### Forward All Ports at Once

```bash
# On your Mac, create SSH tunnel with all ports
ssh -L 8445:localhost:8445 \
    -L 8446:localhost:8446 \
    -L 8447:localhost:8447 \
    -L 8448:localhost:8448 \
    -L 8449:localhost:8449 \
    dev@192.168.10.29 -N

# Keep this terminal open
```

**Then access via browser:**
- Farish: http://localhost:8445
- Dhruv: http://localhost:8446
- Gautham: http://localhost:8447
- Nihita: http://localhost:8448
- Anand: http://localhost:8449

#### Create Helper Script

Save this as `~/tunnel-code-servers.sh`:

```bash
#!/bin/bash

echo "🚇 Creating SSH tunnels to code-servers..."
echo "Press Ctrl+C to stop"
echo ""
echo "Access via:"
echo "  Farish:  http://localhost:8445"
echo "  Dhruv:   http://localhost:8446"
echo "  Gautham: http://localhost:8447"
echo "  Nihita:  http://localhost:8448"
echo "  Anand:   http://localhost:8449"
echo ""

ssh -L 8445:localhost:8445 \
    -L 8446:localhost:8446 \
    -L 8447:localhost:8447 \
    -L 8448:localhost:8448 \
    -L 8449:localhost:8449 \
    dev@192.168.10.29 -N
```

```bash
# Make it executable
chmod +x ~/tunnel-code-servers.sh

# Run it
~/tunnel-code-servers.sh
```

---

## Method 3: Direct Desktop VS Code Connection (Advanced)

Make code-server accept connections from desktop VS Code using code-server's CLI.

### Requirements
⚠️ This method is complex and not recommended
⚠️ Requires modifying code-server settings
⚠️ May conflict with browser access

### Why Not Recommended?

The LinuxServer code-server image is optimized for browser access. To connect desktop VS Code directly, you would need to:
1. Expose additional ports
2. Configure authentication differently
3. Handle SSL certificates
4. May break browser access

**Verdict:** Use Method 1 (Remote-SSH) instead.

---

## Method 4: VS Code Remote Tunnels (New!)

VS Code has a built-in tunneling feature.

### Setup

**On the teaching VM (for each code-server):**

```bash
# SSH to teaching VM
ssh dev@192.168.10.29

# Enter one of the code-server containers
docker exec -it farish-code-server bash

# Install VS Code CLI
curl -Lk 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' \
  --output vscode_cli.tar.gz
tar -xf vscode_cli.tar.gz

# Start tunnel (requires GitHub login)
./code tunnel
```

This creates a secure tunnel via Microsoft's servers. You get a URL like:
```
https://vscode.dev/tunnel/[machine-name]
```

**Advantages:**
✅ Access from anywhere (not just local network)
✅ No SSH needed
✅ Works through firewalls

**Disadvantages:**
⚠️ Requires GitHub account
⚠️ Data goes through Microsoft servers
⚠️ More complex setup for multiple users

---

## Recommended Setup for You

Based on your setup, I recommend **Method 1: SSH Remote Development**.

### Quick Start

```bash
# 1. Install Remote-SSH extension in desktop VS Code

# 2. Add to ~/.ssh/config on your Mac:
Host teaching-vm
    HostName 192.168.10.29
    User dev
    IdentityFile ~/.ssh/id_rsa

# 3. In VS Code:
#    ⇧⌘P → "Remote-SSH: Connect to Host" → "teaching-vm"

# 4. Open folder: /home/dev/code-server-config/[kid-name]/workspace
```

### For the Kids

If kids want to use desktop VS Code:

**Option A:** Give them SSH access (secure)
- Create SSH keys for each kid
- Add to teaching VM's authorized_keys
- Kids install Remote-SSH extension
- Kids connect via SSH

**Option B:** Port forwarding (simpler)
- You run the tunnel script
- Kids access via localhost URLs
- Still browser-based, but via localhost

**Option C:** Keep using browser (easiest)
- No changes needed
- Works exactly as it does now
- Browser VS Code is feature-complete

---

## Comparison Table

| Method | Desktop App? | Kids Can Use? | Setup Complexity | Best For |
|--------|-------------|---------------|------------------|----------|
| **Remote-SSH** | ✅ Yes | ✅ Yes (with SSH keys) | Medium | You, advanced users |
| **Port Forward** | ❌ No (browser) | ✅ Yes | Easy | Quick local access |
| **Direct Connect** | ✅ Yes | ❌ Complex | Very Hard | Not recommended |
| **VS Code Tunnel** | ✅ Yes | ⚠️ Maybe | Hard | Remote access anywhere |
| **Keep Browser** | ❌ No | ✅ Yes | None | Kids, current setup |

---

## Detailed Remote-SSH Setup for Kids

If you want kids to use desktop VS Code:

### Step 1: Generate SSH Keys for Each Kid

```bash
# On your Mac or their computer
ssh-keygen -t ed25519 -C "gautham@fll" -f ~/.ssh/gautham_fll
ssh-keygen -t ed25519 -C "nihita@fll" -f ~/.ssh/nihita_fll
ssh-keygen -t ed25519 -C "dhruv@fll" -f ~/.ssh/dhruv_fll
ssh-keygen -t ed25519 -C "farish@fll" -f ~/.ssh/farish_fll

# No password for kids (press Enter twice)
```

### Step 2: Add Keys to Teaching VM

```bash
# SSH to teaching VM
ssh dev@192.168.10.29

# Add each kid's public key
nano ~/.ssh/authorized_keys

# Paste the contents of:
# - gautham_fll.pub
# - nihita_fll.pub
# - dhruv_fll.pub
# - farish_fll.pub

# Save and exit
```

### Step 3: Give Kids Their SSH Config

Each kid adds to their `~/.ssh/config`:

**Gautham's config:**
```ssh
Host my-code-server
    HostName 192.168.10.29
    User dev
    IdentityFile ~/.ssh/gautham_fll
    RemoteCommand cd /home/dev/code-server-config/gautham/workspace && exec $SHELL
```

**Nihita's config:**
```ssh
Host my-code-server
    HostName 192.168.10.29
    User dev
    IdentityFile ~/.ssh/nihita_fll
    RemoteCommand cd /home/dev/code-server-config/nihita/workspace && exec $SHELL
```

(Similar for Dhruv and Farish)

### Step 4: Kids Install Remote-SSH Extension

1. Install desktop VS Code
2. Install Remote-SSH extension
3. ⇧⌘P → "Remote-SSH: Connect to Host"
4. Select "my-code-server"
5. VS Code opens their workspace

---

## Troubleshooting

### "Could not establish connection to remote"

**Check:**
```bash
# Test SSH connection
ssh dev@192.168.10.29

# Verify SSH key
ssh -i ~/.ssh/id_rsa dev@192.168.10.29
```

### Extensions not working in Remote-SSH

**Fix:**
- Install extensions in the "SSH: teaching-vm" section, not "Local"
- Some extensions only work locally (like themes)

### Port forward not working

**Check:**
```bash
# Test if port is open
nc -zv 192.168.10.29 8447

# Check if code-server is running
ssh dev@192.168.10.29 "docker ps | grep code-server"
```

### Kids can't connect

**Check:**
- SSH key added to authorized_keys?
- Permissions on ~/.ssh: `chmod 700 ~/.ssh`
- Permissions on authorized_keys: `chmod 600 ~/.ssh/authorized_keys`

---

## Security Considerations

### If giving kids SSH access:

1. **Use separate keys** (done above)
2. **Restrict SSH access** (optional):
   ```bash
   # In ~/.ssh/authorized_keys, prefix each key with:
   restrict,command="cd /home/dev/code-server-config/gautham/workspace && exec $SHELL" ssh-ed25519 AAAA...
   ```
3. **Monitor SSH access:**
   ```bash
   tail -f /var/log/auth.log | grep "Accepted publickey"
   ```

---

## Recommendation Summary

**For You (Anand):**
→ Use **Remote-SSH** (Method 1)
- Full desktop VS Code experience
- Direct access to all workspaces
- Easy to switch between kids' folders

**For the Kids:**
→ Keep using **browser** (current setup)
- No changes needed
- Already working well
- Easier to manage

**If kids really want desktop VS Code:**
→ Use **Remote-SSH with individual keys**
- Set up SSH keys for each kid
- They can use desktop VS Code
- You maintain control via SSH

---

## Quick Setup for You

```bash
# 1. On your Mac
nano ~/.ssh/config

# Add:
Host teaching-vm
    HostName 192.168.10.29
    User dev
    IdentityFile ~/.ssh/id_rsa

# 2. In VS Code: Install Remote-SSH extension

# 3. Connect: ⇧⌘P → Remote-SSH: Connect to Host → teaching-vm

# 4. Open folder: /home/dev/code-server-config/anand/workspace

# Done! 🎉
```

---

**Last Updated:** October 26, 2025
