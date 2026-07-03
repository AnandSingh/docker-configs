#!/usr/bin/env bash
set -euo pipefail

# Run on Docker host 192.168.10.13 as root, or via sudo.
# Ensures Docker refuses to start unless TrueNAS NFS mounts are available.

install -d -m 0755 /usr/local/sbin /etc/systemd/system/docker.service.d
cp -a /etc/fstab /etc/fstab.bak.$(date +%Y%m%d-%H%M%S)

cat > /usr/local/sbin/require-truenas-mounts.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

TRUENAS_IP="192.168.10.15"
DOCKER_EXPORT="${TRUENAS_IP}:/mnt/nas-pool/nfs-share/docker"
MEDIA_EXPORT="${TRUENAS_IP}:/mnt/nas-pool/data/media"

log() { echo "[truenas-mounts] $*"; }

log "waiting for TrueNAS ${TRUENAS_IP}..."
for i in $(seq 1 60); do
  if ping -c1 -W2 "${TRUENAS_IP}" >/dev/null 2>&1 && timeout 3 bash -lc "</dev/tcp/${TRUENAS_IP}/2049" >/dev/null 2>&1; then
    break
  fi
  if [ "$i" -eq 60 ]; then
    log "TrueNAS/NFS unavailable after 180s; refusing to start Docker"
    exit 1
  fi
  sleep 3
done

mkdir -p /home/dev/docker /media
mountpoint -q /home/dev/docker || mount /home/dev/docker
mountpoint -q /media || mount /media

if ! findmnt -rn -T /home/dev/docker -t nfs,nfs4 | grep -q "${DOCKER_EXPORT}"; then
  log "/home/dev/docker is not mounted from ${DOCKER_EXPORT}"
  findmnt -T /home/dev/docker || true
  exit 1
fi

if ! findmnt -rn -T /media -t nfs,nfs4 | grep -q "${MEDIA_EXPORT}"; then
  log "/media is not mounted from ${MEDIA_EXPORT}"
  findmnt -T /media || true
  exit 1
fi

log "TrueNAS mounts are ready"
EOS
chmod 0755 /usr/local/sbin/require-truenas-mounts.sh

cat > /etc/systemd/system/truenas-mounts.service <<'EOS'
[Unit]
Description=Require TrueNAS NFS mounts before Docker
Documentation=man:fstab(5)
Wants=network-online.target remote-fs.target
After=network-online.target remote-fs-pre.target
Before=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/require-truenas-mounts.sh
TimeoutStartSec=240

[Install]
WantedBy=multi-user.target
EOS

cat > /etc/systemd/system/docker.service.d/10-require-truenas.conf <<'EOS'
[Unit]
Requires=truenas-mounts.service
After=truenas-mounts.service remote-fs.target network-online.target
RequiresMountsFor=/home/dev/docker /media
EOS

systemctl daemon-reload
systemctl enable truenas-mounts.service
systemctl restart truenas-mounts.service
systemctl status truenas-mounts.service --no-pager
