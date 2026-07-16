# VEX IQ Dev Environment — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Six students program the VEX IQ robot in Python from a browser with zero setup on their machines, with work auto-committed to Forgejo, and one download station beside the robot for flashing.

**Architecture:** A new Proxmox VM runs Traefik plus one code-server container per student. Students edit in the browser; GitDoc auto-commits and pushes server-side to a per-student Forgejo repo. Flashing happens at a single station machine running real VS Code + the VEX extension, because the VEX extension has no browser entrypoint and reaches hardware via `serialport` native bindings on whatever host runs the extension.

**Tech Stack:** Docker Compose, Traefik v3 (Cloudflare DNS-01), code-server, Open VSX extensions, Forgejo, Debian 12 VM on Proxmox.

**Design doc:** `docs/VEX-IQ-DEV-ENVIRONMENT-DESIGN.md`

## Global Constraints

- **Repo `github.com/AnandSingh/docker-configs` is PUBLIC.** No student names, no credentials, no WiFi details in tracked files. Student names live only in `teaching/code-server/.env` (gitignored).
- **Stack path is `teaching/`** — reuses existing `.gitignore` rules (`teaching/traefik/.env`, `teaching/coder/.env`, `teaching/traefik/config/dynamic/*-code-server.yml`).
- **LAN-only.** No port-forwarding, no public ingress. TLS via Cloudflare DNS-01, which issues real certs without exposing anything.
- **Pin every image by tag.** No `:latest` (see `TODO.md` — this bit the homelab).
- **code-server installs extensions from Open VSX, not the MS Marketplace.** Verified available: `vsls-contrib.gitdoc` 0.2.3, `ms-python.python` 2026.4.0, `charliermarsh.ruff` 2026.60.0.
- **The VEX extension is never installed in code-server.** It cannot flash from there; shipping it would imply otherwise.
- Every service: pinned image, `restart: unless-stopped`, and a healthcheck.

## Known limitation (accept, do not fix in this plan)

No official VEX Python stubs exist. In code-server students get Python syntax + linting but **no `vex.*` autocomplete**. Authoritative completion exists only at the station. If this hurts in practice, a hand-written `vex.pyi` is a follow-up, not part of this build.

## Where validation runs

**There is no Docker on the workstation** (`command -v docker` → not found). Nothing in this
plan can be built or tested locally. Every `docker` command below runs **on the teaching VM over
SSH**. Only `git`-level checks (Task 1) and file authoring happen locally.

Practically: author files locally, commit, run Task 5's deploy script to push them to the VM, and
run the verification commands there. Do not mark a build/verify step done from the workstation —
it cannot have run.

## Prerequisite (manual, not an agent task)

- [ ] **VM created on Proxmox.** Debian 12, 4 vCPU / 8 GB RAM / 60 GB disk (7 code-server containers), static IP on the HOME subnet, docker + docker compose installed, SSH key access from the workstation. **Record the IP — every task below needs it as `TEACHING_VM_IP`.**
- [ ] **Proxmox root password rotated** (`TODO.md`) — it was public for ~3 weeks.

---

### Task 1: Scaffold `teaching/` and prove names stay private

**Files:**
- Create: `teaching/code-server/.env.example`
- Create: `teaching/.gitignore`
- Verify: root `.gitignore` already covers `teaching/traefik/.env`

**Interfaces:**
- Produces: `LAB_DOMAIN`, `STUDENT_1_NAME`…`STUDENT_6_NAME`, `COACH_NAME`, `STUDENT_1_PASSWORD`…`STUDENT_6_PASSWORD`, `COACH_PASSWORD` — consumed by Tasks 3 and 4. No Forgejo variable: remotes are set per-workspace in Task 6, each with its own scoped token.

- [ ] **Step 1: Create `teaching/code-server/.env.example`**

```bash
# Student workspace identities. Real names go in .env (gitignored) — never here.
# This repo is PUBLIC.
LAB_DOMAIN=lab.nexuswarrior.site

STUDENT_1_NAME=student-1
STUDENT_2_NAME=student-2
STUDENT_3_NAME=student-3
STUDENT_4_NAME=student-4
STUDENT_5_NAME=student-5
STUDENT_6_NAME=student-6
COACH_NAME=coach

# One password per workspace. Generate with: openssl rand -base64 18
STUDENT_1_PASSWORD=
STUDENT_2_PASSWORD=
STUDENT_3_PASSWORD=
STUDENT_4_PASSWORD=
STUDENT_5_PASSWORD=
STUDENT_6_PASSWORD=
COACH_PASSWORD=
```

Forgejo remotes are set per-workspace in Task 6 (each carries its own scoped token), so no
Forgejo variable belongs here.

- [ ] **Step 2: Create `teaching/.gitignore`**

```gitignore
# Real student names, passwords, and workspace data never enter this public repo
code-server/.env
code-server/data/
traefik/.env
traefik/config/acme.json
```

- [ ] **Step 3: Verify the ignore rules actually hold**

Run:
```bash
cd /home/ts/wrk/docker-configs
mkdir -p teaching/code-server
printf 'STUDENT_1_NAME=realkid\n' > teaching/code-server/.env
git check-ignore -v teaching/code-server/.env
```
Expected: a line naming the ignoring rule (non-empty output, exit 0). If it prints nothing, the rule is wrong — fix before continuing.

- [ ] **Step 4: Confirm the test file is untracked, then remove it**

Run:
```bash
git status --short teaching/code-server/.env   # expect: NO output
rm teaching/code-server/.env
```
Expected: no output from `git status` — the file is invisible to git.

- [ ] **Step 5: Commit**

```bash
git add teaching/.gitignore teaching/code-server/.env.example
git commit -m "teaching: scaffold code-server env template, keep names private"
```

---

### Task 2: VEX Python workspace image

**Files:**
- Create: `teaching/code-server/Dockerfile`
- Create: `teaching/code-server/settings.json`

**Interfaces:**
- Consumes: nothing.
- Produces: image `vex-workspace:1.0`, consumed by Task 3. Workspace dir inside container: `/home/coder/robot`.

- [ ] **Step 1: Create `teaching/code-server/Dockerfile`**

```dockerfile
FROM codercom/code-server:4.128.0

USER root

# curl is required by the compose healthcheck in Task 3 — do not drop it.
RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv git ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

USER coder

# Extensions come from Open VSX — code-server cannot use the MS Marketplace.
RUN code-server --install-extension ms-python.python@2026.4.0 \
 && code-server --install-extension charliermarsh.ruff@2026.60.0 \
 && code-server --install-extension vsls-contrib.gitdoc@0.2.3

COPY --chown=coder:coder settings.json /home/coder/.local/share/code-server/User/settings.json

RUN mkdir -p /home/coder/robot
WORKDIR /home/coder/robot
```

- [ ] **Step 2: Create `teaching/code-server/settings.json`**

GitDoc defaults are wrong for this use: 30s delay is too slow for a practice session.

```json
{
  "gitdoc.enabled": true,
  "gitdoc.autoCommitDelay": 5000,
  "gitdoc.autoPush": "onCommit",
  "gitdoc.filePattern": "**/*.py",
  "gitdoc.commitMessageFormat": "'auto: 'lll",
  "editor.fontSize": 15,
  "editor.minimap.enabled": false,
  "workbench.startupEditor": "readme",
  "python.defaultInterpreterPath": "/usr/bin/python3"
}
```

- [ ] **Step 3: Copy to the VM and build there** (no Docker locally)

```bash
export TEACHING_VM=dev@<TEACHING_VM_IP>
ssh "$TEACHING_VM" 'mkdir -p /opt/teaching/code-server'
scp teaching/code-server/Dockerfile teaching/code-server/settings.json "$TEACHING_VM:/opt/teaching/code-server/"
ssh "$TEACHING_VM" 'cd /opt/teaching/code-server && docker build -t vex-workspace:1.0 .'
```
Expected: `naming to docker.io/library/vex-workspace:1.0 done`. A failure on `--install-extension` means an Open VSX pin is stale — check `curl -s https://open-vsx.org/api/vsls-contrib/gitdoc | grep version` and update the Dockerfile.

- [ ] **Step 4: Verify all three extensions actually installed**

```bash
ssh "$TEACHING_VM" 'docker run --rm vex-workspace:1.0 code-server --list-extensions'
```
Expected exactly:
```
charliermarsh.ruff
ms-python.python
vsls-contrib.gitdoc
```
If GitDoc is missing, the whole autosync premise fails — stop and fix.

- [ ] **Step 5: Verify GitDoc settings landed and curl exists**

```bash
ssh "$TEACHING_VM" 'docker run --rm vex-workspace:1.0 cat /home/coder/.local/share/code-server/User/settings.json'
ssh "$TEACHING_VM" 'docker run --rm --entrypoint sh vex-workspace:1.0 -c "command -v curl"'
```
Expected: JSON containing `"gitdoc.enabled": true` and `"gitdoc.autoCommitDelay": 5000`; then `/usr/bin/curl`. Without curl the Task 3 healthcheck silently fails forever.

- [ ] **Step 6: Commit**

```bash
git add teaching/code-server/Dockerfile teaching/code-server/settings.json
git commit -m "teaching: VEX python workspace image with gitdoc autosync"
```

---

### Task 3: code-server compose — 6 students + coach

**Files:**
- Create: `teaching/code-server/compose.yaml`

**Interfaces:**
- Consumes: `vex-workspace:1.0` (Task 2), `.env` vars (Task 1).
- Produces: containers `cs-1`..`cs-6`, `cs-coach` on the `proxy` network, each serving port 8080 internally. No host ports published — Traefik reaches them over the docker network.

- [ ] **Step 1: Create `teaching/code-server/compose.yaml`**

Names come from `.env` so the public repo never sees them. Seven near-identical services — repeated in full deliberately; compose has no loop.

```yaml
name: code-server

x-workspace: &workspace
  image: vex-workspace:1.0
  restart: unless-stopped
  networks: [proxy]
  environment:
    DOCKER_USER: coder
  healthcheck:
    test: ["CMD", "curl", "-fsS", "http://localhost:8080/healthz"]
    interval: 30s
    timeout: 5s
    retries: 3
    start_period: 20s

services:
  cs-1:
    <<: *workspace
    container_name: cs-1
    environment:
      PASSWORD: ${STUDENT_1_PASSWORD:?set in .env}
    volumes:
      - ./data/${STUDENT_1_NAME}:/home/coder/robot
    labels:
      - traefik.enable=true
      - traefik.http.routers.cs-1.rule=Host(`${STUDENT_1_NAME}.${LAB_DOMAIN}`)
      - traefik.http.routers.cs-1.entrypoints=websecure
      - traefik.http.routers.cs-1.tls.certresolver=letsencrypt
      - traefik.http.services.cs-1.loadbalancer.server.port=8080

  cs-2:
    <<: *workspace
    container_name: cs-2
    environment:
      PASSWORD: ${STUDENT_2_PASSWORD:?set in .env}
    volumes:
      - ./data/${STUDENT_2_NAME}:/home/coder/robot
    labels:
      - traefik.enable=true
      - traefik.http.routers.cs-2.rule=Host(`${STUDENT_2_NAME}.${LAB_DOMAIN}`)
      - traefik.http.routers.cs-2.entrypoints=websecure
      - traefik.http.routers.cs-2.tls.certresolver=letsencrypt
      - traefik.http.services.cs-2.loadbalancer.server.port=8080

  cs-3:
    <<: *workspace
    container_name: cs-3
    environment:
      PASSWORD: ${STUDENT_3_PASSWORD:?set in .env}
    volumes:
      - ./data/${STUDENT_3_NAME}:/home/coder/robot
    labels:
      - traefik.enable=true
      - traefik.http.routers.cs-3.rule=Host(`${STUDENT_3_NAME}.${LAB_DOMAIN}`)
      - traefik.http.routers.cs-3.entrypoints=websecure
      - traefik.http.routers.cs-3.tls.certresolver=letsencrypt
      - traefik.http.services.cs-3.loadbalancer.server.port=8080

  cs-4:
    <<: *workspace
    container_name: cs-4
    environment:
      PASSWORD: ${STUDENT_4_PASSWORD:?set in .env}
    volumes:
      - ./data/${STUDENT_4_NAME}:/home/coder/robot
    labels:
      - traefik.enable=true
      - traefik.http.routers.cs-4.rule=Host(`${STUDENT_4_NAME}.${LAB_DOMAIN}`)
      - traefik.http.routers.cs-4.entrypoints=websecure
      - traefik.http.routers.cs-4.tls.certresolver=letsencrypt
      - traefik.http.services.cs-4.loadbalancer.server.port=8080

  cs-5:
    <<: *workspace
    container_name: cs-5
    environment:
      PASSWORD: ${STUDENT_5_PASSWORD:?set in .env}
    volumes:
      - ./data/${STUDENT_5_NAME}:/home/coder/robot
    labels:
      - traefik.enable=true
      - traefik.http.routers.cs-5.rule=Host(`${STUDENT_5_NAME}.${LAB_DOMAIN}`)
      - traefik.http.routers.cs-5.entrypoints=websecure
      - traefik.http.routers.cs-5.tls.certresolver=letsencrypt
      - traefik.http.services.cs-5.loadbalancer.server.port=8080

  cs-6:
    <<: *workspace
    container_name: cs-6
    environment:
      PASSWORD: ${STUDENT_6_PASSWORD:?set in .env}
    volumes:
      - ./data/${STUDENT_6_NAME}:/home/coder/robot
    labels:
      - traefik.enable=true
      - traefik.http.routers.cs-6.rule=Host(`${STUDENT_6_NAME}.${LAB_DOMAIN}`)
      - traefik.http.routers.cs-6.entrypoints=websecure
      - traefik.http.routers.cs-6.tls.certresolver=letsencrypt
      - traefik.http.services.cs-6.loadbalancer.server.port=8080

  cs-coach:
    <<: *workspace
    container_name: cs-coach
    environment:
      PASSWORD: ${COACH_PASSWORD:?set in .env}
    volumes:
      - ./data/${COACH_NAME}:/home/coder/robot
    labels:
      - traefik.enable=true
      - traefik.http.routers.cs-coach.rule=Host(`${COACH_NAME}.${LAB_DOMAIN}`)
      - traefik.http.routers.cs-coach.entrypoints=websecure
      - traefik.http.routers.cs-coach.tls.certresolver=letsencrypt
      - traefik.http.services.cs-coach.loadbalancer.server.port=8080

networks:
  proxy:
    external: true
```

- [ ] **Step 2: Verify compose fails loudly without `.env`**

Run:
```bash
cd /home/ts/wrk/docker-configs/teaching/code-server
docker compose config >/dev/null
```
Expected: FAIL — `required variable STUDENT_1_PASSWORD is missing a value: set in .env`. This proves no workspace can start password-less.

- [ ] **Step 3: Create a real `.env` and re-verify**

```bash
cp .env.example .env
for i in 1 2 3 4 5 6; do
  sed -i "s|^STUDENT_${i}_PASSWORD=.*|STUDENT_${i}_PASSWORD=$(openssl rand -base64 18)|" .env
done
sed -i "s|^COACH_PASSWORD=.*|COACH_PASSWORD=$(openssl rand -base64 18)|" .env
docker compose config | grep -c "container_name"
```
Expected: `7`

- [ ] **Step 4: Confirm `.env` is still invisible to git**

Run: `git status --short` — expected: `.env` does NOT appear. Only `compose.yaml` shows as new.

- [ ] **Step 5: Commit**

```bash
git add teaching/code-server/compose.yaml
git commit -m "teaching: 6 student + coach code-server workspaces"
```

---

### Task 4: Traefik for the teaching VM

**Files:**
- Create: `teaching/traefik/compose.yaml`
- Create: `teaching/traefik/config/traefik.yml`
- Create: `teaching/traefik/.env.example`

**Interfaces:**
- Consumes: `CLOUDFLARE_EMAIL`, `CLOUDFLARE_API_TOKEN` from `teaching/traefik/.env`.
- Produces: the external `proxy` network and the `letsencrypt` cert resolver used by Task 3.

DNS-01 issues real certs for a LAN-only host with nothing exposed — same pattern as `homelab/traefik`, and as the archived `.29` config.

- [ ] **Step 1: Create `teaching/traefik/config/traefik.yml`**

```yaml
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entrypoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt
        domains:
          - main: "lab.nexuswarrior.site"
            sans:
              - "*.lab.nexuswarrior.site"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false

certificatesResolvers:
  letsencrypt:
    acme:
      email: "anand.krs@gmail.com"
      storage: /acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"

log:
  level: INFO
```

- [ ] **Step 2: Create `teaching/traefik/.env.example`**

```bash
CLOUDFLARE_EMAIL=
CLOUDFLARE_API_TOKEN=
```

- [ ] **Step 3: Create `teaching/traefik/compose.yaml`**

```yaml
name: traefik

services:
  traefik:
    image: traefik:v3.3
    container_name: traefik
    restart: unless-stopped
    networks: [proxy]
    ports:
      - "80:80"
      - "443:443"
    env_file: [.env]
    environment:
      CF_API_EMAIL: ${CLOUDFLARE_EMAIL:?set in .env}
      CF_DNS_API_TOKEN: ${CLOUDFLARE_API_TOKEN:?set in .env}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./config/traefik.yml:/etc/traefik/traefik.yml:ro
      - ./config/acme.json:/acme.json
    healthcheck:
      test: ["CMD", "traefik", "healthcheck", "--ping"]
      interval: 30s
      timeout: 5s
      retries: 3

networks:
  proxy:
    external: true
```

- [ ] **Step 4: Validate config renders**

Run:
```bash
cd /home/ts/wrk/docker-configs/teaching/traefik
cp .env.example .env && printf 'CLOUDFLARE_EMAIL=x@y.z\nCLOUDFLARE_API_TOKEN=dummy\n' > .env
docker compose config >/dev/null && echo RENDER_OK
```
Expected: `RENDER_OK`

- [ ] **Step 5: Commit**

```bash
git add teaching/traefik/compose.yaml teaching/traefik/config/traefik.yml teaching/traefik/.env.example
git commit -m "teaching: traefik with cloudflare dns-01, LAN-only"
```

---

### Task 5: Deploy to the VM and prove one workspace end-to-end

**Files:**
- Modify: `deploy/deploy-homelab.sh` — no. Create: `teaching/deploy-teaching.sh`

The homelab script targets `.13` and carries known bugs (`TODO.md`). Do not extend it; a small dedicated script avoids inheriting them.

**Interfaces:**
- Consumes: everything above. Requires `TEACHING_VM_IP` and SSH key access.

- [ ] **Step 1: Create `teaching/deploy-teaching.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

VM="${TEACHING_VM:?export TEACHING_VM=user@ip}"
REMOTE_DIR="/opt/teaching"

echo "==> syncing to $VM:$REMOTE_DIR"
rsync -az --delete \
  --exclude '.env' --exclude 'data/' \
  ./ "$VM:$REMOTE_DIR/"

echo "==> ensuring proxy network"
ssh "$VM" 'docker network inspect proxy >/dev/null 2>&1 || docker network create proxy'

# The workspace image runs as uid 1000 (codercom/code-server: `USER 1000`).
# Docker creates missing bind-mount host dirs as root, which would leave every
# workspace read-only: GitDoc could not `git init` and students could not save.
# Pre-create each data dir owned by 1000 BEFORE compose up.
echo "==> preparing workspace data dirs (uid 1000)"
# shellcheck disable=SC2029
ssh "$VM" "set -a; . $REMOTE_DIR/code-server/.env; set +a
for n in \"\$STUDENT_1_NAME\" \"\$STUDENT_2_NAME\" \"\$STUDENT_3_NAME\" \"\$STUDENT_4_NAME\" \"\$STUDENT_5_NAME\" \"\$STUDENT_6_NAME\" \"\$COACH_NAME\"; do
  sudo mkdir -p '$REMOTE_DIR/code-server/data/'\"\$n\"
  sudo chown -R 1000:1000 '$REMOTE_DIR/code-server/data/'\"\$n\"
done"

echo "==> building workspace image"
ssh "$VM" "cd $REMOTE_DIR/code-server && docker build -t vex-workspace:1.0 ."

echo "==> starting traefik"
ssh "$VM" "cd $REMOTE_DIR/traefik && touch config/acme.json && chmod 600 config/acme.json && docker compose up -d"

echo "==> starting workspaces"
ssh "$VM" "cd $REMOTE_DIR/code-server && docker compose up -d"

echo "==> status"
ssh "$VM" 'docker ps --format "{{.Names}}\t{{.Status}}" | sort'
```

`.env` is excluded from rsync deliberately — secrets are placed on the VM once, by hand, and never travel from a workstation on every deploy.

- [ ] **Step 2: Place secrets on the VM once**

```bash
export TEACHING_VM=dev@<TEACHING_VM_IP>
ssh "$TEACHING_VM" 'mkdir -p /opt/teaching/code-server /opt/teaching/traefik'
scp teaching/code-server/.env "$TEACHING_VM:/opt/teaching/code-server/.env"
scp teaching/traefik/.env     "$TEACHING_VM:/opt/teaching/traefik/.env"
```

- [ ] **Step 3: Deploy**

```bash
chmod +x teaching/deploy-teaching.sh
cd teaching && ./deploy-teaching.sh
```
Expected: 8 containers (`traefik`, `cs-1`..`cs-6`, `cs-coach`), all `Up`.

- [ ] **Step 3b: Verify a student can actually WRITE to their workspace**

The image runs as uid 1000; a root-owned bind mount silently makes the workspace read-only, and
the symptom (GitDoc never commits) looks like a GitDoc bug rather than a permissions one.

```bash
ssh "$TEACHING_VM" 'docker exec cs-1 bash -c "touch /home/coder/robot/.wtest && rm /home/coder/robot/.wtest && echo WRITABLE"'
```
Expected: `WRITABLE`. If it errors with permission denied, the data dir is root-owned — re-run the
deploy script's data-dir step.

- [ ] **Step 4: Verify every workspace is healthy — not just one**

Run:
```bash
ssh "$TEACHING_VM" 'docker ps --filter "name=cs-" --format "{{.Names}} {{.Status}}" | grep -c healthy'
```
Expected: `7`. Anything less means a workspace is down — investigate before showing kids.

- [ ] **Step 5: Add DNS rewrites in AdGuard**

In AdGuard (`http://192.168.10.13:3053`) add a wildcard rewrite:
`*.lab.nexuswarrior.site` → `<TEACHING_VM_IP>`

Verify: `dig +short student-1.lab.nexuswarrior.site` → returns `TEACHING_VM_IP`

- [ ] **Step 6: Verify TLS and login page from a LAN client**

```bash
curl -sI https://student-1.lab.nexuswarrior.site | head -1
```
Expected: `HTTP/2 200`. A cert error means DNS-01 hasn't completed — check `docker logs traefik`.

- [ ] **Step 7: Commit**

```bash
git add teaching/deploy-teaching.sh
git commit -m "teaching: deploy script for teaching VM"
```

---

### Task 6: Forgejo repos + prove autosync actually works

**Interfaces:**
- Consumes: running workspaces (Task 5).
- Produces: verified end-to-end autosync — the core claim of this design.

- [ ] **Step 1: Create the Forgejo org and repos**

In Forgejo: org `vex-iq`, repos `student-1`..`student-6`, `coach`, `team-official`. One Forgejo account per student. Each student's token scoped to **their repo only**, not the org.

- [ ] **Step 2: Wire one workspace's git identity**

```bash
ssh "$TEACHING_VM" 'docker exec cs-1 bash -c "
  cd /home/coder/robot &&
  git init -b main &&
  git config user.name  \"student-1\" &&
  git config user.email \"student-1@nexusrobotics.local\" &&
  git remote add origin https://student-1:<TOKEN>@<FORGEJO_HOST>/vex-iq/student-1.git
"'
```

- [ ] **Step 3: Prove GitDoc auto-commits and pushes**

This is the step that validates the whole design. In a browser at `https://student-1.lab.nexuswarrior.site`, create `robot.py`, type a line, save, wait 10 seconds.

```bash
ssh "$TEACHING_VM" 'docker exec cs-1 git -C /home/coder/robot log --oneline'
```
Expected: at least one `auto: ...` commit. Then confirm it reached Forgejo:
```bash
ssh "$TEACHING_VM" 'docker exec cs-1 git -C /home/coder/robot log origin/main --oneline'
```
Expected: the same commit. If it committed but did not push, `gitdoc.autoPush` is misconfigured — fix before rolling out to the other six.

- [ ] **Step 4: Repeat Steps 2–3 for `cs-2`..`cs-6` and `cs-coach`**

Same commands, substituting the student index and token each time.

---

### Task 7: Download station

**Files:**
- Create: `teaching/STATION-SETUP.md`

**Interfaces:**
- Consumes: Forgejo repos (Task 6).

- [ ] **Step 1: Write `teaching/STATION-SETUP.md`**

Document, for the one station machine beside the robot:

```powershell
winget install -e --id Microsoft.VisualStudioCode
winget install -e --id Git.Git
winget install -e --id Python.Python.3.11
code --install-extension VEXRobotics.vexcode
code --install-extension ms-python.python
```

Plus a `pull-all.ps1` that clones/pulls all seven repos into `C:\vex\`, and the student-facing flow: open your file → VEX sidebar → Download → run.

Note in the doc: **Python on IQ is single-file download only** — keep projects flat.

- [ ] **Step 2: Verify the station flashes the robot**

With the brain connected by USB-C: open a pulled `robot.py`, hit Download, confirm the program runs. **Then** test Bluetooth from the station — VEX docs indicate Gen 2 Bluetooth works, but `kb.vex.com` blocks automated verification, so this is unconfirmed. Controller-tether is the fallback and is competition-realistic.

- [ ] **Step 3: Commit**

```bash
git add teaching/STATION-SETUP.md
git commit -m "teaching: download station setup"
```

---

## Rollout gate

Do not hand URLs to students until:
- [ ] All 7 workspaces report `healthy`
- [ ] Autosync verified on **every** workspace, not just `cs-1`
- [ ] Station flashes the robot successfully
- [ ] Proxmox root + UniFi passwords rotated (`TODO.md`)
- [ ] `git status` in the repo shows no `.env` and no student names in tracked files
