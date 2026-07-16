# Homelab TODO

Open follow-ups from the 2026-06-22/23 network + WiFi build. None are blocking — the
core setup (pfSense 2-network + VLANs, Proxmox, docker hosts, DNS/ad-blocking, WiFi)
is live and verified.

## DNS / access (found 2026-06-23)
- [x] **AdGuard resolving `plexlab.site`** — FIXED 2026-06-30 (added AdGuard apex `plexlab.site → 192.168.10.13` + wildcard `*.plexlab.site → 192.168.10.13` A rewrites; all subdomains resolve on LAN) — Traefik on `.13:443` serves it (HTTP 200) and Cloudflare publicly points `plexlab.site → 192.168.10.13`, but AdGuard returns the name with NO IP, so HOME clients can't reach it. Likely a broken/missing AdGuard DNS rewrite or upstream resolution issue. Fix: add AdGuard rewrite `*.plexlab.site → 192.168.10.13`, or debug why unbound/AdGuard drops it.

## eink-dashboard (magic mirror)
- [x] **Phase 1 shipped** 2026-06-30 — server deployed at https://dash.plexlab.site (internal + Twingate), homelab/eink-dashboard stack, mock vision + Snoqualmie weather + quarter widget. Demo data.
- [ ] **Phase 2 — task capture without glasses** (own brainstorm): phone→Syncthing→inbox, or Telegram/WhatsApp bot via existing /bot, or web/PWA form.
- [ ] **Phase 3 — physical display on Boox Mira Pro** (25.3", native 3200x1800, 16-level grayscale e-ink):
  - Device: **Raspberry Pi 4 (4GB)** + micro-HDMI→HDMI cable + SD card + USB-C power. (USB-C single-cable does NOT power the Mira Pro — it needs its own adapter; Pi has no DP/USB-C video anyway.)
  - Wiring: Mira on its own power adapter; Pi micro-HDMI → Mira HDMI in.
  - Crispness: render at native 3200x1800 (done) + force Pi HDMI to exact 3200x1800 (custom mode in config.txt / hdmi_cvt) so the Mira never scales (1:1 = pixel-perfect).
  - Client: repo pi-client (pi-client/display.py + systemd unit) → point DASHBOARD_SERVER at http://dash.plexlab.site → feh fullscreen. Change-gated polling minimizes e-ink refresh/ghosting.
  - [x] panel res set to 3200x1800 (2026-06-30).
- [ ] Convert vendored app/ to a true git subtree (needs `sudo dnf install git-subtree`).

## WiFi / network polish
- [ ] **Bedtime schedules** for `NexusRobotics` + `mindsync` kids SSIDs (auto-off, e.g. 21:00–07:00) — via UniFi WiFi schedule or AdGuard client schedule
- [ ] **Managed switch** between U7 and pfSense — VLANs currently work over the unmanaged switch (tags pass), but a managed switch gives clean per-port VLANs and removes tagged frames from the flat L2
- [ ] **6 GHz/WiFi-7 for `mindsync`** — currently 2.4/5 GHz WPA2 for device compatibility; enable 6 GHz (WPA3) if all home devices support it
- [ ] **Guest SSID (`IndraJaal`)** — confirm a device lands on `192.168.40.x` and is isolated

## Security hygiene
- [ ] **Rotate AdGuard admin password** off the Proxmox root password (`cartoonnetwork`) — `http://192.168.10.13:3053`
- [ ] Review WiFi passwords that share a base word with infra creds
- [ ] Consider a dedicated UniFi local admin password (currently `apiadmin`)

## Docker services (host `192.168.10.13`)
- [ ] **gluetun VPN creds** — add `OPENVPN_USER`/`OPENVPN_PASSWORD` (or WireGuard) to `homelab/servarr` `.env`; unblocks `qbittorrent`, `nzbget`, `prowlarr` (stuck "created" behind gluetun)
- [ ] **ytdl-sub** — currently commented out in `homelab/servarr/compose.yaml`; uncomment + add `/data/youtube` + subscription config to enable
- [ ] Clean up: confirm no leftover/dead containers remain after the gluetun fix

## Homelab stability (Option A — planned 2026-07-15, not started)
- [ ] **`deploy/deploy-homelab.sh` bug**: `set -e` + `((failed++))` aborts the script on the first failed service instead of continuing. Use `failed=$((failed+1))`. (Verified reproducible.)
- [ ] **`ddns` never deploys**: in `SERVICES` map but missing from `services_order`, so `deploy-homelab.sh all` skips it
- [ ] **Dead entry**: `piholev6` → `Piholev6/` directory does not exist
- [ ] **Fake backup**: `create_backup()` dumps `docker compose config` (rendered YAML) — cannot restore anything. Replace with a running-image-digest + git-SHA manifest for a real rollback path.
- [ ] **Weak post-deploy check**: `docker compose ps | grep -q "Up"` passes if *any single* container is up. Verify all services.
- [ ] **Healthchecks missing** on traefik, homepage, jellyfin, monitoring, rustdesk (skip twingate — connector has no health endpoint)
- [ ] **No self-healing**: `restart: unless-stopped` doesn't catch hung-but-running containers. Extend `deunhealth` (already used in servarr) host-wide. Requires healthchecks first + host-wide docker.sock (blast-radius decision).
- [ ] **No alerting**: uptime-kuma is deployed but notifies nobody. Add ntfy to monitoring stack; kuma monitor/notification config is UI state, not codifiable in git.
- [ ] **Remote deploy**: `deploy/deploy-remote.sh` over Twingate. BLOCKED: no SSH key auth on `192.168.10.13` (tried `ts`/`dev`/`root`/`anand` — password only). Run `ssh-copy-id <user>@192.168.10.13` once.
- [ ] Deferred: GitOps layer (Komodo vs. systemd-timer reconcile) — decide after the above lands
- [ ] `:latest` on traefik/adguard/jellyfin/homepage/rustdesk/twingate — pin by digest (immich already does this; copy that pattern)

## Telisky (`192.168.50.x`)
- [ ] Migrate remaining telisky hosts onto igb3 if still needed: `.50` (llm), `.194` (rc500), `.236` (ai-team)
- [ ] Telisky web stays **Twingate-only** by design (ts-infra host firewall blocks direct LAN 80/443/2222)

## Reference
- Full topology/runbook documented separately (network diagram, IP reservations,
  firewall logic, DNS chain, gotchas). Key facts:
  - HOME `192.168.10.x` (AdGuard DNS) · NEXUS VLAN20 · ROBOTICS VLAN30 · GUEST VLAN40 · TELISKY `192.168.50.x`
  - LAN `192.168.1.x` = admin super-net; HOME/TELISKY isolated from it
  - AP `192.168.10.115` on local UniFi controller (`192.168.10.13:8443`)
