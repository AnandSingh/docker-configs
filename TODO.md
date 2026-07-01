# Homelab TODO

Open follow-ups from the 2026-06-22/23 network + WiFi build. None are blocking — the
core setup (pfSense 2-network + VLANs, Proxmox, docker hosts, DNS/ad-blocking, WiFi)
is live and verified.

## DNS / access (found 2026-06-23)
- [x] **AdGuard resolving `plexlab.site`** — FIXED 2026-06-30 (added AdGuard apex `plexlab.site → 192.168.10.13` + wildcard `*.plexlab.site → 192.168.10.13` A rewrites; all subdomains resolve on LAN) — Traefik on `.13:443` serves it (HTTP 200) and Cloudflare publicly points `plexlab.site → 192.168.10.13`, but AdGuard returns the name with NO IP, so HOME clients can't reach it. Likely a broken/missing AdGuard DNS rewrite or upstream resolution issue. Fix: add AdGuard rewrite `*.plexlab.site → 192.168.10.13`, or debug why unbound/AdGuard drops it.

## eink-dashboard (magic mirror)
- [x] **Phase 1 shipped** 2026-06-30 — server deployed at https://dash.plexlab.site (internal + Twingate), homelab/eink-dashboard stack, mock vision + Snoqualmie weather + quarter widget. Demo data.
- [ ] **Phase 2 — task capture without glasses** (own brainstorm): phone→Syncthing→inbox, or Telegram/WhatsApp bot via existing /bot, or web/PWA form.
- [ ] **Phase 3 — Pi + Boox 32"** physical display.
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

## Telisky (`192.168.50.x`)
- [ ] Migrate remaining telisky hosts onto igb3 if still needed: `.50` (llm), `.194` (rc500), `.236` (ai-team)
- [ ] Telisky web stays **Twingate-only** by design (ts-infra host firewall blocks direct LAN 80/443/2222)

## Reference
- Full topology/runbook documented separately (network diagram, IP reservations,
  firewall logic, DNS chain, gotchas). Key facts:
  - HOME `192.168.10.x` (AdGuard DNS) · NEXUS VLAN20 · ROBOTICS VLAN30 · GUEST VLAN40 · TELISKY `192.168.50.x`
  - LAN `192.168.1.x` = admin super-net; HOME/TELISKY isolated from it
  - AP `192.168.10.115` on local UniFi controller (`192.168.10.13:8443`)
