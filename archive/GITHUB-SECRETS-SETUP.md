# GitHub Secrets Setup Guide - Teaching VM

## Step-by-Step Instructions

### Step 1: Generate Secrets on Teaching VM

**SSH to your teaching VM:**
```bash
ssh dev@192.168.10.29
```

**Download and run the secrets generation script:**
```bash
cd ~/docker-configs
git pull origin main
bash SETUP-TEACHING-SECRETS.sh
```

**The script will:**
1. ✅ Generate Coder database password (32 chars)
2. ✅ Generate Traefik dashboard hashed password
3. ✅ Create SSH deployment key
4. ✅ Add SSH key to authorized_keys
5. ✅ Collect Cloudflare credentials
6. ✅ Save everything to `/tmp/teaching-vm-secrets.txt`
7. ✅ Create local `.env` files for testing

**What you'll need:**
- Cloudflare email
- Cloudflare API token (get from: https://dash.cloudflare.com/profile/api-tokens)

### Step 2: View Generated Secrets

**On the teaching VM:**
```bash
cat /tmp/teaching-vm-secrets.txt
```

This file contains all 9 secrets you need to add to GitHub.

### Step 3: Add Secrets to GitHub

**Go to your GitHub repository:**
```
https://github.com/YOUR_USERNAME/docker-configs/settings/secrets/actions
```

**Click "New repository secret" and add each one:**

#### Secret 1: TEACHING_DEPLOY_SSH_KEY
```
Name: TEACHING_DEPLOY_SSH_KEY
Value: [Copy the entire SSH private key from the file]
       (starts with -----BEGIN OPENSSH PRIVATE KEY-----)
```

#### Secret 2: TEACHING_DEPLOY_HOST
```
Name: TEACHING_DEPLOY_HOST
Value: 192.168.10.29
```

#### Secret 3: TEACHING_DEPLOY_USER
```
Name: TEACHING_DEPLOY_USER
Value: dev
       (or whatever username the script detected)
```

#### Secret 4: TEACHING_DEPLOY_PATH
```
Name: TEACHING_DEPLOY_PATH
Value: /home/dev/docker-configs
       (or the path the script detected)
```

#### Secret 5: TEACHING_CLOUDFLARE_EMAIL
```
Name: TEACHING_CLOUDFLARE_EMAIL
Value: your-email@example.com
       (the email you entered)
```

#### Secret 6: TEACHING_CLOUDFLARE_API_TOKEN
```
Name: TEACHING_CLOUDFLARE_API_TOKEN
Value: [Your Cloudflare API token]
```

#### Secret 7: TEACHING_TRAEFIK_DASH_USER
```
Name: TEACHING_TRAEFIK_DASH_USER
Value: admin
       (or whatever username you entered)
```

#### Secret 8: TEACHING_TRAEFIK_DASH_PASSWORD
```
Name: TEACHING_TRAEFIK_DASH_PASSWORD
Value: [The hashed password from the file]
       (starts with $$apr1$$...)
```

#### Secret 9: TEACHING_CODER_DB_PASSWORD
```
Name: TEACHING_CODER_DB_PASSWORD
Value: [The generated password from the file]
```

### Step 4: Verify Secrets

**In GitHub, you should now have 9 secrets:**
- ✅ TEACHING_DEPLOY_SSH_KEY
- ✅ TEACHING_DEPLOY_HOST
- ✅ TEACHING_DEPLOY_USER
- ✅ TEACHING_DEPLOY_PATH
- ✅ TEACHING_CLOUDFLARE_EMAIL
- ✅ TEACHING_CLOUDFLARE_API_TOKEN
- ✅ TEACHING_TRAEFIK_DASH_USER
- ✅ TEACHING_TRAEFIK_DASH_PASSWORD
- ✅ TEACHING_CODER_DB_PASSWORD

### Step 5: Clean Up Secrets File

**⚠️ IMPORTANT - Delete the secrets file:**
```bash
# On teaching VM
rm /tmp/teaching-vm-secrets.txt

# Verify it's deleted
ls -la /tmp/teaching-vm-secrets.txt
# Should say: No such file or directory
```

### Step 6: Test SSH Connection

**Test that GitHub Actions can SSH to your teaching VM:**
```bash
# On your local machine, test with the key
ssh -i ~/.ssh/github_deploy_teaching dev@192.168.10.29

# You should be able to login without password
# If it works, GitHub Actions will work too
```

---

## Cloudflare API Token Setup

If you need to create a Cloudflare API token:

1. Go to: https://dash.cloudflare.com/profile/api-tokens
2. Click "Create Token"
3. Use "Edit zone DNS" template
4. Configure:
   ```
   Permissions:
     - Zone / DNS / Edit

   Zone Resources:
     - Include / Specific zone / lab.nexuswarrior.site

   Client IP Address Filtering:
     - (optional) Add your teaching VM IP: 192.168.10.29

   TTL:
     - (optional) Set expiration date
   ```
5. Click "Continue to summary"
6. Click "Create Token"
7. **Copy the token** - you won't see it again!

---

## Troubleshooting

### Issue: Script says "htpasswd: command not found"

**Solution:**
```bash
# Install apache2-utils
sudo apt-get update
sudo apt-get install apache2-utils
```

### Issue: Can't find docker-configs directory

**Solution:**
```bash
# Clone the repository first
cd ~
git clone git@github.com:YOUR_USERNAME/docker-configs.git
cd docker-configs
```

### Issue: SSH key already exists

**The script will ask if you want to overwrite**
- Press `y` to create new key
- Press `n` to keep existing key

### Issue: Forgot to save Cloudflare API token

**You'll need to create a new one:**
1. Go to Cloudflare dashboard
2. Revoke old token
3. Create new token
4. Update GitHub secret

---

## Next Steps After Setup

Once all secrets are added to GitHub:

1. **Create GitHub Actions workflow** (see: `.github/workflows/deploy-teaching.yml`)
2. **Test manual deployment** on teaching VM
3. **Test GitHub Actions deployment**
4. **Setup Coder workspace template**
5. **Migrate kids from code-server**

---

## Security Checklist

- [x] Generated strong database password (32+ chars)
- [x] Created dedicated SSH key for deployment
- [x] Restricted Cloudflare token to specific zone
- [x] Used hashed password for Traefik dashboard
- [x] Deleted `/tmp/teaching-vm-secrets.txt` after adding to GitHub
- [x] `.env` files not committed to git (in `.gitignore`)
- [x] Secrets only stored in GitHub (encrypted)

---

**Created:** 2025-10-25
**Author:** Claude Code
