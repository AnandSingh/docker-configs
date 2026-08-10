# project-graph — private Graphify dashboard

Serves a privately generated Graphify project graph at
**https://projects.plexlab.site** (LAN / Twingate only — the hostname resolves
to the RFC1918 homelab host; there is no public exposure, no published host
port, and no Cloudflare Access).

## Privacy model (this repo is PUBLIC)

| Content | Where it lives | In Git? |
|---|---|---|
| Generated graph HTML (private) | GitHub Actions secrets → `site/index.html` on the deploy host | **Never** |
| vis-network 9.1.6 bundle + license (public) | `assets/` | Yes |
| nginx config, compose, scripts | this directory | Yes |

`site/` is gitignored and excluded from the deploy rsync, so the runtime HTML
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
- `/assets/` is a separate read-only mount of the repo-vendored bundle, so the
  private `site/` dir never contains copies of anything and vice versa.

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
`.backups/homelab/project-graph-site/` (last 5), then runs the normal
compose deploy. If the deployed HTML already matches the published SHA-256,
the step logs "unchanged" and touches nothing, so rollback history only ever
contains distinct versions.

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

# Vendored JS integrity (repo checkout or deploy host):
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
