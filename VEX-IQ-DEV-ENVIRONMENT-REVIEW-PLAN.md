# VEX IQ Dev Environment — Implementation and Test Review Plan

**Status:** Draft for owner review; do not continue installation or deployment until approved.

**Target:** Proxmox VM `100` (`nexus-robotics-lab`) serving six student code-server workspaces
and one coach workspace at `*.nexusroboticslab.org` and `*.nexusrobo.org`.

**Access model:** HOME LAN and Twingate only. No WAN port-forwarding or Cloudflare proxy ingress.
Cloudflare is used only for DNS-01 certificate validation.

## 1. Decisions to approve

| Decision | Recommendation | Why |
|---|---|---|
| VM address | Prefer `192.168.10.29` only after removing or updating the old DHCP reservation | `.29` was the old teaching VM's HOME-network address; it currently does not answer ping, but the former reservation may still map it to the old VM's MAC |
| Guest OS | Ubuntu Server 24.04 LTS | Familiar maintenance path and long support window |
| VM resources | 4 vCPU, 8 GB RAM, 60 GB local disk; balloon floor 4 GB | Enough for seven light IDE sessions; local disk holds OS, images, and logs |
| Public names | `nexusroboticslab.org` (canonical) and `nexusrobo.org` (short alias), with wildcards | Keeps the robotics system separate from the academy website and provides a convenient short name |
| TrueNAS layout | **Implemented fallback:** isolated `robotics-lab` directory inside the proven existing Docker export | Reuses the former teaching VM's working NFS path without requiring TrueNAS administrative access; a dedicated restricted export remains a future hardening improvement |
| Persistent data | NFS only for `/opt/robotics-lab/code-server/data`; Docker data and Traefik stay local | Avoids Docker overlay/database behavior on NFS while protecting student source files |
| VM backup | Back up VM `100` to PBS; exclude or document the NFS-mounted student data as separately protected | Avoids pretending that a VM backup contains NFS data |
| Source control | **Approved for a later phase:** a new local Forgejo dedicated to Nexus Robotics | Keeps this project independent of Telisky; GitHub can remain an optional off-site mirror/export |
| Git authentication | One unique repository-scoped deploy key per workspace | Avoids sharing a personal/admin token and limits a leaked key to one repository |
| Initial exposure | **Approved:** HOME LAN and Twingate only | Password-only code-server is not the desired public-internet security boundary |
| Later remote access | Deferred Cloudflare Tunnel + Access phase with an allowlist and Google identity | Gives children browser access without VPN software while keeping the origin private; requires a separate security review before activation |

Approval of this table is Gate A. Any changed choice must be reflected in the implementation plan
before work resumes.

## 2. Current state

### Already created and installed

- Proxmox VM `100`, named `nexus-robotics-lab`
- 4 host CPU cores, 8 GB RAM, 60 GB `local-lvm` disk
- VirtIO NIC on `vmbr0`, MAC `BC:24:11:AD:31:DD`
- Ubuntu Server 24.04 LTS installed from the official cloud image at `192.168.10.29`
- Deployment user `dev` with key-only SSH and passwordless sudo
- Root SSH and SSH password authentication disabled
- QEMU guest agent, NFS client, Git, curl, rsync, and unattended upgrades installed
- Boot-on-start with startup order 4; TrueNAS is startup order 1

### Already committed on the feature branch

- Public/secret-safe environment template and ignore rules
- `vex-workspace:1.0` Dockerfile and code-server settings
- Compose definition for `cs-1` through `cs-6` and `cs-coach`

### Not yet done

- Ubuntu installation or guest hardening
- Fixed IP/DHCP reservation
- Dedicated TrueNAS dataset/export, snapshot policy, and quota
- Docker/NFS host setup
- Traefik files and Cloudflare token
- Deployment script
- New local Nexus Robotics Forgejo, repositories, backups, and per-repository deploy keys
- Deferred public access through Cloudflare Tunnel and Access
- Download station documentation and validation
- Monitoring, backup, restore, failure, and load tests

## 3. Implementation phases

Each phase ends at a gate. Do not proceed through a failed gate.

### Phase 0 — Security prerequisites

1. Rotate the previously exposed Proxmox root password.
2. Restore the two pre-existing RSA public keys to `/root/.ssh/authorized_keys` if their clients
   remain authorized; adding the workstation key accidentally replaced them.
3. Confirm the Proxmox web UI is not WAN-exposed.
4. Create a non-root Proxmox automation identity for future operations; remove routine root SSH
   dependence after bootstrap.

**Gate B:** New root password works, required SSH keys are accounted for, and no unexpected WAN
listener or forwarding rule exposes Proxmox.

### Phase 1 — Install and harden Ubuntu

1. Install Ubuntu Server on VM `100` with hostname `nexus-robotics-lab`.
2. Create deployment user `dev`; install the workstation Ed25519 key.
3. Reserve the approved address in the network controller using MAC
   `BC:24:11:AD:31:DD`; do not configure two competing static sources.
4. Install `qemu-guest-agent`, `openssh-server`, `nfs-common`, `curl`, `rsync`, `git`, and
   unattended security updates.
5. Disable SSH password authentication and root SSH login after key access is proven.
6. Enable UFW: allow SSH from the admin/HOME networks and allow 80/443 from HOME and Twingate
   source ranges only. Deny other inbound traffic by default.
7. Install Docker Engine from Docker's official Ubuntu repository and the Compose plugin. Pin the
   repository channel; do not use the convenience installer script.
8. Set timezone and time synchronization; verify NTP before ACME.

**Gate C:** Reboot succeeds; VM returns at the reserved IP; SSH key, guest agent, DNS, NTP,
package updates, Docker, Compose, and firewall checks all pass.

### Phase 2 — TrueNAS storage and boot safety

1. Reuse `192.168.10.15:/mnt/nas-pool/nfs-share/docker`, the export proven by the former teaching
   VM, and create its isolated `robotics-lab/code-server-data` directory.
2. Retain the proven hard-mount options and document a future TrueNAS task to add a dataset quota,
   explicit snapshot policy, and an export restricted to `192.168.10.29`.
3. Hard-mount the export at `/mnt/truenas-docker`, then bind only its robotics-lab data directory
   to `/opt/robotics-lab/code-server/data` after verifying the real NFS source.
4. Add systemd mount dependencies so the robotics-lab Compose unit cannot start unless both the NFS
   mount and bind mount are real mounts. A plain local directory must never be accepted as a
   fallback.
5. Keep `/var/lib/docker`, `/opt/robotics-lab/traefik`, secrets, and logs on the VM's local disk.

**Gate D:** UID 1000 can create, edit, rename, and delete a file; mount identity is verified with
`findmnt`; a TrueNAS snapshot contains the test file; stopping NFS prevents workspace startup;
restoring NFS allows a clean recovery without file loss.

### Phase 3 — Review and complete repository artifacts

1. Reconcile completed checkboxes in `VEX-IQ-DEV-ENVIRONMENT-PLAN.md` with git history.
2. Review and build the existing workspace image on VM `100`.
3. Verify exact extension versions, settings, Python, curl, Git, and non-root UID.
4. Review Compose for:
   - seven distinct volumes and router rules;
   - no published code-server host ports;
   - explicit `traefik.docker.network=proxy` labels;
   - resource limits appropriate for seven concurrent sessions;
   - read-only or capability restrictions where code-server permits them;
   - log rotation so local disk cannot fill indefinitely.
5. Add a host preflight script that checks NFS mount identity, free disk, required secrets,
   Docker network, DNS, and ports before changing containers.
6. Ensure deployment is repeatable and does not overwrite `.env`, student data, or `acme.json`.

**Gate E:** Static validation passes, the image builds from scratch, seven service definitions
render with secrets present, rendering fails safely with secrets absent, and the repo contains no
student names or secret values.

### Phase 4 — Dedicated Traefik and TLS

1. Add the pinned Traefik Compose and static configuration under `robotics-lab/traefik`.
2. Create a least-privilege Cloudflare API token scoped only to DNS edits for
   `nexusroboticslab.org` and `nexusrobo.org`; store it only in the VM's root-readable `.env`.
3. Create the external `proxy` Docker network.
4. Persist `acme.json` locally with mode `0600` and include it in VM backups.
5. Prefer a restricted Docker socket proxy or explicitly accept and document direct read-only
   socket exposure; a read-only socket still reveals Docker metadata.
6. Add AdGuard wildcard rewrites for `*.nexusroboticslab.org` and `*.nexusrobo.org` to the robotics-lab VM IP. Do not add
   a public A/AAAA record pointing to an RFC1918 address.

**Gate F:** Traefik is healthy, the wildcard certificate is valid and renewably issued via
DNS-01, LAN and Twingate clients resolve the private address, HTTP redirects to HTTPS, and an
unknown hostname receives no application route.

### Phase 5 — Deploy workspaces

1. Generate seven unique high-entropy code-server passwords outside the tracked repo.
2. Create seven NFS directories owned by UID/GID `1000:1000`.
3. Deploy one canary workspace first and validate it before scaling to seven.
4. Deploy the remaining workspaces through the reviewed deployment script.
5. Add a systemd Compose unit ordered after network-online and the verified NFS mounts.

**Gate G:** All seven containers are healthy; each URL reaches only its intended workspace;
passwords are unique; each volume is writable; containers return after a VM reboot; no workspace
port is directly reachable on the VM IP.

### Phase 6 — Local Nexus Robotics Forgejo

This is a later phase after the LAN/Twingate code-server rollout is stable. It is a new local
service and does not use or depend on any Telisky Forgejo instance.

1. Add a pinned Forgejo container at `git.nexusroboticslab.org`, reachable only from HOME and
   Twingate. Do not publish it through Cloudflare Tunnel during the initial rollout.
2. For this small deployment, use Forgejo's supported SQLite configuration on the VM's local
   disk to minimize maintenance. Keep live database and repository storage off NFS.
3. Persist Forgejo under `/opt/robotics-lab/forgejo`; protect secrets with mode `0600`; add health,
   restart, resource-limit, and log-rotation configuration.
4. Create the owner account without enabling unrestricted public registration. Create seven
   private workspace repositories plus private `team-official`.
5. Schedule an application-consistent `forgejo dump` to the dedicated TrueNAS robotics-lab dataset,
   and include local Forgejo state in PBS VM backups. Test both restore paths.
6. Optionally mirror only reviewed repositories to GitHub for off-site resilience or publication;
   GitHub is not required for student autosync.

**Gate H:** Forgejo is healthy after reboot, registration is closed, repositories are private,
backup and restore are proven, LAN/Twingate access works, WAN access fails, and no Telisky service
or credential is involved.

### Phase 7 — Forgejo autosync

1. Generate a unique Ed25519 deploy key pair for each workspace. Add only its public key to the
   corresponding Forgejo repository with write access. Never reuse a key.
2. Store private keys on the VM's local disk under `/opt/robotics-lab/secrets/git/`, owned by root and
   readable only by the intended container UID through a read-only bind mount. Do not store keys
   in the tracked repo, NFS student directories, shell history, logs, or container images.
3. Pin the local Forgejo SSH host key in a reviewed `known_hosts` file. Do not disable host-key
   checking.
4. Initialize one canary repository, prove GitDoc commit and push, then repeat for all seven.
5. Define deploy-key rotation, repository archival, and student departure procedures.

**Gate I:** A saved Python change auto-commits and pushes from every workspace; one student's
deploy key cannot read or write another student's repository; a removed key fails without
affecting other workspaces; no private key appears in git output, NFS snapshots, or images.

### Phase 8 — Download station

1. Document and configure VS Code, VEX extension, Python, Git, and repository pull workflow.
2. Keep VEX projects flat because IQ Python download is single-file.
3. Test USB download first; test Bluetooth separately; document the controller-tether fallback.
4. Define how reviewed work moves into `team-official`.

**Gate J:** The station pulls a student revision, downloads it to the physical IQ brain, runs the
expected program, and can return to a known-good revision.

### Phase 9 — Operations and handoff

1. Add all seven HTTPS endpoints plus VM, NFS, and disk-capacity monitoring to Uptime Kuma.
2. Configure notifications rather than dashboard-only monitoring.
3. Configure PBS backups of VM `100` and TrueNAS snapshots of robotics-lab data.
4. Write restore, credential rotation, update, shutdown, and start-of-practice runbooks.
5. Record image pins and a monthly patch window. Test updates on one canary workspace first.

**Gate K:** A person other than the implementer can follow the runbook to check status, restart
the stack, restore one deleted student file, and identify where each secret is stored.

### Deferred Phase 10 — Child-friendly remote access without VPN

This phase is explicitly outside the initial rollout. Re-open it only after LAN/Twingate operation
is stable and the owner approves a new threat model.

1. Run `cloudflared` as a separate, pinned container or system service that makes outbound-only
   connections to Cloudflare; do not forward 80/443 on the home router.
2. Create a Cloudflare Access self-hosted application for the wildcard or explicitly enumerated
   student hostnames before publishing the tunnel route. Access applications deny by default.
3. Configure Google as the identity provider and allow only explicitly approved child/parent
   email addresses. Do not use an unrestricted email-domain rule or shared login.
4. Keep code-server's own unique password enabled as defense in depth until the complete login,
   logout, WebSocket, session-expiry, and account-recovery flow is tested.
5. Restrict the tunnel route to Traefik only. Do not publish SSH, Proxmox, TrueNAS, Docker, or the
   Traefik dashboard.
6. Add rate limiting, access logging with an agreed retention period, session duration limits,
   emergency revocation, and a parent/guardian account lifecycle procedure.

**Deferred Gate L:** An allowed Google account works from an external network with code-server
WebSockets and saves intact; an unlisted account is denied; origin ports remain unreachable from
the internet; removing an email from the policy terminates or blocks access as documented.

## 4. Test plan

Record date, operator, command or action, expected result, actual result, and evidence for every
test. Redact names, passwords, tokens, cookies, and repository credentials.

### Infrastructure tests

| ID | Test | Pass condition |
|---|---|---|
| INF-01 | Cold boot Proxmox guests | TrueNAS becomes ready before the robotics-lab stack; all services recover without manual intervention |
| INF-02 | Reboot VM `100` | Fixed IP, SSH, mounts, Docker, Traefik, and seven workspaces return |
| INF-03 | Guest agent | Proxmox reports the guest IP and clean shutdown works |
| INF-04 | Resource headroom | Seven active sessions do not swap heavily; local disk and NFS remain below agreed thresholds |
| INF-05 | Time/DNS | NTP synchronized; public Cloudflare DNS and internal AdGuard answers are correct |

### Storage and recovery tests

| ID | Test | Pass condition |
|---|---|---|
| STO-01 | UID test in all seven containers | Create, save, rename, and delete succeeds as UID 1000 |
| STO-02 | NFS outage before boot | Workspaces fail closed; no local fallback directories receive student data |
| STO-03 | NFS interruption during editing | Failure is visible; after recovery, files are consistent and containers recover in a controlled manner |
| STO-04 | Snapshot restore | A deleted test file is restored to an alternate path, verified, then deliberately copied back |
| STO-05 | VM restore | Restored VM boots with secrets/ACME state; NFS data is not duplicated or overwritten |
| STO-06 | Capacity guard | Warning fires before either local disk or robotics-lab dataset reaches 80% |

### Network and security tests

| ID | Test | Pass condition |
|---|---|---|
| SEC-01 | WAN reachability | Ports 22, 80, 443, and 8006 are not reachable from the public internet |
| SEC-02 | LAN/Twingate reachability | Authorized clients resolve and connect over HTTPS |
| SEC-03 | Port scan VM | Only approved ports are open from each tested network segment |
| SEC-04 | TLS | Trusted wildcard certificate, correct SANs, no default certificate, HTTP redirects to HTTPS |
| SEC-05 | Workspace isolation | Student A cannot browse Student B's files, repository, container, or hostname session |
| SEC-06 | Secret scan | No `.env`, password, Cloudflare token, Forgejo private deploy key, or real student name is tracked or logged |
| SEC-07 | NFS restriction | Only the robotics-lab VM can mount the robotics-lab dataset |
| SEC-08 | Authentication abuse | Repeated bad logins are logged and rate-limited or otherwise mitigated |

### Application tests

| ID | Test | Pass condition |
|---|---|---|
| APP-01 | Seven healthchecks | All containers remain healthy for at least 15 minutes |
| APP-02 | Browser matrix | Current Chrome/Chromium and the actual student devices can log in, edit, and save |
| APP-03 | Python tooling | Syntax checking and Ruff work; the documented lack of `vex.*` autocomplete is understood |
| APP-04 | Autosync latency | A saved `.py` change appears in Forgejo within the agreed target, initially 15 seconds |
| APP-05 | Concurrent use | Seven simultaneous edit/save sessions remain responsive and produce isolated commits |
| APP-06 | Restart during unsaved work | Expected browser/editor behavior is documented; committed files remain intact |
| APP-07 | Wrong/missing secret | Compose refuses to render or start rather than launching unauthenticated |

### Robot workflow tests

| ID | Test | Pass condition |
|---|---|---|
| ROB-01 | Pull student code | Station retrieves the exact Forgejo revision selected by the coach |
| ROB-02 | USB flash | VEX extension downloads and runs a known test program on the IQ brain |
| ROB-03 | Bluetooth/fallback | Bluetooth result is recorded; controller/USB fallback is proven |
| ROB-04 | Known-good rollback | Station checks out and flashes a prior working revision |

## 5. Rollback plan

- **Before first deployment:** take a PBS backup or Proxmox snapshot of the clean, hardened VM.
- **Before Compose changes:** save the running image digests, git SHA, rendered Compose hashes,
  and a protected copy of `acme.json`; never call rendered YAML a data backup.
- **Application rollback:** redeploy the prior git SHA and prior pinned image digest. Do not delete
  NFS directories during rollback.
- **VM rollback:** stop the robotics-lab Compose stack, restore VM state from PBS, verify NFS mount
  identity, then start one canary before all seven.
- **Student-file rollback:** restore from a TrueNAS snapshot to an alternate directory first;
  compare and copy only the intended file. Never roll back the entire shared dataset to recover a
  single student's file.
- **Emergency shutdown:** stop the workspace Compose project, then Traefik. Leave NFS data and
  snapshots untouched.

## 6. Final rollout gate

The base environment is ready for students when Gates A–G and K pass. Forgejo integration is
ready when Gates H–I pass; the download-station workflow requires Gate J. In all cases:

- all security prerequisites and credential rotations are complete;
- all seven workspaces pass health, write, isolation, and autosync tests;
- cold-boot, NFS outage, snapshot restore, and VM restore tests have evidence;
- the physical station flashes and rolls back the robot successfully;
- monitoring alerts reach a real recipient;
- the repository is clean and contains no secrets or student identities;
- the owner signs off on the completed test record.
