#!/bin/bash
# =============================================================================
# VNALO — Rollback Script
# Usage: ./rollback.sh [service-name]
#
# Examples:
#   ./rollback.sh                    # Rollback all services
#   ./rollback.sh core-service       # Rollback specific service
#   ./rollback.sh --prune          # Clean up old images
#   ./rollback.sh --list           # Show available rollback images
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[VNALO]${NC} $*"; }
success() { echo -e "${GREEN}[VNALO]${NC} $*"; }
warn() { echo -e "${YELLOW}[VNALO]${NC} $*"; }
error() { echo -e "${RED}[VNALO]${NC} $*" >&2; }

# Detect docker compose command
if docker compose version &>/dev/null; then
  DC="docker compose"
elif docker-compose --version &>/dev/null; then
  DC="docker-compose"
else
  error "Docker Compose is not installed!"
  exit 1
fi

# =============================================================================
# Handle flags
# =============================================================================

case "${1:-}" in
  --prune)
    log "Cleaning up old Docker images..."
    docker image prune -f
    docker builder prune -f
    success "Cleanup complete."
    exit 0
    ;;
  --list)
    log "Available rollback images:"
    echo ""
    docker images | grep -E "vnalo|core|message|media|ai|notification|realtime" || echo "  No VNALO images found."
    echo ""
    exit 0
    ;;
esac

# =============================================================================
# Rollback all services
# =============================================================================

rollback_all() {
    log "Rolling back all services..."

    # Stop current containers
    log "Stopping containers..."
    $DC down

    # Rebuild from current code
    log "Rebuilding from current code..."
    $DC build

    # Start services
    log "Starting services..."
    $DC up -d

    success "All services rolled back."
}

# =============================================================================
# Rollback a specific service
# =============================================================================

rollback_service() {
    local SERVICE="$1"

    log "Rolling back service: $SERVICE"

    # Stop and remove the service
    $DC stop "$SERVICE"
    $DC rm -f "$SERVICE"

    # Rebuild and start
    $DC build "$SERVICE"
    $DC up -d "$SERVICE"

    success "Service '$SERVICE' rolled back."
}

# =============================================================================
# Main
# =============================================================================

SERVICE="${1:-all}"

if [ "$SERVICE" = "all" ]; then
    echo ""
    warn "This will rebuild and restart all services from current code."
    read -p "Continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Cancelled."
        exit 0
    fi
    rollback_all
else
    rollback_service "$SERVICE"
fi

# Verify
sleep 5
log "Service status:"
$DC ps --format "table {{.Name}}\t{{.Status}}"
