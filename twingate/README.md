# Twingate Connector Setup

This directory contains the Twingate connector configuration for secure remote access to your homelab.

## Setup Instructions

### 1. Create a Twingate Connector

1. Log in to your Twingate Admin Console: https://clcreative.twingate.com/
   (Replace `clcreative` with your actual network name)

2. Navigate to: **Networks** → **Connectors** → **Add Connector**

3. Choose a name for your connector (e.g., "Proxmox-Homelab")

4. Select "Docker" as the deployment method

5. Copy the three values shown:
   - Network name
   - Access Token
   - Refresh Token

### 2. Configure Environment Variables

1. Copy the example file:
   ```bash
   cd /home/dev/docker/docker-configs/twingate
   cp .env.example .env
   ```

2. Edit the `.env` file and paste your tokens:
   ```bash
   nano .env
   ```

3. Fill in the values from step 1

### 3. Deploy the Connector

```bash
cd /home/dev/docker/docker-configs/twingate
docker compose up -d
```

### 4. Verify Connection

```bash
docker logs twingate-connector
```

You should see: "Connector is online and ready"

### 5. Configure Resources in Twingate

1. In Twingate Admin Console, go to: **Resources** → **Add Resource**

2. Add your services with these settings:

   **Homepage (Main Site)**
   - Name: `Homepage`
   - Address: `plexlab.site` or `192.168.10.13`
   - Ports: `443` (HTTPS)
   - Connector: Select your connector
   - Access: Assign to your user/group

   **Traefik Dashboard**
   - Name: `Traefik`
   - Address: `traefik.plexlab.site` or `192.168.10.13`
   - Ports: `443`
   - Connector: Select your connector
   - Access: Assign to your user/group

   **Other Services** (repeat for each):
   - Jellyfin: `jellyfin.plexlab.site`
   - Proxmox: `proxmox.plexlab.site` → `192.168.10.61:8006`
   - TrueNAS: `truenas.plexlab.site` → `192.168.10.15`
   - etc.

### 6. Configure DNS Override (Recommended)

To make `*.plexlab.site` work through Twingate:

1. In Twingate Admin Console: **DNS** → **DNS Override**

2. Add override:
   - Domain: `plexlab.site`
   - IP Address: `192.168.10.13`
   - Include subdomains: ✓

3. Add override for wildcards:
   - Domain: `*.plexlab.site`
   - IP Address: `192.168.10.13`

### 7. Install Twingate Client

On your laptop/phone:
1. Download Twingate client: https://www.twingate.com/download
2. Install and sign in with your Twingate account
3. Connect to your network
4. Access: https://plexlab.site

## Troubleshooting

- **Connector not connecting**: Check firewall rules, ensure outbound HTTPS (443) is allowed
- **Services not accessible**: Verify resources are added in Twingate dashboard
- **DNS not resolving**: Check DNS override configuration
- **Permission denied**: Ensure your user has access to the resources

## Useful Commands

```bash
# View connector logs
docker logs -f twingate-connector

# Restart connector
docker compose restart

# Stop connector
docker compose down

# Update connector
docker compose pull
docker compose up -d
```
