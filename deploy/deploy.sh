#!/bin/bash
set -e

# Homelab Deployment Script
# Usage: ./deploy.sh [service_name|all]
# Example: ./deploy.sh traefik
#          ./deploy.sh all

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BACKUP_DIR="${BACKUP_DIR:-$REPO_DIR/.backups}"
LOG_FILE="${LOG_FILE:-$REPO_DIR/deploy/deploy.log}"
SERVICE="${1:-all}"

# Service directories
declare -A SERVICES=(
    ["traefik"]="traefik"
    ["homepage"]="homepage"
    # ["pihole"]="Piholev6"  # Disabled - will set up DNS stack later
    ["rustdesk"]="rustdesk"
)

# Logging function
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

# Create backup of current state
create_backup() {
    local service=$1
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/${service}_${timestamp}"

    log_info "Creating backup for $service..."
    mkdir -p "$backup_path"

    # Backup docker-compose state
    if [ -f "$REPO_DIR/${SERVICES[$service]}/docker-compose.yaml" ] || [ -f "$REPO_DIR/${SERVICES[$service]}/docker-compose.yml" ]; then
        compose_file=$(ls "$REPO_DIR/${SERVICES[$service]}/docker-compose.y"*"ml" 2>/dev/null | head -1)
        docker compose -f "$compose_file" config > "$backup_path/docker-compose.backup.yaml" 2>/dev/null || true
    fi

    # Keep only last 5 backups
    ls -t "$BACKUP_DIR" | grep "^${service}_" | tail -n +6 | xargs -I {} rm -rf "$BACKUP_DIR/{}" 2>/dev/null || true

    echo "$backup_path"
}

# Pull latest changes from git
update_repo() {
    log_info "Pulling latest changes from GitHub..."
    cd "$REPO_DIR"

    # Stash any local changes
    if [[ -n $(git status -s) ]]; then
        log_warning "Local changes detected, stashing..."
        git stash push -m "Auto-stash before deployment $(date)"
    fi

    local current_commit=$(git rev-parse HEAD)
    git pull origin main
    local new_commit=$(git rev-parse HEAD)

    if [ "$current_commit" == "$new_commit" ]; then
        log_info "Already up to date (commit: ${current_commit:0:7})"
        return 1
    else
        log_success "Updated from ${current_commit:0:7} to ${new_commit:0:7}"
        git log --oneline "${current_commit}..${new_commit}"
        return 0
    fi
}

# Check if service is running
is_service_running() {
    local service=$1
    local service_dir="${SERVICES[$service]}"
    local compose_file=$(ls "$REPO_DIR/$service_dir/docker-compose.y"*"ml" 2>/dev/null | head -1)

    if [ -f "$compose_file" ]; then
        docker compose -f "$compose_file" ps --services --filter "status=running" 2>/dev/null | grep -q . && return 0
    fi
    return 1
}

# Deploy a specific service
deploy_service() {
    local service=$1
    local service_dir="${SERVICES[$service]}"

    if [ -z "$service_dir" ]; then
        log_error "Unknown service: $service"
        return 1
    fi

    log_info "Deploying $service..."

    # Find compose file
    local compose_file=$(ls "$REPO_DIR/$service_dir/docker-compose.y"*"ml" 2>/dev/null | head -1)

    if [ ! -f "$compose_file" ]; then
        log_error "No docker-compose file found for $service"
        return 1
    fi

    # Create backup
    local backup_path=$(create_backup "$service")

    # Navigate to service directory
    cd "$REPO_DIR/$service_dir"

    # Validate compose file
    log_info "Validating compose file..."
    if ! docker compose -f "$(basename "$compose_file")" config > /dev/null 2>&1; then
        log_error "Invalid compose file for $service"
        return 1
    fi

    # Pull latest images
    log_info "Pulling latest images for $service..."
    docker compose -f "$(basename "$compose_file")" pull

    # Deploy with zero-downtime reload
    log_info "Deploying $service..."
    if is_service_running "$service"; then
        docker compose -f "$(basename "$compose_file")" up -d --remove-orphans --force-recreate
    else
        docker compose -f "$(basename "$compose_file")" up -d --remove-orphans
    fi

    # Wait for health check
    sleep 5

    # Verify deployment
    if docker compose -f "$(basename "$compose_file")" ps | grep -q "Up\|running"; then
        log_success "$service deployed successfully"

        # Cleanup old images
        docker image prune -f > /dev/null 2>&1

        return 0
    else
        log_error "$service deployment failed"
        log_warning "Check logs: docker compose -f $compose_file logs"
        return 1
    fi
}

# Main deployment logic
main() {
    log_info "=========================================="
    log_info "Starting Homelab Deployment"
    log_info "Service: $SERVICE"
    log_info "=========================================="

    # Create necessary directories
    mkdir -p "$BACKUP_DIR"

    # Update repository
    if ! update_repo && [ "$SERVICE" != "all" ]; then
        log_info "No updates available, checking service status..."
    fi

    # Setup secrets from environment variables
    if [ -f "$REPO_DIR/deploy/setup-secrets.sh" ]; then
        log_info "Setting up secrets from environment..."
        bash "$REPO_DIR/deploy/setup-secrets.sh"
    else
        log_warning "setup-secrets.sh not found, skipping secret setup"
        log_warning "Make sure .env files exist manually or secrets are configured"
    fi

    # Deploy services
    if [ "$SERVICE" == "all" ]; then
        log_info "Deploying all services..."
        local failed_services=()

        for service in "${!SERVICES[@]}"; do
            if ! deploy_service "$service"; then
                failed_services+=("$service")
            fi
        done

        if [ ${#failed_services[@]} -eq 0 ]; then
            log_success "All services deployed successfully!"
        else
            log_error "Failed to deploy: ${failed_services[*]}"
            exit 1
        fi
    else
        # Deploy specific service
        if ! deploy_service "$SERVICE"; then
            log_error "Deployment failed for $SERVICE"
            exit 1
        fi
    fi

    log_info "=========================================="
    log_success "Deployment completed!"
    log_info "=========================================="
}

# Run main function
main
