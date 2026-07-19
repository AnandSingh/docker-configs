# Nexus Robotics Cloudflare Tunnel

Outbound-only remote access connector for the robotics lab. Cloudflare Access
must protect every public hostname before a tunnel route is added. No router
port forwarding is required.

The remotely managed tunnel token is stored only at
`/opt/robotics-lab/cloudflared/tunnel-token`, owned by `root:65532` and mode
`0440`. It is mounted read-only and is never placed in Compose environment
variables or the public repository.

Cloudflare routes the two wildcard domains to Traefik on the private Docker
`proxy` network. Use HTTPS origin validation with the corresponding apex domain
as `originServerName`; do not disable TLS verification.
