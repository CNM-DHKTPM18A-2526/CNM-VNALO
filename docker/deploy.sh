#!/bin/bash
# =============================================================================
# VNALO — Deployment Script
# Usage: ./deploy.sh [service-name]
#
# Examples:
#   ./deploy.sh              # Deploy all services
#   ./deploy.sh core-service # Deploy specific service only
#   ./deploy.sh --status     # Show service status
#   ./deploy.sh --logs       # Tail all logs
#   ./deploy.sh --restart    # Restart all services
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

# =============================================================================
# Handle flags
# =============================================================================

case "${1:-}" in
  --status)
    log "Checking service status..."
    docker compose ps
    echo ""
    log "Resource usage:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || echo "  (stats unavailable)"
    exit 0
    ;;
  --logs)
    log "Tailing logs (Ctrl+C to exit)..."
    docker compose logs -f --tail=50
    exit 0
    ;;
  --restart)
    log "Restarting all services..."
    docker compose restart
    success "All services restarted."
    exit 0
    ;;
  --stop)
    log "Stopping all services..."
    docker compose down
    success "All services stopped."
    exit 0
    ;;
  --health)
    log "Checking service health..."
    echo ""
    for svc in core-service message-service media-service ai-service content-service notification-service realtime-gateway; do
      status=$(docker compose ps "$svc" --format json 2>/dev/null | grep -o '"State":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
      if [ "$status" = "running" ]; then
        echo -e "  ${GREEN}[OK]${NC} $svc"
      else
        echo -e "  ${RED}[FAIL]${NC} $svc (status: $status)"
      fi
    done
    echo ""
    log "Container status:"
    docker compose ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null || docker-compose ps --format "table {{.Name}}\t{{.Status}}"
    exit 0
    ;;
esac

# =============================================================================
# Pre-flight checks
# =============================================================================

log "Starting deployment..."

# Detect docker compose command
if docker compose version &>/dev/null; then
  DC="docker compose"
elif docker-compose --version &>/dev/null; then
  DC="docker-compose"
else
  error "Docker Compose is not installed!"
  exit 1
fi

# Check if .env exists
if [ ! -f ".env" ]; then
    warn ".env not found. Copying from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        error "Please edit .env with your actual values before continuing."
        error "Run: nano .env"
        exit 1
    else
        error ".env.example not found!"
        exit 1
    fi
fi

# =============================================================================
# Pull latest code (if git repo)
# =============================================================================

if [ -d ".git" ] || [ -f ".git" ]; then
    log "Pulling latest code from git..."
    git pull origin $(git branch --show-current 2>/dev/null || echo "main") 2>/dev/null || warn "Git pull skipped (not a git repo or no remote)"
    success "Code updated."
elif [ -d "../.git" ] || [ -f "../.git" ]; then
    log "Pulling latest code from git..."
    cd ..
    git pull origin $(git branch --show-current 2>/dev/null || echo "main") 2>/dev/null || warn "Git pull skipped"
    cd docker
    success "Code updated."
else
    warn "Not a git repository. Skipping git pull."
fi

# =============================================================================
# Build and deploy
# =============================================================================

SERVICE="${1:-}"

if [ -n "$SERVICE" ]; then
    log "Building and deploying service: $SERVICE"
    $DC build "$SERVICE"
    $DC up -d "$SERVICE"
    success "Service '$SERVICE' deployed successfully."
else
    log "Building and deploying all services..."
    $DC build
    $DC up -d
    success "All services deployed successfully."
fi

# =============================================================================
# Health check
# =============================================================================

log "Waiting for services to start..."
sleep 10

log "Checking service health..."
UNHEALTHY=0
for svc in core-service message-service media-service ai-service content-service notification-service realtime-gateway; do
    STATUS=$($DC ps "$svc" --format json 2>/dev/null | grep -o '"State":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    if [ "$STATUS" != "running" ]; then
        ((UNHEALTHY++))
        warn "Service '$svc' is not running (status: $STATUS)"
    fi
done

echo ""
if [ $UNHEALTHY -eq 0 ]; then
    success "All services are healthy!"
else
    warn "Some services may have issues ($UNHEALTHY unhealthy)."
    log "Run './deploy.sh --logs' to check logs."
fi

echo ""
log "Quick commands:"
echo "  ./deploy.sh --status   # Check status"
echo "  ./deploy.sh --logs     # Tail logs"
echo "  ./deploy.sh --restart  # Restart all"
echo "  ./deploy.sh --health   # Detailed health"
echo "  $DC logs -f <service>  # Logs for specific service"
