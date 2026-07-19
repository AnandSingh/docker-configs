#!/usr/bin/env bash
set -euo pipefail

NFS_SOURCE="192.168.10.15:/mnt/nas-pool/nfs-share/docker"
NFS_MOUNT="/mnt/truenas-docker"
DATA_SOURCE="$NFS_MOUNT/robotics-lab/code-server-data"
DATA_MOUNT="/opt/robotics-lab/code-server/data"

mountpoint -q "$NFS_MOUNT" || mount "$NFS_MOUNT"

actual_source="$(findmnt -rn -T "$NFS_MOUNT" -o SOURCE)"
actual_type="$(findmnt -rn -T "$NFS_MOUNT" -o FSTYPE)"
if [[ "$actual_source" != "$NFS_SOURCE" || "$actual_type" != nfs* ]]; then
  echo "Expected $NFS_MOUNT from $NFS_SOURCE (NFS); got $actual_source ($actual_type)" >&2
  exit 1
fi

install -d -o 1000 -g 1000 -m 0770 "$DATA_SOURCE" "$DATA_MOUNT"
mountpoint -q "$DATA_MOUNT" || mount --bind "$DATA_SOURCE" "$DATA_MOUNT"

data_type="$(findmnt -rn -T "$DATA_MOUNT" -o FSTYPE)"
if [[ "$data_type" != nfs* ]]; then
  echo "Expected $DATA_MOUNT to remain NFS-backed; got $data_type" >&2
  exit 1
fi

test_file="$DATA_MOUNT/.storage-check-$$"
sudo -u '#1000' touch "$test_file"
rm -f "$test_file"
echo "robotics-lab storage ready"
