# Homelab boot guard: TrueNAS before Docker

## Proxmox VM startup order

Configured on Proxmox host `192.168.10.61`:

```bash
qm set 102 --startup order=1,up=180   # TrueNAS-SCALE
qm set 107 --startup order=2,up=30    # Docker/Portainer VM
```

This starts TrueNAS first and waits 180 seconds before starting the Docker VM.

## Docker VM systemd guard

Configured on Docker host `192.168.10.13`:

- `/usr/local/sbin/require-truenas-mounts.sh`
- `/etc/systemd/system/truenas-mounts.service`
- `/etc/systemd/system/docker.service.d/10-require-truenas.conf`

Docker now requires both TrueNAS NFS mounts before it starts:

```text
/home/dev/docker -> 192.168.10.15:/mnt/nas-pool/nfs-share/docker
/media           -> 192.168.10.15:/mnt/nas-pool/data/media
```

If TrueNAS/NFS is unavailable, Docker fails closed instead of starting containers against local disk fallback paths.

## Verification

```bash
ssh dev@192.168.10.13
findmnt -t nfs,nfs4
systemctl status truenas-mounts.service docker.service
```
