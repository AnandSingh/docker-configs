# VEX IQ Dev Environment — Design

**Date:** 2026-07-15
**Status:** Approved for planning
**Team:** Nexus Robotics Academy — VIQRC 2026–27 season, 6 students, VEX IQ 2nd gen
**Supersedes:** the FLL/Pybricks setup in `archive/teaching/` (teaching VM `192.168.10.29`, now decommissioned)

## Goal

Six students program the team robot in Python with **zero setup on their own machines**. Their
work is version-controlled automatically, without any student touching git.

## The hard constraint

The VEX VS Code extension **cannot flash a robot from a browser IDE**. This is settled by the
extension's own manifest (`VEXRobotics.vexcode` v0.8.2026020401):

```
main:    "./dist/extension.js"    # node entrypoint
browser:                          # ABSENT — no web extension entrypoint
deps:    serialport
native:  @serialport/bindings-cpp.node  (win32-x64, linux-x64, linux-arm64, ...)
```

No `browser` field means code-server loads it in the **server-side** extension host. It reaches
hardware via `serialport` native bindings, which open serial devices on the machine running that
host — the server, not the student's laptop. The student's brain is invisible to it.

This is why the old Pybricks setup worked and VEX won't: Pybricks shipped a `forceWebBluetooth`
mode that ran flashing in the browser webview (fed by the
`Permissions-Policy: bluetooth=(self)` middleware in
`archive/teaching/traefik/config/dynamic/bluetooth-middleware.yml`). VEX ships no browser
entrypoint at all. No amount of configuration changes this.

**Corollary that makes it a non-problem:** the team has *one robot*. Flashing is already
serialized — six students can never download at once. So we need six *editors* and *one*
flash-capable machine.

## Architecture

```
  6 students, any device, browser only
        |
        v
  code-server per student  (nihita.lab.nexuswarrior.site, ...)
   - VEX Python workspace image
   - GitDoc: auto-commit + auto-push on save (server-side)
        |
        v
  Forgejo: one repo per student  +  team-official repo
        |
        v  (git pull)
  Download station  — one machine, beside the robot
   - VS Code + VEX extension + Python + git
   - USB-C to the IQ brain
```

**Students:** open a URL, write Python, work auto-commits. They never see git, install nothing,
configure nothing.

**Flashing:** student walks to the station, pulls their file, hits Download, tests. They queue for
the robot exactly as they already do.

## Components

### 1. code-server stack (rebuild — not in repo)

Only the Traefik routes (`archive/teaching/traefik/config/dynamic/*-code-server.yml`) and
`archive/teaching/code-server/DESKTOP-VSCODE-GUIDE.md` survived. The compose that ran the five
instances lived on `.29` and is gone. Rebuild as a single compose with one service per student.

Prior port allocation, kept for continuity:

| Student | Host | Port |
|---|---|---|
| Farish | farish.lab.nexuswarrior.site | 8445 |
| Dhruv | dhruv.lab.nexuswarrior.site | 8446 |
| Gautham | gautham.lab.nexuswarrior.site | 8447 |
| Nihita | nihita.lab.nexuswarrior.site | 8448 |
| Anand (coach) | anand.lab.nexuswarrior.site | 8449 |

Team is 6 students; the roster above is 4 + coach. Two more services to add — names needed.

Each service: `restart: unless-stopped`, a healthcheck (per the homelab stability work in
`TODO.md`), password auth, and a per-student volume.

### 2. VEX Python workspace image

Base on `archive/teaching/coder/templates/fll-python/Dockerfile` (Ubuntu 22.04 + Python 3.11 +
dev tooling). Changes:

- **Drop** the FLL-era libraries: `robotframework*`, `pyserial`, jupyter/notebook, the data-science
  stack (`numpy`/`pandas`/`matplotlib`/`scipy`). None are reachable from an IQ brain and they bloat
  the image.
- **Keep** Python 3.11, `black`, git, shell tooling.
- **Add** VEX Python stubs for IntelliSense so students get completion for `vex.*` while editing.
  The VEX extension itself is *not* installed here — it cannot flash from this host, and shipping
  it would imply otherwise.
- Pre-seed `settings.json` with GitDoc enabled.

### 3. Autosync — GitDoc

`vsls-contrib.gitdoc`, installed and pre-configured in the image. Auto-commits and auto-pushes on
save. Running server-side is an advantage: no git config, no SSH keys, no credentials on any
student machine.

Settings to pin (defaults are wrong for this use):

- `gitdoc.enabled: true`
- `gitdoc.autoCommitDelay`: 30000 default → lower (~5000)
- `gitdoc.autoPush`: `onCommit` (default) — keep
- `gitdoc.filePattern`: `**/*.py`

### 4. Forgejo — one repo per student

Separate repos, not one shared repo. GitDoc pushes on every save; six students auto-pushing to one
branch would be a non-fast-forward pileup all practice. Isolated repos make that structurally
impossible.

- `vex-iq/<student>` — one per student, student's own Forgejo account, token scoped to that repo only
- `vex-iq/team-official` — the code that goes to competition; Programmer + coach, reviewed

Per-student Forgejo accounts are also the "each kid logs in" requirement, landing on the right
system.

### 5. Download station

One machine beside the robot, plugged into the brain by USB-C. Configured once, ever.

- VS Code + `VEXRobotics.vexcode` + `ms-python.python` + git
- All student repos cloned; a `pull-all` script
- Student opens their file, hits Download

A mini PC is a good fit. Note Python on IQ is **single-file download only** per VEX docs — keep
project structure flat.

## Open decisions

1. **Host.** `.29` is gone. Rebuild a VM on the robotics Proxmox, or run on the homelab `.13`?
   `.13` already has Traefik, AdGuard, and the deploy script; a separate VM keeps kid-facing
   services off the household stack.
2. **Reachability.** The old setup resolved `*.lab.nexuswarrior.site` to a LAN IP (`192.168.10.29`)
   — LAN-only. **Do students code from home?** If yes this needs public exposure (real certs,
   real authn, exposed to the internet) or Twingate accounts for six kids, which is a poor fit.
   If practice-only, LAN is fine and much safer. This decision gates the security model.
3. **Two more students.** Roster has 4 + coach; team is 6. Need names.
4. **Station hardware.** New mini PC, or an existing laptop?

## Risks

- **Students cannot flash from their seat.** They edit at their desk, walk to the station to test.
  This is inherent (one robot) but is a real change in feel from the FLL setup, where Pybricks
  flashed from the browser. Set expectations with the kids.
- **GitDoc noise.** Every save becomes a commit. Fine for students; ugly history. `team-official`
  should use normal reviewed commits, not GitDoc.
- **Exposing kid-facing services** if decision 2 lands on "from home". Six student accounts on an
  internet-exposed service is a real security surface, on the same host as the household network.
- **Blocks is not supported by this design.** If any student needs VEXcode Blocks, they use
  codeiq.vex.com directly — Blocks does not exist in VS Code.
- **`.29`'s config is lost.** The rebuild is from the Traefik routes and the doc, not from the
  running system. Expect gaps.

## Out of scope

- Homelab stability work (Option A) — tracked in `TODO.md`
- Password rotation — tracked in `TODO.md`
- Team portal / homepage — worthwhile, separate
- Engineering notebook tooling

## Validation

- `docker compose config` on the new stack
- One student's flow end-to-end: open URL → edit → confirm commit lands in Forgejo → pull at
  station → Download → robot runs
- Confirm the station flashes over USB-C **and** test whether Bluetooth works from the station
  (VEX docs indicate Gen 2 Bluetooth is supported; `kb.vex.com` blocks automated fetches, so this
  is unverified and needs a hardware test). Controller-tether is the fallback and is
  competition-realistic.
