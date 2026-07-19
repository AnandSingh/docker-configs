#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${CONTAINER:-robotics-lab-forgejo}"
NFS_MOUNT="${NFS_MOUNT:-/mnt/truenas-docker}"
EXPECTED_SOURCE="${EXPECTED_SOURCE:-192.168.10.15:/mnt/nas-pool/nfs-share/docker}"
BACKUP_DIR="${BACKUP_DIR:-$NFS_MOUNT/robotics-lab/forgejo-backups}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE="forgejo-dump-$STAMP.zip"
CONTAINER_ARCHIVE="/data/forgejo/$ARCHIVE"

actual_source="$(findmnt -n -o SOURCE -T "$NFS_MOUNT")"
actual_type="$(findmnt -n -o FSTYPE -T "$NFS_MOUNT")"
if [[ "$actual_source" != "$EXPECTED_SOURCE" || "$actual_type" != nfs* ]]; then
  echo "refusing backup: $NFS_MOUNT is not the expected TrueNAS NFS mount" >&2
  exit 1
fi

install -d -m 0750 -o 1000 -g 1000 "$BACKUP_DIR"
# A brand-new instance has no repository root until its first repository is
# created, but `forgejo dump` still expects the configured directory to exist.
install -d -m 0750 -o 1000 -g 1000 /opt/robotics-lab/forgejo/data/git/repositories
docker exec -u git "$CONTAINER" forgejo dump --quiet \
  --file "$CONTAINER_ARCHIVE" --type zip
install -m 0600 -o 1000 -g 1000 \
  "/opt/robotics-lab/forgejo/data/forgejo/$ARCHIVE" "$BACKUP_DIR/$ARCHIVE"
rm -f "/opt/robotics-lab/forgejo/data/forgejo/$ARCHIVE"
test -s "$BACKUP_DIR/$ARCHIVE"
echo "$BACKUP_DIR/$ARCHIVE"
