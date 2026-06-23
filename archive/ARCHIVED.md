# Archived: Teaching stack

**Archived:** 2026-06-22

## Why

The teaching stack was deployed to a VM at **192.168.10.29**, which lived on the
**`robotics`** Proxmox node (cluster `cluster1`, nodeid 2, 192.168.10.20). That
node was decommissioned and removed from the cluster on 2026-06-22 (it would no
longer boot and was no longer needed). With the host gone, the teaching
deployment target no longer exists, so this stack is archived rather than
actively deployed.

## What's here

Moved under `archive/` (kept for reference, not deployed):

- `archive/teaching/` — full teaching stack (coder, traefik, homepage, rustdesk, code-server, templates, scripts)
- `archive/workflows/deploy-teaching.yml` — CI deploy workflow (moved out of `.github/workflows/` so it no longer runs)
- `archive/deploy/deploy-teaching.sh`, `archive/deploy/TEACHING-VM-SECRETS.md`
- `archive/MANUAL-DEPLOYMENT-GUIDE.md`, `archive/GITHUB-SECRETS-SETUP.md`
- `archive/scripts/diagnose-coder.sh`, `archive/scripts/test-remote.sh`

## To restore

Provision a new teaching host, move these paths back to their original
locations (`teaching/`, `.github/workflows/deploy-teaching.yml`, etc.), and
update the deploy host/IP (was `192.168.10.29`, user `dev`).
