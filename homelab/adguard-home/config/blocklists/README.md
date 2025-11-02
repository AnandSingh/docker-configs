# AdGuard Home Blocklists

This directory contains custom blocklists for AdGuard Home DNS filtering.

## Blocklists

### 1. `ai-tools.txt`
Blocks AI chatbots and homework assistance tools:
- ChatGPT, Claude, Gemini, Bing Chat
- AI writing tools (Jasper, Copy.ai, Quillbot)
- AI coding assistants (GitHub Copilot, Replit AI)
- AI homework help sites

**Use Case:** Prevent kids from using AI for homework cheating

### 2. `social-media.txt`
Blocks major social media platforms:
- Facebook, Instagram, WhatsApp (Meta)
- TikTok, Snapchat
- Twitter/X, Reddit
- Discord, Telegram
- Twitch, Pinterest, LinkedIn

**Use Case:** Limit kids' social media access for focus/safety

### 3. `kids-safe.txt`
Combined blocklist for comprehensive kids protection:
- Adult content
- Violence and gore
- Gambling
- Drugs/alcohol
- Hate speech
- Self-harm content

**Use Case:** Safe internet browsing for children

## Usage in AdGuard Home

### Method 1: Local File References (Recommended)
1. These files are mounted in the container at `/opt/adguardhome/blocklists/`
2. In AdGuard Home web UI, go to: **Filters → DNS blocklists**
3. Add custom blocklist with path:
   ```
   file:///opt/adguardhome/blocklists/ai-tools.txt
   file:///opt/adguardhome/blocklists/social-media.txt
   file:///opt/adguardhome/blocklists/kids-safe.txt
   ```

### Method 2: HTTP Server
Serve these files via web server and reference by URL.

## Client-Specific Filtering

Use AdGuard Home's **Client Settings** to apply different blocklists to different devices:

### Kids Devices
- ✅ ai-tools.txt
- ✅ social-media.txt
- ✅ kids-safe.txt
- ✅ OISD NSFW
- ✅ Blocklist Project - Adult

### Adult Devices
- ❌ No AI/social media blocking
- ✅ Ads & trackers only
- ✅ Malware blocking

### Work Devices
- ❌ No AI blocking (needed for work)
- ❌ No social media blocking
- ✅ Malware blocking only

## Maintenance

### Adding Domains
Edit the relevant `.txt` file and add one domain per line:
```
example.com
*.example.com
subdomain.example.com
```

### Testing
After updating, verify blocking:
```bash
# From any device on network
nslookup chatgpt.com 192.168.10.13
nslookup instagram.com 192.168.10.13
```

Should return `0.0.0.0` or NXDOMAIN if blocked.

### Backup
All blocklists are in git and backed up to TrueNAS via:
- `/mnt/truenas/adguard/conf/` (AdGuard config includes references)
- This repository (version controlled)

## External Blocklists

In addition to these custom lists, configure these external blocklists in AdGuard Home:

### Ads & Tracking
- AdGuard DNS filter
- OISD Big List: `https://big.oisd.nl/`
- 1Hosts Pro: `https://o0.pages.dev/Pro/adblock.txt`

### Adult Content
- OISD NSFW: `https://nsfw.oisd.nl/`
- Blocklist Project - Adult: `https://blocklistproject.github.io/Lists/porn.txt`
- StevenBlack (porn): `https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts`

### Malware & Security
- Blocklist Project - Malware: `https://blocklistproject.github.io/Lists/malware.txt`
- Blocklist Project - Phishing: `https://blocklistproject.github.io/Lists/phishing.txt`
- URLHaus: `https://urlhaus.abuse.ch/downloads/hostfile/`

### Privacy
- Blocklist Project - Tracking: `https://blocklistproject.github.io/Lists/tracking.txt`
- EasyPrivacy: `https://v.firebog.net/hosts/Easyprivacy.txt`

## Schedule

Blocklists update automatically every 24 hours in AdGuard Home.
