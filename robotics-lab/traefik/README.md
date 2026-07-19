# Robotics Lab Traefik

Dedicated LAN/Twingate reverse proxy for `*.nexusroboticslab.org` and
`*.nexusrobo.org` on
`192.168.10.29`. There is no public router forwarding and no Traefik dashboard.

## Cloudflare credential

Create a Cloudflare API token limited to:

- Zones: `nexusroboticslab.org` and `nexusrobo.org`
- Permissions: Zone / Zone / Read and Zone / DNS / Edit

Place it only in `/opt/robotics-lab/traefik/.env`:

```bash
CLOUDFLARE_API_TOKEN=replace-me
```

The token performs DNS-01 validation; it does not require inbound internet
access to the VM. `acme.json` remains on the VM's local disk and must be mode
`0600`.

## Validation

```bash
docker compose config --quiet
docker compose up -d
docker compose ps
curl -I http://health.nexusroboticslab.org
curl -fsS https://health.nexusroboticslab.org/ping
curl -fsS https://health.nexusrobo.org/ping
```

Expected: HTTP redirects to HTTPS, `/ping` returns `OK`, and the certificate
covers both apex domains and both wildcard domains.
