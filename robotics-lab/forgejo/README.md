# Nexus Robotics Forgejo

Private Forgejo service for the robotics lab. Web access is routed through
Traefik at `git.nexusroboticslab.org` and `git.nexusrobo.org`. Git SSH listens
on VM port `2222`, restricted to HOME/Twingate by the tracked Docker firewall.

Live SQLite and repository data stay on the VM's local disk under `./data`.
Do not place the live database on NFS. Application-consistent dumps belong in
the TrueNAS-backed backup directory and must be tested before relying on them.

Secrets are stored only in the root-readable `.env` on the VM. Public
registration is disabled, and the first administrator is created with the
Forgejo CLI after the service becomes healthy.

`backup-forgejo.sh` verifies the exact TrueNAS NFS mount before asking Forgejo
to create an application dump. The systemd timer runs nightly at 03:15 local
time and catches up after downtime. Backup retention and a destructive restore
test require an explicit owner policy before automation.

Each code-server workspace has one unique write-enabled deploy key scoped to
its matching private repository. Keys live only under
`/opt/robotics-lab/secrets/git/<workspace>` on the VM's local disk and are
mounted read-only at `/home/coder/.ssh`. They are not stored in NFS snapshots,
container images, or this repository.

Workspace SSH config preserves the canonical
`git@git.nexusroboticslab.org:coach/<repository>.git` remote while routing over
the private Docker `proxy` network to Forgejo port 22. LAN clients use the
Forgejo-advertised `ssh://git@git.nexusroboticslab.org:2222/...` URL. The
persistent Forgejo Ed25519 host key is pinned in every workspace; host-key
checking is never disabled.

The owner credential sheet is `/home/dev/robotics-lab-credentials.txt` on the
VM, mode `0600`. Never commit or copy it into a workspace repository.
