# Nexus Robotics Lab host

Target: Proxmox VM `100`, `nexus-robotics-lab`, Ubuntu Server 24.04 LTS at
`192.168.10.29`.

## Installed baseline

- Key-only SSH user `dev`; root and password SSH disabled
- QEMU guest agent, unattended upgrades, NFS client, Git, curl, and rsync
- UFW default-deny inbound; HOME `192.168.10.0/24` may reach 22, 80, and 443
- Docker Engine 29.6.2 from Docker's official Ubuntu `stable` apt repository
- Docker Compose plugin 5.3.1
- Docker `local` log driver and live restore

Docker-published ports bypass UFW. `configure-docker-firewall.sh` installs a
separate `DOCKER-USER` policy that accepts 80/443 and Forgejo SSH port 2222 entering the VM's LAN
interface from HOME (including the Twingate connector) and drops those ports
from other sources. Docker bridge traffic retains outbound access for ACME,
DNS, and development services. The accompanying systemd unit reapplies the
policy after Docker starts.

## Install the tracked Docker firewall policy

```bash
sudo install -m 0755 configure-docker-firewall.sh \
  /usr/local/sbin/configure-nexus-docker-firewall
sudo install -m 0644 docker-firewall.service \
  /etc/systemd/system/docker-firewall.service
sudo systemctl daemon-reload
sudo systemctl enable --now docker-firewall.service
```

Verify:

```bash
sudo ufw status verbose
sudo iptables -S DOCKER-USER
sudo iptables -S NEXUS-ROBOTICS-LAB
docker version
docker compose version
```

Do not add public router forwarding. Later clientless remote access uses an
outbound Cloudflare Tunnel and a separately reviewed Access policy.

## TrueNAS workspace storage

The former teaching VM used this existing export, which remains available:

```text
192.168.10.15:/mnt/nas-pool/nfs-share/docker
```

The robotics-lab VM mounts it at `/mnt/truenas-docker`, then bind-mounts only
`robotics-lab/code-server-data` to `/opt/robotics-lab/code-server/data`. The
tracked storage service verifies the real NFS source before creating the bind
mount, preventing an `/etc/fstab` ordering race, and tests UID 1000 write access.
Future application units must require `robotics-lab-storage.service`; Docker
itself may run without TrueNAS, but the application stack must fail closed.

Mount options retained from the former VM are `rw,hard,rsize=131072,
wsize=131072,timeo=600`, with `_netdev,nofail` added so an NFS outage does not
prevent the Ubuntu VM from reaching an administrative boot.

Verify:

```bash
systemctl status robotics-lab-storage.service
findmnt -T /mnt/truenas-docker
findmnt -T /opt/robotics-lab/code-server/data
sudo -u '#1000' touch /opt/robotics-lab/code-server/data/.wtest
sudo rm /opt/robotics-lab/code-server/data/.wtest
```
