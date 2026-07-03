# Immich Photo Library

Self-hosted Google Photos-style library for personal photos/videos.

## Access

- Local: `http://192.168.10.13:2283`
- Traefik: `https://immich.plexlab.site`

## Storage

Immich is configured to store originals on TrueNAS:

```text
/media/photos/immich -> TrueNAS media dataset
/home/dev/docker/appdata/immich/postgres -> TrueNAS docker/appdata dataset
/home/dev/docker/appdata/immich/model-cache -> TrueNAS docker/appdata dataset
```

## Deploy

```bash
cd /home/dev/docker/docker-configs/homelab/immich
cp .env.example .env
openssl rand -base64 32   # put this in DB_PASSWORD
nano .env
docker compose up -d
```

## Google Photos migration/sync

Recommended approach:

1. Use **Google Takeout** for a one-time export of existing Google Photos.
2. Put the extracted Takeout data on TrueNAS, for example:
   ```text
   /media/photos/google-takeout
   ```
3. In Immich, use the CLI/import workflow to import that folder.
4. For ongoing automatic backup, install the **Immich mobile app** on phones and enable automatic backup.

Notes:

- Google Photos does not provide a perfect always-on original-quality sync API for self-hosted tools.
- `rclone backend google photos` exists, but Google API limitations can reduce quality/metadata fidelity and it may not behave like a true mirror.
- The safest archive-grade migration is Google Takeout + Immich mobile auto-backup going forward.
