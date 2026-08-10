# project-graph — private Graphify dashboard

Serves a privately generated Graphify project graph at
**https://projects.plexlab.site** (LAN / Twingate only — the hostname resolves
to the RFC1918 homelab host; there is no public exposure, no published host
port, and no Cloudflare Access).

## Privacy model (this repo is PUBLIC)

| Content | Where it lives | In Git? |
|---|---|---|
| Generated graph HTML (private) | GitHub Actions secrets → `site/index.html` on the deploy host | **Never** |
| vis-network 9.1.6 bundle + license (public) | `assets/` (source of truth); workflow deploys a hash-verified copy to `site/assets/vis-network.min.js` | Yes (`assets/` only) |
| nginx config, compose, scripts | this directory | Yes |

On the deploy host, `site/` therefore contains the private `index.html` plus
`assets/vis-network.min.js`, a deployed copy of the *public* hash-pinned
bundle — nothing in `site/` is secret except `index.html`. `site/` stays
gitignored and excluded from the deploy rsync, so the runtime content
survives code syncs and is only replaced atomically by the workflow.

Secrets used (repo secrets on `AnandSingh/docker-configs`):

- `PROJECT_GRAPH_DASHBOARD_GZIP_B64` — gzip+base64 of the transformed HTML
- `PROJECT_GRAPH_DASHBOARD_SHA256` — sha256 of the transformed HTML (integrity check)

**Publish both secrets (step 2 below) BEFORE the first deployment/merge to
`main`.** An explicit `service=project-graph` dispatch fails hard when the
secrets are missing; an `all` deploy skips reconstruction and serves nothing
at `site/index.html` until the secrets exist and a deploy runs again.

## Hardening

- Image pinned by digest: `nginxinc/nginx-unprivileged:1.28-alpine@sha256:7377697a…ec3f8`, listens on 8080, runs as uid 101.
- `read_only` rootfs, `cap_drop: ALL`, `no-new-privileges`, tmpfs only on `/tmp`.
- No host ports; only the external `proxy` network + Traefik labels (websecure, TLS).
- nginx: dotfiles denied, autoindex off, `no-store` + `noindex` + CSP allowing
  only `'self'` and the inline script/style Graphify emits — the page cannot
  load from or talk to any external origin.
- The web root is a **single** read-only mount of `site/`. `/assets/` is
  served from `site/assets/`, where the workflow atomically installs a
  SHA-256-verified copy of the repo-vendored bundle (mode 0444). A nested
  `./assets` bind mount under the read-only web root is deliberately absent:
  Docker cannot create a mountpoint inside a read-only parent mount and
  fails before process start (Podman tolerated it, which is why it worked
  locally). `verify-assets.sh` fails CI if that nested mount reappears.
- The nginx config is mounted as a **directory** (`./nginx:/etc/nginx/conf.d:ro`),
  never as an individual file bind of `default.conf`. See the NFS pitfall
  below; `verify-assets.sh` also fails CI if a
  `/etc/nginx/conf.d/default.conf` file bind reappears.

## NFS pitfall: never bind-mount individual files from the deploy tree

The deployment directory on the deploy host is NFS-backed. Bind-mounting an
individual file (as the compose file originally did with
`./nginx/default.conf`) makes the running container pin that exact inode.
When the deploy rsync later replaces the file, NFS cannot free the old inode
while the container still holds it open, so it "silly-renames" it to a
hidden `.nfs…` file in the same directory. The next isolated deploy's
`rsync --delete` then fails with `Device or resource busy` trying to unlink
that `.nfs…` file — blocking the very deploy that would fix things.

Rules that follow from this:

- **Mount directories, not files.** The container pins the directory, not any
  file inode, so rsync can replace `default.conf` freely. The isolated deploy
  runs `docker compose up -d --force-recreate` so the new config is loaded and
  any old open inode is released deterministically on every deployment.
- The isolated project-graph rsync passes `--exclude='.nfs*'` so transient
  silly-rename files are never copied and never block `--delete`. NFS
  removes a silly-renamed file automatically once the old container (or any
  other holder) releases the inode — after container recreation they clean
  themselves up; no manual deletion is needed or safe while the inode is
  open.
- The same scoped rsync uses `--checksum`. Because it intentionally does not
  preserve mtimes, a size-only quick check would otherwise miss a config
  edit whose replacement has the same byte length.

## Publish a new graph

```bash
# 1. Generate graph.html locally with Graphify (must reference exactly
#    https://unpkg.com/vis-network@9.1.6/standalone/umd/vis-network.min.js)
# 2. Package + upload as secrets (prints only sizes and the non-secret SHA):
homelab/project-graph/scripts/publish-graph-secrets.sh ~/path/to/graph.html
# optional: --repo owner/repo to override the default AnandSingh/docker-configs

# 3. Deploy just this service (manual deployment MUST target main — the
#    deploy job only runs for refs/heads/main; dispatching any other ref
#    validates but never deploys):
gh workflow run deploy-homelab.yml --repo AnandSingh/docker-configs \
    --ref main -f service=project-graph

# 4. Watch it:
gh run watch --repo AnandSingh/docker-configs
```

The `service` input is validated against the workflow's allowlist of homelab
services (empty means `all`); unknown values fail the run before anything
deploys.

The workflow reconstructs `site/index.html` (base64 → gunzip → sha256 compare
→ reference checks → atomic replace, mode 0444) only when the selected service
is `project-graph` or `all`, keeps a timestamped rollback copy under
`.backups/homelab/project-graph-site/` (last 5), then deploys the container.
If the deployed HTML already matches the published SHA-256, the step logs
"unchanged" and leaves it alone, so rollback history only ever contains
distinct versions. The public `site/assets/vis-network.min.js` copy is
republished (hash-verified, atomic, mode 0444) on **every** reconstruction
run — including unchanged-HTML runs — so bundle updates or a
missing/corrupt deployed asset are always repaired; the deploy step then
re-verifies its hash immediately before `docker compose up -d` and refuses
to start the container on a mismatch.

## Isolated deploy path (project-graph only)

When the selected service is `project-graph`, the workflow takes a strictly
isolated path instead of the shared full-repo machinery:

- **Sync**: rsync copies *only* `homelab/project-graph/` into the deployment
  directory (`--delete` scoped to that one tree, `site/` excluded so the
  private runtime HTML **and** the deployed `site/assets/` copy survive; the
  workflow, not rsync, owns publishing into `site/`; `.nfs*` silly-rename
  files are excluded so open-inode leftovers never block the sync). No other
  homelab service or deployment directory is scanned, deleted, or chmod-ed.
- **Secrets**: the shared "Setup secrets" step is skipped entirely — this
  stack has no `.env`, and a project-only deploy must not rewrite unrelated
  Traefik/Twingate secret files.
- **Deploy**: `deploy/deploy.sh` is bypassed. The workflow works only inside
  `homelab/project-graph/`: `compose config` validation, a SHA-256 check of
  the deployed `site/assets/vis-network.min.js` (fail-hard if missing or
  wrong), pull of the digest-pinned image, `up -d --force-recreate`, then a bounded wait
  (≤120s) for the `project-graph` container health check. On timeout it
  prints bounded `compose ps`/`logs --tail` output and fails.

Why: the deploy host's other service trees contain runtime state owned by
root or container users. Any full-tree operation (rsync, chmod, deploy
script walks) either fails hard on those unreadable paths or risks touching
runtime data — so project-only deploys intentionally never traverse
unrelated trees. Artifact reconstruction and rollback behavior are the same
on both paths. Deploys of any *other* service (or `all`) still use the
legacy full-repo sync + `deploy/deploy.sh` unchanged.

## Verify health

On the deploy host (`192.168.10.13`):

```bash
docker inspect --format '{{.State.Health.Status}}' project-graph   # expect: healthy
docker exec project-graph wget -q -O- http://127.0.0.1:8080/healthz # expect: ok
```

From a LAN/Twingate client:

```bash
curl -fsS https://projects.plexlab.site/healthz                     # expect: ok
curl -fsS -o /dev/null -w '%{http_code}\n' https://projects.plexlab.site/  # expect: 200
```

## Verify content hashes

```bash
# Deployed HTML matches what was published (compare to the SHA printed by
# publish-graph-secrets.sh / stored in PROJECT_GRAPH_DASHBOARD_SHA256):
sha256sum /home/dev/docker/docker-configs/homelab/project-graph/site/index.html

# Deployed copy of the public bundle matches the pinned hash (deploy host):
echo "576bb887733eb01bb52ee75b90ef46d818454de5fddb5b616fb8a298d307ca12  \
/home/dev/docker/docker-configs/homelab/project-graph/site/assets/vis-network.min.js" | sha256sum -c -

# Vendored JS integrity + no nested /assets mount + no tracked site/ files
# (repo checkout or deploy host):
homelab/project-graph/scripts/verify-assets.sh
```

## Rollback

Roll back the **HTML artifact** (deploy host):

```bash
cd /home/dev/docker/docker-configs
ls -t .backups/homelab/project-graph-site/          # pick a timestamped copy
install -m 0444 .backups/homelab/project-graph-site/index.html.<TIMESTAMP> \
    homelab/project-graph/site/.index.html.tmp
mv -f homelab/project-graph/site/.index.html.tmp homelab/project-graph/site/index.html
# No container restart needed — nginx serves the bind mount directly.
curl -fsS https://projects.plexlab.site/healthz
```

Roll back the **secrets** (so the next deploy also serves the old graph):
re-run `publish-graph-secrets.sh` with the previous `graph.html`.

Roll back the **container/config**: revert the commit on `main` and re-run

```bash
gh workflow run deploy-homelab.yml --repo AnandSingh/docker-configs \
    --ref main -f service=project-graph
```

(the image is digest-pinned, so config rollback fully determines the runtime).

Manual container ops on the deploy host:

```bash
cd /home/dev/docker/docker-configs/homelab/project-graph
docker compose -f compose.yaml up -d       # (re)deploy
docker compose -f compose.yaml logs --tail=50
docker compose -f compose.yaml down        # stop
```
