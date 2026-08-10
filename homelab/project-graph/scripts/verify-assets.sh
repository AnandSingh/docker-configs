#!/usr/bin/env bash
# verify-assets.sh — check the vendored vis-network bundle matches the pinned
# hash, that compose does not regress to a nested /assets mount or an
# individual nginx config file bind (NFS inode pinning), and that no
# private content has leaked into Git-tracked paths.
# Used by CI (validate job) and safe to run locally. Read-only.

set -euo pipefail

SERVICE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_JS_SHA256='576bb887733eb01bb52ee75b90ef46d818454de5fddb5b616fb8a298d307ca12'

echo "${EXPECTED_JS_SHA256}  ${SERVICE_DIR}/assets/vis-network.min.js" | sha256sum -c -

# Regression guard: Docker cannot create a mountpoint inside a read-only
# parent bind mount, so a nested ./assets -> /usr/share/nginx/html/assets
# mount (which local Podman happily accepted) breaks the container at start
# on the deploy host. The workflow copies the bundle into site/assets/
# instead; the web root must stay a SINGLE mount.
if grep -Eq '/usr/share/nginx/html/assets' "${SERVICE_DIR}/compose.yaml"; then
    echo "ERROR: compose.yaml mounts /usr/share/nginx/html/assets — nested mount" >&2
    echo "  under the read-only site mount fails on Docker. Publish the asset" >&2
    echo "  into site/assets/ via the deploy workflow instead." >&2
    exit 1
fi

# Regression guard: the deploy tree is NFS-backed. An individual file bind
# of nginx/default.conf pins that file's inode; when the deploy rsync
# replaces the file, NFS silly-renames the still-open old inode to .nfs*
# and the next `rsync --delete` fails with "Device or resource busy".
# nginx config must be mounted as a DIRECTORY (./nginx -> /etc/nginx/conf.d).
if grep -Eq '/etc/nginx/conf\.d/default\.conf' "${SERVICE_DIR}/compose.yaml"; then
    echo "ERROR: compose.yaml bind-mounts /etc/nginx/conf.d/default.conf as an" >&2
    echo "  individual file. On the NFS-backed deploy tree this pins the inode" >&2
    echo "  and breaks rsync --delete after the file is replaced (silly-rename" >&2
    echo "  .nfs* leftovers). Mount the directory instead: ./nginx:/etc/nginx/conf.d:ro" >&2
    exit 1
fi

[ -f "${SERVICE_DIR}/assets/vis-network-LICENSE-APACHE-2.0.txt" ] || {
    echo "ERROR: vis-network license file missing" >&2
    exit 1
}

# The private generated site content must never be tracked in this public
# repo — reject ANY Git-tracked file under site/, not just index.html.
TRACKED_SITE_FILES="$(git -C "$SERVICE_DIR" ls-files -- site/)"
if [ -n "$TRACKED_SITE_FILES" ]; then
    echo "ERROR: files under site/ are tracked by Git — private content must not be committed:" >&2
    printf '%s\n' "$TRACKED_SITE_FILES" | sed 's/^/  /' >&2
    exit 1
fi

echo "OK: vendored assets verified, no private site content tracked"
