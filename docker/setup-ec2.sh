#!/bin/bash
# =============================================================================
# VNALO — EC2 First-Time Setup
# Run this ONCE after cloning the repo on a fresh EC2 instance.
# =============================================================================
#
# Usage:
#   chmod +x setup-ec2.sh
#   ./setup-ec2.sh
#
# This script will:
#   1. Install Docker & Docker Compose v2
#   2. Enable Docker service
#   3. Create vnalo user and add to docker group
#   4. Make deploy scripts executable
#   5. Create .env from .env.example
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    warn "Please run as root (sudo ./setup-ec2.sh)"
    exit 1
fi

echo ""
log "VNALO EC2 First-Time Setup"
log "=============================="
echo ""

# =============================================================================
# 1. Update system
# =============================================================================
log "Updating system packages..."
yum update -y > /dev/null 2>&1
success "System updated."

# =============================================================================
# 2. Install Docker
# =============================================================================
log "Installing Docker..."
if command -v docker &> /dev/null; then
    warn "Docker already installed: $(docker --version)"
else
    yum install -y docker > /dev/null 2>&1
    success "Docker installed."
fi

# =============================================================================
# 3. Install Docker Compose v2
# =============================================================================
log "Installing Docker Compose v2..."
if command -v docker &> /dev/null && docker compose version &>/dev/null; then
    warn "Docker Compose v2 already installed: $(docker compose version)"
else
    curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose > /dev/null 2>&1
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    # Also copy to Docker plugin directory
    mkdir -p /usr/libexec/docker/cli-plugins
    cp /usr/local/bin/docker-compose /usr/libexec/docker/cli-plugins/docker-compose
    chmod +x /usr/libexec/docker/cli-plugins/docker-compose
    success "Docker Compose v2 installed."
fi

# =============================================================================
# 4. Start and enable Docker
# =============================================================================
log "Starting Docker service..."
systemctl start docker
systemctl enable docker
success "Docker service enabled."

# =============================================================================
# 5. Add current user to docker group
# =============================================================================
CURRENT_USER=$(logname 2>/dev/null || echo "ec2-user")
log "Adding user '$CURRENT_USER' to docker group..."
usermod -aG docker "$CURRENT_USER" 2>/dev/null || true
success "User added to docker group."

# =============================================================================
# 6. Create .env from example
# =============================================================================
if [ ! -f ".env" ]; then
    log "Creating .env from .env.example..."
    cp .env.example .env
    warn "IMPORTANT: Please edit .env before deploying!"
    warn "Run: nano .env"
else
    warn ".env already exists. Skipping."
fi

# =============================================================================
# 7. Make scripts executable
# =============================================================================
log "Making scripts executable..."
chmod +x deploy.sh rollback.sh 2>/dev/null || true
success "Scripts are now executable."

# =============================================================================
# Done
# =============================================================================
echo ""
success "==================================="
success "Setup complete!"
success "==================================="
echo ""
log "Next steps:"
echo "  1. Edit .env:           nano .env"
echo "  2. Pull latest code:   git pull"
echo "  3. Deploy:             ./deploy.sh"
echo ""
log "Quick commands:"
echo "  ./deploy.sh             # Deploy all"
echo "  ./deploy.sh --status    # Check status"
echo "  ./deploy.sh --logs      # Tail logs"
echo "  ./deploy.sh ai-service  # Deploy specific service"
echo ""
