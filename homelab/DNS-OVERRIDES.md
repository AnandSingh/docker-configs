# Local DNS overrides

## pfSense / Unbound on `192.168.20.1`

`forgejo.telisky.dev` is an external Forgejo service and must resolve publicly, not to local Traefik.

Configured in pfSense DNS Resolver custom options:

```unbound
server:
local-zone: "forgejo.telisky.dev." static
local-data: "forgejo.telisky.dev. 90 IN A 15.204.89.163"
local-zone: "telisky.dev." redirect
local-data: "telisky.dev. 90 IN A 192.168.50.10"
local-zone: "plexlab.site." redirect
local-data: "plexlab.site. 90 IN A 192.168.10.13"
```

The specific `forgejo.telisky.dev` zone must appear before the broader `telisky.dev` redirect.

## Validation

```bash
dig @192.168.20.1 +short forgejo.telisky.dev
# 15.204.89.163

curl -Iv https://forgejo.telisky.dev
# certificate subject/SAN should be forgejo.telisky.dev, not TRAEFIK DEFAULT CERT
```

As of this change, wildcard-ish local redirect behavior remains for other `*.telisky.dev` names:

```bash
dig @192.168.20.1 +short foo.telisky.dev
# 192.168.50.10
```
