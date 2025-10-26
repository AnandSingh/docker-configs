#!/bin/bash
set -e

# Multi-Server Deployment Router
# Routes deployment to homelab or teaching VM based on parameters
# Usage: ./deploy.sh [--server homelab|teaching] [service_name|all]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
LOG_FILE="${LOG_FILE:-$REPO_DIR/deploy/deploy.log}"

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

# Show usage
show_usage() {
    cat << EOF
Multi-Server Deployment Script

Usage:
  $0 [--server SERVER] [SERVICE]
  $0 --help

Options:
  --server SERVER    Target server: homelab | teaching (default: homelab)
  SERVICE            Service name or 'all' (default: all)

Examples:
  $0                              # Deploy all homelab services
  $0 --server homelab traefik     # Deploy homelab Traefik
  $0 --server teaching coder      # Deploy teaching Coder
  $0 --server teaching all        # Deploy all teaching services

Servers:
  homelab   - Main homelab server (192.168.10.13)
              Services: traefik, homepage, jellyfin, servarr, twingate

  teaching  - Teaching VM (192.168.10.29)
              Services: traefik, coder, rustdesk

EOF
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

# Setup secrets from environment variables
setup_secrets() {
    if [ -f "$REPO_DIR/deploy/setup-secrets.sh" ]; then
        log_info "Setting up secrets from environment..."
        bash "$REPO_DIR/deploy/setup-secrets.sh"
    else
        log_warning "setup-secrets.sh not found, skipping secret setup"
    fi
}

# Main execution
main() {
    # Parse arguments
    local server="homelab"
    local service="all"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --server)
                server="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                service="$1"
                shift
                ;;
        esac
    done

    # Validate server
    if [[ "$server" != "homelab" && "$server" != "teaching" ]]; then
        log_error "Invalid server: $server"
        log_info "Valid servers: homelab, teaching"
        exit 1
    fi

    log_info "=========================================="
    log_info "Multi-Server Deployment Router"
    log_info "Server: $server ($([ "$server" == "homelab" ] && echo "192.168.10.13" || echo "192.168.10.29"))"
    log_info "Service: $service"
    log_info "=========================================="

    # Update repository (skip if not a git repo - GitHub Actions handles updates)
    if [ -d "$REPO_DIR/.git" ]; then
        update_repo || true
    else
        log_info "Code synced by CI/CD pipeline, skipping git pull"
    fi

    # Setup secrets
    setup_secrets

    # Route to appropriate deployment script
    case $server in
        homelab)
            log_info "Routing to homelab deployment..."
            bash "$REPO_DIR/deploy/deploy-homelab.sh" "$service"
            ;;
        teaching)
            log_info "Routing to teaching VM deployment..."
            bash "$REPO_DIR/deploy/deploy-teaching.sh" "$service"
            ;;
    esac

    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        log_success "Deployment completed successfully!"
    else
        log_error "Deployment failed with exit code: $exit_code"
    fi

    exit $exit_code
}

main "$@"
