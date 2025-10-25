#!/bin/bash

# Rollback Script for Homelab Services
# Usage: ./rollback.sh <service_name> [backup_timestamp]
# Example: ./rollback.sh traefik 20250124_143022
#          ./rollback.sh traefik (uses latest backup)

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BACKUP_DIR="${BACKUP_DIR:-$REPO_DIR/.backups}"
SERVICE="$1"
BACKUP_TIMESTAMP="$2"

declare -A SERVICE_DIRS=(
    ["traefik"]="traefik"
    ["homepage"]="homepage"
    ["pihole"]="Piholev6"
    ["rustdesk"]="rustdesk"
)

log() {
    echo -e "${2:-$NC}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_info() {
    log "$1" "$BLUE"
}

log_success() {
    log "✅ $1" "$GREEN"
}

log_error() {
    log "❌ $1" "$RED"
}

log_warning() {
    log "⚠️  $1" "$YELLOW"
}

# Show usage
show_usage() {
    echo "Usage: $0 <service_name> [backup_timestamp]"
    echo ""
    echo "Available services: ${!SERVICE_DIRS[*]}"
    echo ""
    echo "Examples:"
    echo "  $0 traefik                    # Rollback traefik to latest backup"
    echo "  $0 traefik 20250124_143022    # Rollback to specific backup"
    echo ""
    echo "Available backups:"
    if [ -d "$BACKUP_DIR" ]; then
        ls -lt "$BACKUP_DIR" | grep "^d" | awk '{print "  " $9}' | head -10
    else
        echo "  No backups found"
    fi
}

# Find latest backup for service
find_latest_backup() {
    local service=$1
    ls -t "$BACKUP_DIR" | grep "^${service}_" | head -1
}

# Rollback service
rollback_service() {
    local service=$1
    local backup_name=$2
    local service_dir="${SERVICE_DIRS[$service]}"

    if [ -z "$service_dir" ]; then
        log_error "Unknown service: $service"
        return 1
    fi

    local backup_path="$BACKUP_DIR/$backup_name"

    if [ ! -d "$backup_path" ]; then
        log_error "Backup not found: $backup_path"
        return 1
    fi

    log_info "Rolling back $service to backup: $backup_name"

    # Check if backup has compose file
    if [ ! -f "$backup_path/docker-compose.backup.yaml" ]; then
        log_error "Backup does not contain docker-compose file"
        return 1
    fi

    cd "$REPO_DIR/$service_dir"

    # Get current compose file
    local compose_file=$(ls docker-compose.y*ml 2>/dev/null | head -1)

    # Stop current containers
    log_info "Stopping current containers..."
    if [ -f "$compose_file" ]; then
        docker compose -f "$compose_file" down
    fi

    # Use git to restore files
    log_info "Checking git history for restoration point..."

    # Extract timestamp from backup name
    local backup_date=$(echo "$backup_name" | grep -oP '\d{8}_\d{6}')

    if [ -n "$backup_date" ]; then
        # Try to find closest commit
        local backup_epoch=$(date -d "${backup_date:0:8} ${backup_date:9:2}:${backup_date:11:2}:${backup_date:13:2}" +%s 2>/dev/null || echo "")

        if [ -n "$backup_epoch" ]; then
            log_info "Searching for commit near $(date -d @$backup_epoch '+%Y-%m-%d %H:%M:%S')..."

            # Find the closest commit before backup time
            local rollback_commit=$(git log --until="@$backup_epoch" --format="%H" -n 1 2>/dev/null)

            if [ -n "$rollback_commit" ]; then
                log_warning "Found commit: ${rollback_commit:0:7}"
                read -p "Rollback to this commit? [y/N] " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    git checkout "$rollback_commit" -- "$service_dir"
                    log_success "Files restored from git"
                fi
            else
                log_warning "No matching git commit found"
            fi
        fi
    fi

    # Start with restored configuration
    log_info "Starting containers with restored configuration..."
    docker compose -f "$compose_file" up -d

    # Wait and verify
    sleep 5

    if docker compose -f "$compose_file" ps | grep -q "Up\|running"; then
        log_success "Rollback completed successfully"
        log_info "Verify with: cd $REPO_DIR/$service_dir && docker compose logs"
        return 0
    else
        log_error "Rollback failed - containers not running properly"
        log_info "Check logs: cd $REPO_DIR/$service_dir && docker compose logs"
        return 1
    fi
}

# Main
main() {
    if [ -z "$SERVICE" ]; then
        show_usage
        exit 1
    fi

    # Check if service exists
    if [ -z "${SERVICE_DIRS[$SERVICE]}" ]; then
        log_error "Unknown service: $SERVICE"
        show_usage
        exit 1
    fi

    # Find backup to use
    local backup_name
    if [ -n "$BACKUP_TIMESTAMP" ]; then
        backup_name="${SERVICE}_${BACKUP_TIMESTAMP}"
    else
        backup_name=$(find_latest_backup "$SERVICE")
        if [ -z "$backup_name" ]; then
            log_error "No backups found for $SERVICE"
            exit 1
        fi
        log_info "Using latest backup: $backup_name"
    fi

    log_warning "⚠️  WARNING: This will rollback $SERVICE to a previous state"
    log_warning "Backup: $backup_name"
    read -p "Continue with rollback? [y/N] " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Rollback cancelled"
        exit 0
    fi

    rollback_service "$SERVICE" "$backup_name"
}

main
