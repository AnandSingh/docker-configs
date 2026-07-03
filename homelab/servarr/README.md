# Servarr + qBittorrent + Gluetun setup

This stack is for legal/public-domain media acquisition and organizing your own library. qBittorrent, NZBGet, and Prowlarr share Gluetun's network namespace so their traffic exits through the VPN container instead of the Docker host.

## Services

- `gluetun` - VPN gateway / kill switch
- `qbittorrent` - torrent client, reachable on host port `8082`
- `nzbget` - Usenet client, reachable on host port `6790`
- `prowlarr` - indexer manager, reachable on host port `9696`
- `radarr` - movie library manager
- `sonarr` - TV library manager
- `lidarr` - music library manager
- `readarr` - book library manager
- `bazarr` - subtitles

## Required TrueNAS mounts on the Docker host

Expected host paths:

```text
/mnt/nas/appdata    -> TrueNAS docker app configs
/mnt/nas/media      -> TrueNAS media library
/mnt/nas/downloads  -> TrueNAS download staging
```

Recommended media folders:

```text
/mnt/nas/media/movies
/mnt/nas/media/tv
/mnt/nas/media/music
/mnt/nas/media/books
/mnt/nas/downloads/incomplete
/mnt/nas/downloads/complete
/mnt/nas/downloads/torrents
```

## Configure secrets

```bash
cd homelab/servarr
cp .env.example .env
nano .env
```

Set your PIA OpenVPN credentials:

```env
OPENVPN_USER=pXXXXXXX
OPENVPN_PASSWORD=...
APPDATA_ROOT=/mnt/nas/appdata
MEDIA_ROOT=/mnt/nas/media
DOWNLOADS_ROOT=/mnt/nas/downloads
```

## Start

```bash
cd homelab/servarr
docker compose --env-file .env -f compose.yaml up -d
```

## Verify VPN path / leak protection

```bash
# Should show the VPN public IP, not your ISP/WAN IP
docker exec gluetun wget -qO- https://ipinfo.io/ip

docker exec qbittorrent wget -qO- https://ipinfo.io/ip

docker compose -f compose.yaml logs -f gluetun
```

If Gluetun is down/unhealthy, qBittorrent/NZBGet/Prowlarr should be unreachable because they use `network_mode: service:gluetun`.

## App path setup

Use one common root layout so hardlinks/imports work cleanly:

- Download clients see downloads as `/downloads`
- Arr apps see downloads as `/downloads`
- Arr apps see libraries under `/data`

Suggested app roots:

- Radarr root folder: `/data/movies`
- Sonarr root folder: `/data/tv`
- Lidarr root folder: `/data/music`
- Readarr root folder: `/data/books`
- qBittorrent default save path: `/downloads/complete`
- qBittorrent incomplete path: `/downloads/incomplete`

## TV / media playback

Use Jellyfin from `homelab/jellyfin`. It reads the same TrueNAS media mount and has TV/mobile apps.
