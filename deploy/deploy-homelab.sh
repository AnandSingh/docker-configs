#!/bin/bash
set -e

# Homelab Server Deployment Script
# Deploys services to 192.168.10.13 (Main Homelab Server)
# Usage: ./deploy-homelab.sh [service_name|all]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
HOMELAB_DIR="$REPO_DIR/homelab"
BACKUP_DIR="${BACKUP_DIR:-$REPO_DIR/.backups/homelab}"
LOG_FILE="${LOG_FILE:-$REPO_DIR/deploy/deploy-homelab.log}"
SERVICE="${1:-all}"

# Service directories in homelab/
declare -A SERVICES=(
    ["traefik"]="traefik"
    ["adguard"]="adguard-home"
    ["monitoring"]="monitoring"
    ["homepage"]="homepage"
    ["jellyfin"]="jellyfin"
    ["servarr"]="servarr"
    ["rustdesk"]="rustdesk"
    ["twingate"]="twingate"
    ["piholev6"]="Piholev6"
    ["ddns"]="cloudflare-ddns-updater"
)

# Logging functions
log() {
    echo -e "${2:-$NC}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    log "$1" "$BLUE"
}

log_success() {
    log "✅ $1" "$GREEN"
}

log_warning() {
    log "⚠️  $1" "$YELLOW"
}

log_error() {
    log "❌ $1" "$RED"
}

# Create backup
create_backup() {
    local service=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/${service}_${timestamp}"

    log_info "Creating backup for homelab/$service..."
    mkdir -p "$backup_path"

    # Backup docker-compose state
    if [ -f "$HOMELAB_DIR/${SERVICES[$service]}/docker-compose.yaml" ] || [ -f "$HOMELAB_DIR/${SERVICES[$service]}/docker-compose.yml" ] || [ -f "$HOMELAB_DIR/${SERVICES[$service]}/compose.yaml" ]; then
        compose_file=$(ls "$HOMELAB_DIR/${SERVICES[$service]}/"*compose.y*ml 2>/dev/null | head -1)
        docker compose -f "$compose_file" config > "$backup_path/docker-compose.backup.yaml" 2>/dev/null || true
    fi

    # Keep only last 5 backups
    ls -t "$BACKUP_DIR" | grep "^${service}_" | tail -n +6 | xargs -I {} rm -rf "$BACKUP_DIR/{}" 2>/dev/null || true

    echo "$backup_path"
}

# Check if service is running
is_service_running() {
    local service=$1
    local service_dir="${SERVICES[$service]}"

    if [ ! -d "$HOMELAB_DIR/$service_dir" ]; then
        return 1
    fi

    cd "$HOMELAB_DIR/$service_dir"

    if [ -f docker-compose.yaml ] || [ -f docker-compose.yml ] || [ -f compose.yaml ]; then
        compose_file=$(ls *compose.y*ml 2>/dev/null | head -1)
        docker compose -f "$compose_file" ps -q 2>/dev/null | grep -q . && return 0
    fi

    return 1
}

# Deploy a single service
deploy_service() {
    local service=$1
    local service_dir="${SERVICES[$service]}"

    if [ -z "$service_dir" ]; then
        log_error "Unknown service: $service"
        return 1
    fi

    log_info "Deploying homelab/$service..."

    if [ ! -d "$HOMELAB_DIR/$service_dir" ]; then
        log_error "Service directory not found: homelab/$service_dir"
        return 1
    fi

    cd "$HOMELAB_DIR/$service_dir"

    # Check for required files
    if [ ! -f docker-compose.yaml ] && [ ! -f docker-compose.yml ] && [ ! -f compose.yaml ]; then
        log_error "No compose file found in homelab/$service_dir"
        return 1
    fi

    compose_file=$(ls *compose.y*ml 2>/dev/null | head -1)

    # Check for .env file
    if [ ! -f .env ] && [ -f .env.example ]; then
        log_warning "No .env file found, but .env.example exists"

        # Special handling for homepage - it can run without .env (widgets won't work)
        if [ "$service" = "homepage" ]; then
            log_warning "Homepage will deploy without widgets. Add .env file to enable service widgets."
            log_info "Creating minimal .env file with defaults..."
            cp .env.example .env
            # Set default values for required vars only
            sed -i 's/^PUID=.*/PUID=1000/' .env
            sed -i 's/^PGID=.*/PGID=1000/' .env
        else
            log_warning "Please create .env file with required secrets"
            return 1
        fi
    fi

    # Create backup if service is running
    if is_service_running "$service"; then
        create_backup "$service"
    fi

    # Run pre-deployment setup for specific services
    if [ "$service" = "adguard" ]; then
        log_info "Running AdGuard Home pre-deployment setup..."
        if [ -f "./setup-unbound.sh" ]; then
            bash ./setup-unbound.sh || log_warning "Setup script failed, continuing anyway"
        else
            log_warning "setup-unbound.sh not found, skipping"
        fi
    fi

    # Pull latest images
    log_info "Pulling latest images for $service..."
    docker compose -f "$compose_file" pull || log_warning "Failed to pull some images"

    # Deploy service
    log_info "Starting $service..."
    docker compose -f "$compose_file" up -d

    # Check health
    sleep 5
    if docker compose -f "$compose_file" ps | grep -q "Up"; then
        log_success "Successfully deployed homelab/$service"
        docker compose -f "$compose_file" ps
        return 0
    else
        log_error "Failed to deploy homelab/$service"
        docker compose -f "$compose_file" logs --tail=20
        return 1
    fi
}

# Deploy all services
deploy_all() {
    log_info "Deploying all homelab services..."

    local failed=0
    # Deploy in dependency order
    local services_order=("traefik" "adguard" "monitoring" "homepage" "rustdesk" "jellyfin" "servarr" "twingate")

    for service in "${services_order[@]}"; do
        if deploy_service "$service"; then
            log_success "✓ $service deployed"
        else
            log_error "✗ $service failed"
            ((failed++))
        fi
        echo ""
    done

    if [ $failed -eq 0 ]; then
        log_success "All homelab services deployed successfully!"
        return 0
    else
        log_error "$failed service(s) failed to deploy"
        return 1
    fi
}

# Setup proxy network if it doesn't exist
setup_network() {
    if ! docker network inspect proxy >/dev/null 2>&1; then
        log_info "Creating proxy network..."
        docker network create proxy
        log_success "Proxy network created"
    else
        log_info "Proxy network already exists"
    fi
}

# Main execution
main() {
    log_info "=================================================="
    log_info "Homelab Server Deployment (192.168.10.13)"
    log_info "=================================================="

    # Create necessary directories
    mkdir -p "$BACKUP_DIR"

    # Setup network
    setup_network

    # Deploy service(s)
    if [ "$SERVICE" == "all" ]; then
        deploy_all
    else
        if [ -z "${SERVICES[$SERVICE]}" ]; then
            log_error "Unknown service: $SERVICE"
            log_info "Available services: ${!SERVICES[@]}"
            exit 1
        fi
        deploy_service "$SERVICE"
    fi
}

# Show usage
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    echo "Homelab Server Deployment Script"
    echo ""
    echo "Usage: $0 [service_name|all]"
    echo ""
    echo "Available services:"
    for service in "${!SERVICES[@]}"; do
        echo "  - $service"
    done
    echo ""
    echo "Examples:"
    echo "  $0 all          # Deploy all homelab services"
    echo "  $0 traefik      # Deploy only Traefik"
    echo "  $0 jellyfin     # Deploy only Jellyfin"
    exit 0
fi

main
