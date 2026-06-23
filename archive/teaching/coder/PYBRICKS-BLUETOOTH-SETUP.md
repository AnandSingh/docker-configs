# Pybricks Web Bluetooth Setup for Coder

## Changes Made

This document explains the changes made to enable Web Bluetooth support for the Pybricks Runner extension in your Coder workspaces.

## What Was Changed

### 1. Traefik Middleware Configuration
**File**: `teaching/traefik/config/dynamic/bluetooth-middleware.yml` (NEW)

Added a middleware that injects the `Permissions-Policy: bluetooth=(self)` header to all responses. This header tells the browser it's allowed to access Bluetooth API.

### 2. Coder Docker Compose
**File**: `teaching/coder/docker-compose.yaml`

Applied the bluetooth-permissions middleware to:
- Main Coder dashboard router (line 47)
- Workspace wildcard router (line 55)

This ensures all coder workspaces get the required header.

### 3. Workspace Template - Dockerfile
**File**: `teaching/coder/templates/fll-python/Dockerfile`

Added `"pybricksRunner.forceWebBluetooth": true` to VS Code settings (line 103). This automatically enables Web Bluetooth mode in the Pybricks Runner extension.

## Deployment Steps

### Step 1: Restart Traefik
```bash
cd /home/dev/docker/teaching/traefik
docker compose restart
```

This will load the new bluetooth-permissions middleware.

### Step 2: Restart Coder
```bash
cd /home/dev/docker/teaching/coder
docker compose down
docker compose up -d
```

This applies the middleware to the Coder routes.

### Step 3: Rebuild Docker Image
```bash
cd /home/dev/docker/teaching/coder/templates/fll-python
docker build -t fll-python:latest .
```

This rebuilds the workspace image with the updated VS Code settings.

### Step 4: Recreate Template in Coder
1. Package the updated template:
   ```bash
   cd /home/dev/docker/teaching/coder/templates
   ./create-template-zip.sh
   ```

2. Upload to Coder:
   - Go to https://coder.lab.nexuswarrior.site
   - Navigate to Templates
   - Update or recreate the "FLL Python" template
   - Upload the new `fll-python-template.zip`

### Step 5: Recreate Workspaces
For each student's workspace:
1. Stop the workspace
2. Delete the workspace (data is preserved in volumes)
3. Create a new workspace using the updated template

**OR** have students rebuild their workspaces from the Coder UI.

## Testing

### 1. Verify Headers
Open a student workspace (e.g., `https://nihita-main.coder.lab.nexuswarrior.site`):
1. Open Developer Console (F12)
2. Go to Network tab
3. Refresh the page
4. Click on the main document request
5. Check Response Headers
6. Verify you see: `Permissions-Policy: bluetooth=(self)`

### 2. Test Bluetooth Access
1. Open VS Code in the workspace
2. Open a Python file
3. Click "Run on Robot" button in Pybricks Runner
4. Should see Web Bluetooth pairing dialog
5. Should be able to connect to LEGO hub

## Troubleshooting

### Header Not Appearing
- Ensure Traefik restarted successfully
- Check Traefik logs: `docker logs traefik`
- Verify middleware file exists: `ls /home/dev/docker/teaching/traefik/config/dynamic/bluetooth-middleware.yml`

### Bluetooth Still Not Working
- Clear browser cache (Ctrl+Shift+Delete)
- Try in Chrome/Chromium (Web Bluetooth not supported in Firefox)
- Check if extension setting is enabled:
  - Open Settings (Ctrl+,)
  - Search: `pybricksRunner.forceWebBluetooth`
  - Should be checked

### Extension Not Found
- Verify extension is installed in template Dockerfile (line 89)
- Rebuild docker image
- Recreate workspace

## Browser Requirements

Web Bluetooth requires:
- Chrome, Edge, or Chromium-based browser
- HTTPS connection (already configured via Traefik)
- `Permissions-Policy: bluetooth=(self)` header (now configured)

**Firefox does NOT support Web Bluetooth**

## References

- [Pybricks Runner Documentation](https://github.com/pybricks/pybricks-code)
- [Web Bluetooth API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API)
- [Permissions Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Permissions-Policy)
